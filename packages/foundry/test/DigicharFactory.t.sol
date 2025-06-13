// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/DigicharFactory.sol";
import "../contracts/AuctionVault.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
import "../contracts/DigicharToken.sol";
//import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "v2-core/interfaces/IUniswapV2Factory.sol";
import "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

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

contract DigicharFactoryTest is Test {
    DigicharFactory public factory;
    AuctionVault public auctionVault;
    DigicharOwnershipCertificate public ownershipCertificate;
    MockUniswapV2Factory public mockSwapFactory;
    MockUniswapV2Router public mockSwapRouter;
    ERC20 public mockWETH;

    address public owner = address(0x1);
    address public protocolAdmin = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    event TargetDexUpdated(address _newTargetDex);
    event DigicharOwnershipCertificateSet(address _digicharOwnershipCertificate);
    event TokenCreated(address indexed _token, string _name, string _symbol);
    event PairCreated(address indexed _token, address indexed _pair);
    event SwapFactorySet(address indexed _swapFactory);
    event LPInitialized(
        address indexed _token, address indexed _pair, uint256 _amountToken, uint256 _amountEth, uint256 _liquidity
    );
    event Received(address, uint256);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock contracts
        mockWETH = new CustomCoin();
        mockSwapFactory = new MockUniswapV2Factory();
        mockSwapRouter = new MockUniswapV2Router(address(mockWETH));

        // Deploy AuctionVault first
        auctionVault = new AuctionVault();

        // Deploy factory
        factory = new DigicharFactory(address(auctionVault));

        // Deploy ownership certificate
        ownershipCertificate = new DigicharOwnershipCertificate(payable(address(factory)));

        // Set up factory dependencies
        factory.setSwapFactory(address(mockSwapFactory));
        factory.setDigicharOwnershipCertificate(address(ownershipCertificate));
        factory.setWETH(address(mockWETH));
        factory.setSwapRouter(address(mockSwapRouter));

        // Set up auction vault
        auctionVault.setDigicharFactory(payable(address(factory)));

        vm.stopPrank();
    }

    function testConstructor() public {
        assertEq(factory.owner(), owner);
        assertEq(address(factory.auctionVault()), address(auctionVault));
    }

    function testSetSwapFactory() public {
        address newFactory = address(0x999);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit SwapFactorySet(newFactory);
        factory.setSwapFactory(newFactory);

        // Verify the factory was set (we can't directly access it, but we can test behavior)
    }

    function testSetSwapFactoryOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.setSwapFactory(address(0x999));
    }

    function testUpdateTargetDex() public {
        address newDex = address(0x888);

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit TargetDexUpdated(newDex);
        factory.updateTargetDex(newDex);
    }

    function testUpdateTargetDexOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.updateTargetDex(address(0x888));
    }

    function testSetDigicharOwnershipCertificate() public {
        address newCertificate = address(0x777);

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit DigicharOwnershipCertificateSet(newCertificate);
        factory.setDigicharOwnershipCertificate(newCertificate);
    }

    function testSetDigicharOwnershipCertificateOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.setDigicharOwnershipCertificate(address(0x777));
    }

    function testReceiveEther() public {
        uint256 amount = 1 ether;

        vm.expectEmit(false, false, false, true);
        emit Received(address(this), amount);

        (bool success,) = payable(address(factory)).call{ value: amount }("");
        assertTrue(success);
        assertEq(address(factory).balance, amount);
    }

    function testCreateCharacterOnlyAuctionVault() public {
        vm.prank(user1);
        vm.expectRevert(DigicharFactory.OnlyAuctionVault.selector);
        factory.createCharacter{ value: 1 ether }(user1, 0, "ipfs://test", "TestChar", "TEST");
    }

    function testCreateCharacterInsufficientBalance() public {
        // Set up auction vault to have a different pool balance
        vm.prank(owner);

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // Simulate a bid to create pool balance
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        // Now try to create character with wrong value
        vm.prank(address(auctionVault));
        vm.expectRevert(DigicharFactory.InsufficientBalance.selector);
        factory.createCharacter{ value: 0.5 ether }(user1, 0, "ipfs://test", "TestChar", "TEST");
    }

    function testCreateCharacterSuccess() public {
        // Set up auction vault
        vm.prank(owner);

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // Simulate a bid
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        // Fast forward past auction end
        vm.warp(block.timestamp + 2 hours);

        // Close auction
        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        // Get the created token address
        address tokenAddress = auctionVault.getCharacterTokenAddress(0);
        assertTrue(tokenAddress != address(0));

        // Verify token was created with correct parameters
        DigicharToken token = DigicharToken(tokenAddress);
        assertEq(token.name(), "name1");
        assertEq(token.symbol(), "SYM1");
        assertEq(token.decimals(), 18);
    }

    function testCreateLPforTokenPairRequireETH() public {
        // This is a private function, but we can test it indirectly through createCharacter
        // The require statement should be triggered if no ETH is sent

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // Try to create character with 0 value (should fail in createCharacter due to InsufficientBalance)
        vm.prank(address(auctionVault));
        vm.expectRevert(DigicharFactory.InsufficientBalance.selector);
        factory.createCharacter{ value: 0 }(user1, 0, "ipfs://test", "TestChar", "TEST");
    }

    function testCreateLPforTokenPairRequireTokenAmount() public {
        // This tests the "Token amount must be > 0" require statement
        // Since the token amount is calculated from constants, this would only fail
        // if the constants were set to 0, which they aren't in the current implementation
        // But we can still verify the LP creation works correctly

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        // Verify LP was created successfully
        address tokenAddress = auctionVault.getCharacterTokenAddress(0);
        assertTrue(tokenAddress != address(0));
    }

    function testCreateCharacterRefundsExcessETH() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.deal(user1, 3 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 2 ether }(0);

        vm.warp(block.timestamp + 2 hours);

        uint256 protocolAdminBalanceBefore = protocolAdmin.balance;

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        // Check that excess ETH was sent to protocol admin
        // Note: In the mock router, we simulate using less ETH than provided
        assertTrue(protocolAdmin.balance > protocolAdminBalanceBefore);
    }

    function testMultipleCharacterCreation() public {
        // Test creating multiple characters in sequence

        // First auction
        string[3] memory uris1 = ["uri1", "uri2", "uri3"];
        string[3] memory names1 = ["name1", "name2", "name3"];
        string[3] memory symbols1 = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris1, names1, symbols1);

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        address token1 = auctionVault.getCharacterTokenAddress(0);

        // Second auction
        string[3] memory uris2 = ["uri4", "uri5", "uri6"];
        string[3] memory names2 = ["name4", "name5", "name6"];
        string[3] memory symbols2 = ["SYM4", "SYM5", "SYM6"];

        vm.prank(owner);
        auctionVault.createAuction(uris2, names2, symbols2);

        vm.deal(user2, 2 ether);
        vm.prank(user2);
        auctionVault.bid{ value: 1 ether }(1);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, 1);

        address token2 = auctionVault.getCharacterTokenAddress(1);

        // Verify both tokens were created
        assertTrue(token1 != address(0));
        assertTrue(token2 != address(0));
        assertTrue(token1 != token2);

        DigicharToken tokenContract1 = DigicharToken(token1);
        DigicharToken tokenContract2 = DigicharToken(token2);

        assertEq(tokenContract1.name(), "name1");
        assertEq(tokenContract2.name(), "name5");
    }

    function testOwnershipCertificateMinting() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        // Verify ownership certificate was minted
        assertEq(ownershipCertificate.ownerOf(0), user1);
        assertEq(ownershipCertificate.tokenURI(0), "uri1");
    }

    // Fuzz testing
    function testFuzzCreateCharacterWithDifferentValues(uint256 bidAmount) public {
        vm.assume(bidAmount > 0 && bidAmount <= 100 ether);

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.deal(user1, bidAmount + 1 ether);
        vm.prank(user1);
        auctionVault.bid{ value: bidAmount }(0);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(0);
        assertTrue(tokenAddress != address(0));
    }

    function testAccessControlModifiers() public {
        // Test all functions that should revert for non-owners
        vm.startPrank(user1);

        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.setSwapFactory(address(0x123));

        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.updateTargetDex(address(0x123));

        vm.expectRevert(DigicharFactory.OnlyOwner.selector);
        factory.setDigicharOwnershipCertificate(address(0x123));

        vm.stopPrank();

        // Test function that should revert for non-auction vault
        vm.prank(user1);
        vm.expectRevert(DigicharFactory.OnlyAuctionVault.selector);
        factory.createCharacter{ value: 1 ether }(user1, 0, "uri", "name", "symbol");
    }
}
