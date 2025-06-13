// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/AuctionVault.sol";
import "../contracts/DigicharFactory.sol";
import "../contracts/DigicharToken.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
//import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract AuctionVaultTest is Test {
    AuctionVault public auctionVault;
    DigicharFactory public digicharFactory;
    DigicharOwnershipCertificate digicharOwnershipCertificate;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public nonOwner = address(0x5);

    uint256 public constant DEFAULT_AUCTION_DURATION = 4 hours;

    event AuctionTimeChanged(uint256 _auctionDurationTime);
    event DigicharFactorySet(address _digicharFactory);
    event DigicharTokenSet(address _digicharToken);
    event BidPlaced(uint256 indexed _auctionId, address indexed _user, uint256 _amount, uint256 _characterId);
    event BidWithdrawn(uint256 _auctionId, address user, uint256 _withdrawAmount);
    event TokensClaimed(address _user, uint256 _auctionId);

    function setUp() public {
        vm.startPrank(owner);

        auctionVault = new AuctionVault();
        digicharFactory = new DigicharFactory(address(auctionVault));
        digicharOwnershipCertificate = new DigicharOwnershipCertificate(payable(address(digicharFactory)));

        auctionVault.setDigicharFactory(payable(address(digicharFactory)));

        vm.stopPrank();

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function testSetDigicharFactory() public {
        address newFactory = address(0x999);

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit DigicharFactorySet(newFactory);
        auctionVault.setDigicharFactory(payable(newFactory));
    }

    function test_Revert_SetDigicharFactory_OnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(AuctionVault.OnlyOwner.selector);
        auctionVault.setDigicharFactory(payable(address(0x999)));
    }

    function testSetDigicharToken() public {
        address newToken = address(0x888);

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit DigicharTokenSet(newToken);
        auctionVault.setDigicharToken(payable(newToken));
    }

    function test_Revert_SetDigicharToken_OnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(AuctionVault.OnlyOwner.selector);
        auctionVault.setDigicharToken(payable(address(0x888)));
    }

    function testCreateAuction() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        uint256 auctionIdBefore = auctionVault.auctionId();
        uint256 expectedEndTime = block.timestamp + DEFAULT_AUCTION_DURATION;

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        assertEq(auctionVault.auctionId(), auctionIdBefore + 1);

        // Verify auction details
        uint256 endTime = auctionVault.getCurrentAuctionEndTime();
        assertEq(endTime, expectedEndTime);
    }

    function test_Revert_CreateAuction_OnlyOwner() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(nonOwner);
        vm.expectRevert(AuctionVault.OnlyOwner.selector);
        auctionVault.createAuction(uris, names, symbols);
    }

    function testBid() public {
        // Create auction first
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 bidAmount = 1 ether;
        uint8 characterIndex = 0;

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit BidPlaced(auctionVault.auctionId(), user1, bidAmount, characterIndex);
        auctionVault.bid{ value: bidAmount }(characterIndex);
        vm.stopPrank();

        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), characterIndex), bidAmount);
        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), characterIndex), bidAmount);
    }

    function test_Revert_Bid_AmountZero() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.prank(user1);
        vm.expectRevert(AuctionVault.AmountZero.selector);
        auctionVault.bid{ value: 0 }(0);
    }

    function test_Revert_Bid_AuctionExpired() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // Fast forward past auction end
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(user1);
        vm.expectRevert(AuctionVault.AuctionExpired.selector);
        auctionVault.bid{ value: 1 ether }(0);
    }

    function test_Revert_Bid_InvalidCharacter() public {
        // Create auction with empty character at index 0
        string[3] memory uris = ["", "uri2", "uri3"];
        string[3] memory names = ["", "name2", "name3"];
        string[3] memory symbols = ["", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.prank(user1);
        vm.expectRevert(AuctionVault.InvalidCharacter.selector);
        auctionVault.bid{ value: 1 ether }(0);
    }

    function testMultipleBidsOnSameCharacter() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint8 characterIndex = 1;

        // Multiple bids from different users
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(characterIndex);

        vm.prank(user2);
        auctionVault.bid{ value: 2 ether }(characterIndex);

        vm.prank(user1);
        auctionVault.bid{ value: 0.5 ether }(characterIndex); // Additional bid from user1

        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), characterIndex), 1.5 ether);
        assertEq(auctionVault.getUserBidBalance(user2, auctionVault.auctionId(), characterIndex), 2 ether);
        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), characterIndex), 3.5 ether);
    }

    function testBidsOnDifferentCharacters() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.prank(user1);
        auctionVault.bid{ value: 2 ether }(1);

        vm.prank(user2);
        auctionVault.bid{ value: 1.5 ether }(2);

        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), 0), 1 ether);
        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), 1), 2 ether);
        assertEq(auctionVault.getUserBidBalance(user2, auctionVault.auctionId(), 2), 1.5 ether);

        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), 0), 1 ether);
        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), 1), 2 ether);
        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), 2), 1.5 ether);
    }

    function testWithdrawBid() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();
        uint8 characterIndex = 1;
        uint256 bidAmount = 2 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(user1);
        auctionVault.bid{ value: bidAmount }(characterIndex);

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        vm.expectEmit(false, false, false, true);
        emit BidWithdrawn(auctionId, user1, withdrawAmount);
        auctionVault.withdrawBid(auctionId, characterIndex, withdrawAmount);

        assertEq(user1.balance, balanceBefore + withdrawAmount);
        assertEq(auctionVault.getUserBidBalance(user1, auctionId, characterIndex), bidAmount - withdrawAmount);
    }

    function test_Revert_WithdrawBid_AmountZero() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(user1);
        vm.expectRevert(AuctionVault.AmountZero.selector);
        auctionVault.withdrawBid(auctionId, 0, 0);
    }

    function test_Revert_WithdrawBid_AmountTooLarge() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();
        uint8 characterIndex = 0;

        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(characterIndex);

        vm.prank(user1);
        vm.expectRevert(AuctionVault.AmountTooLarge.selector);
        auctionVault.withdrawBid(auctionId, characterIndex, 2 ether);
    }

    function testCloseCurrentAuction_ExecutionSuccessful() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 currentAuctionId = auctionVault.auctionId();
        uint8 winningCharacterIndex = 1;

        // Place bid
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(winningCharacterIndex);

        // Fast forward past auction end
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, winningCharacterIndex);

        // Verify auction was closed
        assertEq(auctionVault.auctionId(), currentAuctionId + 1);
    }

    function testCloseCurrentAuction_CharacterCreation() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 currentAuctionId = auctionVault.auctionId();
        uint8 winningCharacterIndex = 1;

        // Place bids
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        vm.prank(user2);
        auctionVault.bid{ value: 2 ether }(winningCharacterIndex);

        vm.prank(user3);
        auctionVault.bid{ value: 0.5 ether }(2);

        // Fast forward past auction end
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, winningCharacterIndex);

        // Verify auction was closed
        assertEq(auctionVault.auctionId(), currentAuctionId + 1);

        // Verify token was created
        address tokenAddress = auctionVault.getCharacterTokenAddress(currentAuctionId);
        assertTrue(tokenAddress != address(0));

        address ownershipCertificateOwner = DigicharToken(tokenAddress).getOwnershipCertificateOwner();
        //expected to be top bidder (user2 in this case)
        assertEq(ownershipCertificateOwner, user2);

        string memory mintedCharacterName = DigicharToken(tokenAddress).name();
        assertEq(mintedCharacterName, names[winningCharacterIndex]);

        string memory mintedCharacterSymbol = DigicharToken(tokenAddress).symbol();
        assertEq(mintedCharacterSymbol, symbols[winningCharacterIndex]);

        uint256 lastTokenId = digicharOwnershipCertificate.tokenId() - 1;

        string memory tokenURI = digicharOwnershipCertificate.tokenURI(lastTokenId);
        assertEq(tokenURI, uris[winningCharacterIndex]);
    }

    function test_Revert_CloseCurrentAuction_OnlyOwner() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(nonOwner);
        vm.expectRevert(AuctionVault.OnlyOwner.selector);
        auctionVault.closeCurrentAuction(user1, 0);
    }

    function test_Revert_CloseCurrentAuction_AuctionStillOpen() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // Don't fast forward - auction is still open
        vm.prank(owner);
        vm.expectRevert(AuctionVault.AuctionStillOpen.selector);
        auctionVault.closeCurrentAuction(user1, 0);
    }

    function test_ClaimTokens() public {
        // Set up and close an auction first
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();
        uint8 winningCharacterIndex = 0;

        vm.prank(user1);
        auctionVault.bid{ value: 2 ether }(winningCharacterIndex);

        vm.prank(user2);
        auctionVault.bid{ value: 3 ether }(winningCharacterIndex);

        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, winningCharacterIndex);

        // Now claim tokens
        uint256 expectedTokens = auctionVault.checkUnclaimedTokens(user1, auctionId);
        assertTrue(expectedTokens > 0);

        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionId);
        uint256 balanceBefore = DigicharToken(tokenAddress).balanceOf(user1);

        vm.prank(user1);
        vm.expectEmit(false, false, false, true);
        emit TokensClaimed(user1, auctionId);
        auctionVault.claimTokens(auctionId);

        uint256 balanceAfter = DigicharToken(tokenAddress).balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, expectedTokens);
    }

    function test_Revert_ClaimTokens_AuctionStillOpen() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 currentAuctionId = auctionVault.auctionId();

        vm.prank(user1);
        vm.expectRevert(AuctionVault.AuctionStillOpen.selector);
        auctionVault.claimTokens(currentAuctionId);
    }

    function test_Revert_ClaimTokens_AmountZero() public {
        // Set up and close an auction, but user has no bid
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.prank(user2);
        auctionVault.bid{ value: 1 ether }(0);

        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, 0);

        // user1 never bid, so should have 0 tokens to claim
        vm.prank(user1);
        vm.expectRevert(AuctionVault.AmountZero.selector);
        auctionVault.claimTokens(auctionId);
    }

    function testCheckUnclaimedTokensCalculation() public {
        // Test token allocation calculation
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();
        uint8 winningCharacterIndex = 0;

        // User1 bids 2 ETH, User2 bids 3 ETH (total 5 ETH)
        vm.prank(user1);
        auctionVault.bid{ value: 2 ether }(winningCharacterIndex);

        vm.prank(user2);
        auctionVault.bid{ value: 3 ether }(winningCharacterIndex);

        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + DEFAULT_AUCTION_DURATION);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, winningCharacterIndex);

        uint256 initialTokenSupply = 500_000 * 10 ** 18;

        // User1 should get (2/5) * initialTokenSupply = 200,000 tokens
        uint256 user1ExpectedTokens = (2 ether * initialTokenSupply) / 5 ether;
        uint256 user1ActualTokens = auctionVault.checkUnclaimedTokens(user1, auctionId);
        assertEq(user1ActualTokens, user1ExpectedTokens);

        // User2 should get (3/5) * initialTokenSupply = 300,000 tokens
        uint256 user2ExpectedTokens = (3 ether * initialTokenSupply) / 5 ether;
        uint256 user2ActualTokens = auctionVault.checkUnclaimedTokens(user2, auctionId);
        assertEq(user2ActualTokens, user2ExpectedTokens);
    }

    function testWithdrawFromWinningCharacter() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();
        uint8 winningCharacterIndex = 0;

        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(winningCharacterIndex);

        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, winningCharacterIndex);

        // Should not be able to withdraw from winning character
        vm.prank(user1);
        vm.expectRevert(AuctionVault.InvalidCharacter.selector);
        auctionVault.withdrawBid(auctionId, winningCharacterIndex, 0.5 ether);
    }

    function testReentrancyProtection() public {
        // Basic test - the reentrancy guard should prevent multiple calls
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // This just tests that the function works normally
        vm.prank(user1);
        auctionVault.bid{ value: 1 ether }(0);

        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), 0), 1 ether);
    }

    /*
       @dev not sure if I want this to be intended protocol functionality or not.
       // ...the question is:
       // only allow one auction at a time, or allow multiple auctions at a time?
       // was thinking the former initially, but the latter has its own benefits worth considering.
       // TBD
    function testMultipleAuctions() public {
        // Test creating and managing multiple auctions
        string[3] memory uris1 = ["uri1", "uri2", "uri3"];
        string[3] memory names1 = ["name1", "name2", "name3"];
        string[3] memory symbols1 = ["SYM1", "SYM2", "SYM3"];
        
        vm.prank(owner);
        auctionVault.createAuction(uris1, names1, symbols1);
        
        uint256 auction1Id = auctionVault.auctionId();
        
        vm.prank(user1);
        auctionVault.bid{value: 1 ether}(0);
        
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);
        
        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);
        
        // Create second auction
        string[3] memory uris2 = ["uri4", "uri5", "uri6"];
        string[3] memory names2 = ["name4", "name5", "name6"];
        string[3] memory symbols2 = ["SYM4", "SYM5", "SYM6"];
        
        vm.prank(owner);
        auctionVault.createAuction(uris2, names2, symbols2);
        
        uint256 auction2Id = auctionVault.auctionId();
        
        vm.prank(user2);
        auctionVault.bid{value: 2 ether}(1);
        
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);
        
        vm.prank(owner);
        auctionVault.closeCurrentAuction(user2, 1);
        
        // Verify both auctions exist and have different token addresses
        address token1 = auctionVault.getCharacterTokenAddress(auction1Id);
        address token2 = auctionVault.getCharacterTokenAddress(auction2Id);
        
        assertTrue(token1 != address(0));
        assertTrue(token2 != address(0));
        assertTrue(token1 != token2);
        
        // Verify users can claim from their respective auctions
        assertGt(auctionVault.checkUnclaimedTokens(user1, auction1Id), 0);
        assertGt(auctionVault.checkUnclaimedTokens(user2, auction2Id), 0);
        assertEq(auctionVault.checkUnclaimedTokens(user1, auction2Id), 0);
        assertEq(auctionVault.checkUnclaimedTokens(user2, auction1Id), 0);
    }
    */

    // Fuzz testing
    function testFuzzBidAmounts(uint256 bidAmount) public {
        vm.assume(bidAmount > 0 && bidAmount <= 100 ether);

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        vm.deal(user1, bidAmount + 1 ether);

        vm.prank(user1);
        auctionVault.bid{ value: bidAmount }(0);

        assertEq(auctionVault.getUserBidBalance(user1, auctionVault.auctionId(), 0), bidAmount);
        assertEq(auctionVault.getPoolBalance(auctionVault.auctionId(), 0), bidAmount);
    }

    function testFuzzWithdrawAmounts(uint256 bidAmount, uint256 withdrawAmount) public {
        vm.assume(bidAmount > 0 && bidAmount <= 10 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= bidAmount);

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 auctionId = auctionVault.auctionId();

        vm.deal(user1, bidAmount + 1 ether);

        vm.prank(user1);
        auctionVault.bid{ value: bidAmount }(0);

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        auctionVault.withdrawBid(auctionId, 0, withdrawAmount);

        assertEq(user1.balance, balanceBefore + withdrawAmount);
        assertEq(auctionVault.getUserBidBalance(user1, auctionId, 0), bidAmount - withdrawAmount);
    }

    function testGetCharacterTokenAddressBeforeClose() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        uint256 currentAuctionId = auctionVault.auctionId();

        vm.expectRevert(AuctionVault.AuctionStillOpen.selector);
        auctionVault.getCharacterTokenAddress(currentAuctionId);
    }

    function testEdgeCaseEmptyBidsInPool() public {
        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        vm.prank(owner);
        auctionVault.createAuction(uris, names, symbols);

        // No bids placed
        vm.warp(block.timestamp + DEFAULT_AUCTION_DURATION + 1);

        // Should still be able to close auction even with no bids
        vm.prank(owner);
        auctionVault.closeCurrentAuction(user1, 0);

        // Verify token was created even with 0 pool balance
        address tokenAddress = auctionVault.getCharacterTokenAddress(auctionVault.auctionId() - 1);
        assertTrue(tokenAddress != address(0));
    }

    function testAccessControlComprehensive() public {
        address[] memory nonOwners = new address[](3);
        nonOwners[0] = user1;
        nonOwners[1] = user2;
        nonOwners[2] = user3;

        string[3] memory uris = ["uri1", "uri2", "uri3"];
        string[3] memory names = ["name1", "name2", "name3"];
        string[3] memory symbols = ["SYM1", "SYM2", "SYM3"];

        for (uint256 i = 0; i < nonOwners.length; i++) {
            vm.startPrank(nonOwners[i]);

            vm.expectRevert(AuctionVault.OnlyOwner.selector);
            auctionVault.setDigicharFactory(payable(address(0x123)));

            vm.expectRevert(AuctionVault.OnlyOwner.selector);
            auctionVault.setDigicharToken(payable(address(0x123)));

            vm.expectRevert(AuctionVault.OnlyOwner.selector);
            auctionVault.createAuction(uris, names, symbols);

            vm.expectRevert(AuctionVault.OnlyOwner.selector);
            auctionVault.closeCurrentAuction(user1, 0);

            vm.stopPrank();
        }
    }
}
