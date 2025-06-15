// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/AuctionVault.sol";
import "../contracts/DigicharFactory.sol";
import "../contracts/DigicharToken.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
import "../contracts/Config.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract DigicharTokenTest is Test {
    DigicharToken public digicharToken;
    AuctionVault public auctionVault;
    DigicharFactory public digicharFactory;
    DigicharOwnershipCertificate digicharOwnershipCertificate;
    Config config;

    MockUniswapV2Factory swapFactory;
    MockUniswapV2Router swapRouter;
    ERC20 weth;

    address public protocolAdmin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public dexAddress = address(0x6);
    address public characterOwner = address(0x7);

    uint256 public constant OWNERSHIP_CERTIFICATE_TOKEN_ID = 0;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    event TaxCollected(address indexed from, address indexed to, uint256 tokenAmount, uint256 ethAmount);
    event TaxExemptionSet(address indexed account, bool exempt);
    event LiquidityLocked(uint256 tokenAmount, uint256 ethAmount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        vm.startPrank(protocolAdmin);

        config = new Config();

        auctionVault = new AuctionVault(address(config));
        digicharFactory = new DigicharFactory(address(config));
        digicharOwnershipCertificate = new DigicharOwnershipCertificate(payable(address(digicharFactory)));

        weth = new CustomCoin();
        swapFactory = new MockUniswapV2Factory();
        swapRouter = new MockUniswapV2Router(address(weth));

        config.setAuctionVault(address(auctionVault));
        config.setDigicharFactory(payable(address(digicharFactory)));
        config.setOwnershipCertificate(address(digicharOwnershipCertificate));

        config.setSwapFactory(address(swapFactory));
        config.setSwapRouter(address(swapRouter));
        config.setWETH(address(weth));

        vm.stopPrank();

        // Create DigicharToken
        vm.startPrank(characterOwner);
        digicharToken = new DigicharToken(address(config), OWNERSHIP_CERTIFICATE_TOKEN_ID, "Test Token", "TEST", 18);
        vm.stopPrank();

        // Mint ownership certificate to characterOwner
        vm.prank(address(digicharFactory));
        digicharOwnershipCertificate.mint(characterOwner, "TEST_TOKEN_URI");

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(protocolAdmin, 10 ether);
        vm.deal(characterOwner, 10 ether);

        // Give some tokens to users for testing
        vm.startPrank(characterOwner);
        digicharToken.transfer(user1, 10000 * 10 ** 18);
        digicharToken.transfer(user2, 10000 * 10 ** 18);
        vm.stopPrank();
    }

    function testConstructorInitialization() public {
        assertEq(digicharToken.name(), "Test Token");
        assertEq(digicharToken.symbol(), "TEST");
        assertEq(digicharToken.decimals(), 18);
        assertEq(digicharToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(digicharToken.balanceOf(characterOwner), INITIAL_SUPPLY - 20000 * 10 ** 18);
        assertEq(digicharToken.ownershipCertificateTokenId(), OWNERSHIP_CERTIFICATE_TOKEN_ID);
        assertEq(address(digicharToken.config()), address(config));
        assertTrue(digicharToken.taxExempt(address(digicharToken)));
    }

    function testGetOwnershipCertificateOwner() public {
        assertEq(digicharToken.getOwnershipCertificateOwner(), characterOwner);
    }

    function testStandardTransferWithoutTax() public {
        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 user1InitialBalance = digicharToken.balanceOf(user1);
        uint256 user2InitialBalance = digicharToken.balanceOf(user2);

        vm.prank(user1);
        digicharToken.transfer(user2, transferAmount);

        assertEq(digicharToken.balanceOf(user1), user1InitialBalance - transferAmount);
        assertEq(digicharToken.balanceOf(user2), user2InitialBalance + transferAmount);
    }

    function testTransferFromWithoutTax() public {
        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 user1InitialBalance = digicharToken.balanceOf(user1);
        uint256 user2InitialBalance = digicharToken.balanceOf(user2);

        vm.prank(user1);
        digicharToken.approve(user3, transferAmount);

        vm.prank(user3);
        digicharToken.transferFrom(user1, user2, transferAmount);

        assertEq(digicharToken.balanceOf(user1), user1InitialBalance - transferAmount);
        assertEq(digicharToken.balanceOf(user2), user2InitialBalance + transferAmount);
        assertEq(digicharToken.allowance(user1, user3), 0);
    }

    function testShouldApplyTaxFalseForTaxExempt() public {
        assertTrue(digicharToken.taxExempt(address(digicharToken)));
        assertFalse(shouldApplyTaxHelper(address(digicharToken), user1));
        assertFalse(shouldApplyTaxHelper(user1, address(digicharToken)));
    }

    function testShouldApplyTaxFalseForCharacterOwner() public {
        assertFalse(shouldApplyTaxHelper(characterOwner, user1));
        assertFalse(shouldApplyTaxHelper(user1, characterOwner));
    }

    function testShouldApplyTaxFalseForRegularTransfers() public {
        assertFalse(shouldApplyTaxHelper(user1, user2));
    }

    function testTaxExemptionForContractItself() public {
        assertTrue(digicharToken.taxExempt(address(digicharToken)));
    }

    function testTransferFromCharacterOwnerNoTax() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(characterOwner);
        digicharToken.approve(user3, transferAmount);

        uint256 characterOwnerInitialBalance = digicharToken.balanceOf(characterOwner);
        uint256 user1InitialBalance = digicharToken.balanceOf(user1);

        vm.prank(user3);
        digicharToken.transferFrom(characterOwner, user1, transferAmount);

        assertEq(digicharToken.balanceOf(characterOwner), characterOwnerInitialBalance - transferAmount);
        assertEq(digicharToken.balanceOf(user1), user1InitialBalance + transferAmount);
    }

    function testTransferToCharacterOwnerNoTax() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        digicharToken.approve(user3, transferAmount);

        uint256 user1InitialBalance = digicharToken.balanceOf(user1);
        uint256 characterOwnerInitialBalance = digicharToken.balanceOf(characterOwner);

        vm.prank(user3);
        digicharToken.transferFrom(user1, characterOwner, transferAmount);

        assertEq(digicharToken.balanceOf(user1), user1InitialBalance - transferAmount);
        assertEq(digicharToken.balanceOf(characterOwner), characterOwnerInitialBalance + transferAmount);
    }

    function testZeroAmountTransfer() public {
        vm.prank(user1);
        digicharToken.transfer(user2, 0);

        assertEq(digicharToken.balanceOf(user1), 10000 * 10 ** 18);
        assertEq(digicharToken.balanceOf(user2), 10000 * 10 ** 18);
    }

    function testTransferMoreThanBalance() public {
        vm.expectRevert();
        vm.prank(user1);
        digicharToken.transfer(user2, 20000 * 10 ** 18);
    }

    function testTransferFromWithInsufficientAllowance() public {
        vm.prank(user1);
        digicharToken.approve(user3, 500 * 10 ** 18);

        vm.expectRevert();
        vm.prank(user3);
        digicharToken.transferFrom(user1, user2, 1000 * 10 ** 18);
    }

    function testTransferFromWithMaxAllowance() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        digicharToken.approve(user3, type(uint256).max);

        uint256 allowanceBefore = digicharToken.allowance(user1, user3);

        vm.prank(user3);
        digicharToken.transferFrom(user1, user2, transferAmount);

        assertEq(digicharToken.allowance(user1, user3), allowanceBefore);
    }

    function shouldApplyTaxHelper(address from, address to) internal view returns (bool) {
        return !digicharToken.taxExempt(from) && !digicharToken.taxExempt(to) && from != characterOwner
            && to != characterOwner && (digicharToken.isDEX(from) || digicharToken.isDEX(to));
    }
}

contract CustomCoin is ERC20 {
    constructor() ERC20("Dummy ", "DUMMY", 18) { }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PAIR_EXISTS");

        // Create mock pair address
        pair = address(new MockPair(token0, token1));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}

contract MockPair {
    address public token0;
    address public token1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}

contract MockUniswapV2Router {
    address public WETH;

    constructor(address _WETH) {
        WETH = _WETH;
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // Mock implementation
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1000; // Mock liquidity amount
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2; // Mock 2:1 ratio
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = 1000;
    }
}
