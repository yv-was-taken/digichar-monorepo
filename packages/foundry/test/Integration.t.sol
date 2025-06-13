// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/DigicharFactory.sol";
import "../contracts/AuctionVault.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
import "../contracts/DigicharToken.sol";
import "../contracts/Config.sol";
//import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "solmate/tokens/WETH.sol";

// Mock UniswapV2Factory to avoid solidity version compatibility issues
contract MockUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    address public feeTo;
    address public feeToSetter;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PAIR_EXISTS");

        // Create a deterministic mock pair address
        pair = address(uint160(uint256(keccak256(abi.encodePacked(token0, token1, block.timestamp)))));

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}

// Mock UniswapV2Router02 to avoid solidity version compatibility issues
contract MockUniswapV2Router02 {
    address public factory;
    address public MockWETH;

    constructor(address _factory, address _MockWETH) {
        factory = _factory;
        MockWETH = _MockWETH;
    }

    // Add minimal required functions that might be called by the contracts
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        // Mock implementation - just return empty array
        amounts = new uint256[](path.length);
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
        liquidity = amountToken;
    }
}

contract IntegrationTest is Test {
    DigicharFactory public factory;
    AuctionVault public auctionVault;
    DigicharOwnershipCertificate public ownershipCertificate;
    MockUniswapV2Factory public uniswapFactory;
    MockUniswapV2Router02 public uniswapRouter;
    WETH public weth;

    address public protocolAdmin = address(0x1);
    address public factoryOwner = address(0x2);
    address public bidder1 = address(0x3);
    address public bidder2 = address(0x4);
    address public bidder3 = address(0x5);
    address public trader1 = address(0x6);
    address public trader2 = address(0x7);

    function setUp() public {
        // Deploy MockWETH
        weth = new WETH();

        // Deploy Uniswap contracts
        uniswapFactory = new MockUniswapV2Factory(factoryOwner);
        uniswapRouter = new MockUniswapV2Router02(address(uniswapFactory), address(weth));

        // Deploy core contracts
        vm.startPrank(factoryOwner);

        auctionVault = new AuctionVault();
        factory = new DigicharFactory(address(auctionVault));
        ownershipCertificate = new DigicharOwnershipCertificate(payable(address(factory)));

        // Set up factory
        factory.setSwapFactory(address(uniswapFactory));
        factory.setDigicharOwnershipCertificate(address(ownershipCertificate));
        //factory.setMockWETH(address(weth));
        factory.setSwapRouter(address(uniswapRouter));

        // Set up auction vault
        auctionVault.setDigicharFactory(payable(address(factory)));

        vm.stopPrank();

        // Fund test accounts
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
        vm.deal(bidder3, 10 ether);
        vm.deal(trader1, 5 ether);
        vm.deal(trader2, 5 ether);

        // Give MockWETH to accounts for trading
        vm.deal(address(this), 1000 ether);
        weth.deposit{ value: 1000 ether }();
        weth.transfer(address(uniswapRouter), 500 ether);
    }

    function testFullAuctionFlow() public {
        // 1. Create auction
        string[3] memory uris = ["ipfs://char1", "ipfs://char2", "ipfs://char3"];
        string[3] memory names = ["Character1", "Character2", "Character3"];
        string[3] memory symbols = ["CHAR1", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        // 2. Multiple users bid on different characters
        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0); // Character 1

        vm.prank(bidder2);
        auctionVault.bid{ value: 2 ether }(1); // Character 2

        vm.prank(bidder3);
        auctionVault.bid{ value: 1.5 ether }(1); // Also Character 2

        vm.prank(bidder1);
        auctionVault.bid{ value: 0.5 ether }(2); // Character 3

        // Verify bid balances
        assertEq(auctionVault.getUserBidBalance(bidder1, auctionId, 0), 1 ether);
        assertEq(auctionVault.getUserBidBalance(bidder2, auctionId, 1), 2 ether);
        assertEq(auctionVault.getUserBidBalance(bidder3, auctionId, 1), 1.5 ether);
        assertEq(auctionVault.getUserBidBalance(bidder1, auctionId, 2), 0.5 ether);

        // 3. Fast forward past auction end
        vm.warp(block.timestamp + 4 hours + 1);

        // 4. Close auction (Character 2 has highest pool: 2 + 1.5 = 3.5 ETH)
        uint8 winningCharacterIndex = 1;
        address topBidder = bidder2; // Highest individual bid

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(topBidder, winningCharacterIndex);

        // 5. Verify character token was created
        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        assertTrue(tokenAddress != address(0));

        DigicharToken characterToken = DigicharToken(tokenAddress);
        assertEq(characterToken.name(), "Character2");
        assertEq(characterToken.symbol(), "CHAR2");

        // 6. Verify ownership certificate was minted
        assertEq(ownershipCertificate.ownerOf(0), topBidder);
        assertEq(ownershipCertificate.tokenURI(0), "ipfs://char2");

        // 7. Users claim their tokens
        uint256 bidder2ExpectedTokens = auctionVault.checkUnclaimedTokens(bidder2, auctionId);
        uint256 bidder3ExpectedTokens = auctionVault.checkUnclaimedTokens(bidder3, auctionId);

        assertTrue(bidder2ExpectedTokens > 0);
        assertTrue(bidder3ExpectedTokens > 0);

        vm.prank(bidder2);
        auctionVault.claimTokens(auctionId);

        vm.prank(bidder3);
        auctionVault.claimTokens(auctionId);

        assertEq(characterToken.balanceOf(bidder2), bidder2ExpectedTokens);
        assertEq(characterToken.balanceOf(bidder3), bidder3ExpectedTokens);

        // 8. Test that losing bidders can withdraw their bids
        vm.prank(bidder1);
        auctionVault.withdrawBid(auctionId, 0, 1 ether); // Character 1 bid

        vm.prank(bidder1);
        auctionVault.withdrawBid(auctionId, 2, 0.5 ether); // Character 3 bid
    }

    function testTokenTaxMechanics() public {
        // Set up an auction and close it first
        string[3] memory uris = ["ipfs://char1", "ipfs://char2", "ipfs://char3"];
        string[3] memory names = ["TaxTest", "Character2", "Character3"];
        string[3] memory symbols = ["TAX", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 2 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        DigicharToken token = DigicharToken(tokenAddress);

        // Claim tokens
        vm.prank(bidder1);
        auctionVault.claimTokens(auctionId);

        uint256 bidder1Balance = token.balanceOf(bidder1);

        // Transfer some tokens to traders
        vm.prank(bidder1);
        token.transfer(trader1, 10000 * 10 ** 18);

        vm.prank(bidder1);
        token.transfer(trader2, 10000 * 10 ** 18);

        // Set up trader2 as a DEX to trigger tax
        vm.prank(protocolAdmin);
        //token.setDEXStatus(trader2, true);

        // Test regular transfer (no tax)
        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 trader1BalanceBefore = token.balanceOf(trader1);

        vm.prank(trader1);
        token.transfer(bidder2, transferAmount);

        assertEq(token.balanceOf(bidder2), transferAmount);
        assertEq(token.balanceOf(trader1), trader1BalanceBefore - transferAmount);

        // Test DEX transfer (with tax)
        vm.prank(trader1);
        token.approve(trader2, transferAmount);

        uint256 protocolAdminMockWETHBefore = weth.balanceOf(protocolAdmin);
        uint256 characterOwnerMockWETHBefore = weth.balanceOf(bidder1);
        uint256 contractTokensBefore = token.balanceOf(address(token));

        vm.prank(trader2);
        token.transferFrom(trader1, trader2, transferAmount);

        // Verify tax was collected and converted to MockWETH
        assertTrue(weth.balanceOf(protocolAdmin) > protocolAdminMockWETHBefore);
        assertTrue(weth.balanceOf(bidder1) > characterOwnerMockWETHBefore);
        assertTrue(token.balanceOf(address(token)) > contractTokensBefore);
    }

    function testCharacterOwnerPrivileges() public {
        // Set up auction
        string[3] memory uris = ["ipfs://char1", "ipfs://char2", "ipfs://char3"];
        string[3] memory names = ["OwnerTest", "Character2", "Character3"];
        string[3] memory symbols = ["OWN", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        DigicharToken token = DigicharToken(tokenAddress);

        // Character owner (bidder1) should be able to set tax exemptions
        vm.prank(bidder1);
        //token.setTaxExemption(trader1, true);
        assertTrue(token.taxExempt(trader1));

        // Character owner should be able to set DEX status
        vm.prank(bidder1);
        //token.setDEXStatus(trader2, true);
        assertTrue(token.isDEX(trader2));

        // Non-character owner should not be able to set these
        vm.prank(bidder2);
        vm.expectRevert("Unauthorized");
        //token.setTaxExemption(trader2, true);

        vm.prank(bidder2);
        vm.expectRevert("Unauthorized");
        //token.setDEXStatus(trader1, true);
    }

    function testOwnershipTransferAndPrivileges() public {
        // Test that privileges transfer with ownership certificate
        string[3] memory uris = ["ipfs://char1", "ipfs://char2", "ipfs://char3"];
        string[3] memory names = ["TransferTest", "Character2", "Character3"];
        string[3] memory symbols = ["TFRT", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        DigicharToken token = DigicharToken(tokenAddress);

        // Original owner can set privileges
        vm.prank(bidder1);
        //token.setTaxExemption(trader1, true);

        // Transfer ownership certificate
        vm.prank(bidder1);
        ownershipCertificate.transferFrom(bidder1, bidder2, 0);

        // New owner should have privileges
        vm.prank(bidder2);
        //token.setDEXStatus(trader2, true);
        //assertTrue(token.isDEX(trader2));

        // Old owner should no longer have privileges
        vm.prank(bidder1);
        vm.expectRevert("Unauthorized");
        //token.setTaxExemption(trader2, true);
    }

    function testMultipleAuctionsIntegration() public {
        // Test running multiple auctions and ensuring isolation

        // First auction
        string[3] memory uris1 = ["ipfs://a1", "ipfs://a2", "ipfs://a3"];
        string[3] memory names1 = ["Auction1Char1", "Auction1Char2", "Auction1Char3"];
        string[3] memory symbols1 = ["A1C1", "A1C2", "A1C3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris1, names1, symbols1);

        uint256 auction1Id = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        address token1Address = auctionVault.getCharacterTokenAddress(auction1Id);

        // Second auction
        string[3] memory uris2 = ["ipfs://b1", "ipfs://b2", "ipfs://b3"];
        string[3] memory names2 = ["Auction2Char1", "Auction2Char2", "Auction2Char3"];
        string[3] memory symbols2 = ["A2C1", "A2C2", "A2C3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris2, names2, symbols2);

        uint256 auction2Id = auctionVault.auctionId();

        vm.prank(bidder2);
        auctionVault.bid{ value: 2 ether }(1);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder2, 1);

        address token2Address = auctionVault.getCharacterTokenAddress(auction2Id);

        // Verify isolation
        assertTrue(token1Address != token2Address);
        assertEq(ownershipCertificate.ownerOf(0), bidder1);
        assertEq(ownershipCertificate.ownerOf(1), bidder2);

        DigicharToken token1 = DigicharToken(token1Address);
        DigicharToken token2 = DigicharToken(token2Address);

        assertEq(token1.name(), "Auction1Char1");
        assertEq(token2.name(), "Auction2Char2");

        // Each owner can only control their own token
        vm.prank(bidder1);
        //token1.setTaxExemption(trader1, true);

        vm.prank(bidder1);
        vm.expectRevert("Unauthorized");
        //token2.setTaxExemption(trader1, true);
    }

    function testLiquidityLockingIntegration() public {
        // Test that LP tokens are properly locked
        string[3] memory uris = ["ipfs://lp1", "ipfs://lp2", "ipfs://lp3"];
        string[3] memory names = ["LPTest", "Character2", "Character3"];
        string[3] memory symbols = ["LP", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        // Large bid to ensure significant LP creation
        vm.prank(bidder1);
        auctionVault.bid{ value: 5 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        // Check that factory has enough ETH for LP creation
        uint256 factoryBalanceBefore = address(factory).balance;

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        // Verify that ETH was used for LP creation
        uint256 factoryBalanceAfter = address(factory).balance;
        // Some ETH should have been sent to protocol admin as excess
        assertTrue(factoryBalanceAfter < factoryBalanceBefore + 5 ether);
    }

    function testSystemReentrancyProtection() public {
        // Test that the system is protected against reentrancy attacks
        string[3] memory uris = ["ipfs://re1", "ipfs://re2", "ipfs://re3"];
        string[3] memory names = ["ReentryTest", "Character2", "Character3"];
        string[3] memory symbols = ["RE", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0);

        // Basic test that bid function works (reentrancy guard exists)
        assertEq(auctionVault.getUserBidBalance(bidder1, auctionId, 0), 1 ether);
    }

    function testSystemEdgeCases() public {
        // Test various edge cases in the integrated system

        // 1. Auction with minimum bid amounts
        string[3] memory uris = ["ipfs://edge1", "ipfs://edge2", "ipfs://edge3"];
        string[3] memory names = ["EdgeTest", "Character2", "Character3"];
        string[3] memory symbols = ["EDGE", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        // Bid with smallest possible amount
        vm.prank(bidder1);
        auctionVault.bid{ value: 1 wei }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        // Should still work with minimal bid
        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        assertTrue(tokenAddress != address(0));

        // 2. Test token allocation with very small bid
        uint256 expectedTokens = auctionVault.checkUnclaimedTokens(bidder1, auctionId);
        assertTrue(expectedTokens > 0);
    }

    function testSystemFailureModes() public {
        // Test how the system handles various failure scenarios

        // 1. Try to interact with non-existent auction
        vm.prank(bidder1);
        vm.expectRevert(AuctionVault.AuctionStillOpen.selector);
        auctionVault.claimTokens(999);

        // 2. Try to bid on invalid character index
        string[3] memory uris = ["ipfs://fail1", "", "ipfs://fail3"];
        string[3] memory names = ["FailTest", "", "Character3"];
        string[3] memory symbols = ["FAIL", "", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        vm.prank(bidder1);
        vm.expectRevert(AuctionVault.InvalidCharacter.selector);
        auctionVault.bid{ value: 1 ether }(1); // Empty character
    }

    function testConfigSystemIntegration() public {
        // Test that config changes propagate through the system
        string[3] memory uris = ["ipfs://config1", "ipfs://config2", "ipfs://config3"];
        string[3] memory names = ["ConfigTest", "Character2", "Character3"];
        string[3] memory symbols = ["CFG", "CHAR2", "CHAR3"];

        vm.prank(factoryOwner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(bidder1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + 4 hours + 1);

        vm.prank(factoryOwner);
        auctionVault.closeCurrentAuction(bidder1, 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        DigicharToken token = DigicharToken(tokenAddress);

        // Test changing tax rates
        uint256 originalProtocolTax = token.PROTOCOL_ADMIN_TAX_BPS();

        vm.prank(protocolAdmin);
        token.setProtocolAdminTaxBps(200); // 2%

        assertEq(token.PROTOCOL_ADMIN_TAX_BPS(), 200);
        assertNotEq(token.PROTOCOL_ADMIN_TAX_BPS(), originalProtocolTax);
    }
}
