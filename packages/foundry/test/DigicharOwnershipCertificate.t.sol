// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
import "../contracts/DigicharFactory.sol";

contract DigicharOwnershipCertificateTest is Test {
    DigicharOwnershipCertificate public certificate;
    DigicharFactory public factory;

    address public factoryOwner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public nonFactory = address(0x4);

    event OwnershipCertificateMinted(address _to, uint256 _tokenId, string _tokenURI);
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function setUp() public {
        vm.startPrank(factoryOwner);

        // Deploy factory first (with dummy auction vault)
        factory = new DigicharFactory(address(0x999));

        // Deploy certificate
        certificate = new DigicharOwnershipCertificate(payable(address(factory)));

        vm.stopPrank();
    }

    function testConstructor() public {
        assertEq(certificate.name(), "Digichar Ownership Certificate");
        assertEq(certificate.symbol(), "DCO");
        assertEq(address(certificate.digicharFactory()), address(factory));
    }

    function testMintSuccess() public {
        string memory tokenURI = "ipfs://QmTest123";

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 0);

        vm.expectEmit(false, false, false, true);
        emit OwnershipCertificateMinted(user1, 0, tokenURI);

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, tokenURI);

        assertEq(tokenId, 0);
        assertEq(certificate.ownerOf(0), user1);
        assertEq(certificate.tokenURI(0), tokenURI);
        assertEq(certificate.balanceOf(user1), 1);
    }

    function testMintOnlyDigicharFactory() public {
        vm.prank(nonFactory);
        vm.expectRevert(DigicharOwnershipCertificate.OnlyDigicharFactory.selector);
        certificate.mint(user1, "ipfs://test");
    }

    function testMintMultiple() public {
        string memory tokenURI1 = "ipfs://QmTest1";
        string memory tokenURI2 = "ipfs://QmTest2";
        string memory tokenURI3 = "ipfs://QmTest3";

        vm.startPrank(address(factory));

        uint256 tokenId1 = certificate.mint(user1, tokenURI1);
        uint256 tokenId2 = certificate.mint(user2, tokenURI2);
        uint256 tokenId3 = certificate.mint(user1, tokenURI3);

        vm.stopPrank();

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);

        assertEq(certificate.ownerOf(0), user1);
        assertEq(certificate.ownerOf(1), user2);
        assertEq(certificate.ownerOf(2), user1);

        assertEq(certificate.tokenURI(0), tokenURI1);
        assertEq(certificate.tokenURI(1), tokenURI2);
        assertEq(certificate.tokenURI(2), tokenURI3);

        assertEq(certificate.balanceOf(user1), 2);
        assertEq(certificate.balanceOf(user2), 1);
    }

    function testTokenURIRetrieval() public {
        string memory tokenURI = "ipfs://QmLongHashExample123456789";

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, tokenURI);

        assertEq(certificate.tokenURI(tokenId), tokenURI);
    }

    function testTokenURIForNonExistentToken() public {
        // ERC721 typically reverts for non-existent tokens, but our implementation returns empty string
        // Let's test what actually happens
        string memory result = certificate.tokenURI(999);
        assertEq(result, ""); // Our implementation returns empty string for non-set URIs
    }

    function testTokenIdIncrementing() public {
        vm.startPrank(address(factory));

        uint256 tokenId1 = certificate.mint(user1, "uri1");
        uint256 tokenId2 = certificate.mint(user1, "uri2");
        uint256 tokenId3 = certificate.mint(user1, "uri3");
        uint256 tokenId4 = certificate.mint(user2, "uri4");
        uint256 tokenId5 = certificate.mint(user2, "uri5");

        vm.stopPrank();

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
        assertEq(tokenId4, 3);
        assertEq(tokenId5, 4);

        // Verify all tokens exist and have correct owners
        assertEq(certificate.ownerOf(0), user1);
        assertEq(certificate.ownerOf(1), user1);
        assertEq(certificate.ownerOf(2), user1);
        assertEq(certificate.ownerOf(3), user2);
        assertEq(certificate.ownerOf(4), user2);

        assertEq(certificate.balanceOf(user1), 3);
        assertEq(certificate.balanceOf(user2), 2);
    }

    function testEmptyTokenURI() public {
        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, "");

        assertEq(certificate.tokenURI(tokenId), "");
        assertEq(certificate.ownerOf(tokenId), user1);
    }

    function testMintToZeroAddress() public {
        // Should revert when trying to mint to zero address
        vm.prank(address(factory));
        vm.expectRevert(); // ERC721 should revert on mint to zero address
        certificate.mint(address(0), "ipfs://test");
    }

    function testTransferAfterMint() public {
        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, "ipfs://test");

        // Test transfer functionality (inherited from ERC721)
        vm.prank(user1);
        certificate.transferFrom(user1, user2, tokenId);

        assertEq(certificate.ownerOf(tokenId), user2);
        assertEq(certificate.balanceOf(user1), 0);
        assertEq(certificate.balanceOf(user2), 1);
    }

    function testApprovalAndTransfer() public {
        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, "ipfs://test");

        // Approve user2 to transfer the token
        vm.prank(user1);
        certificate.approve(user2, tokenId);

        assertEq(certificate.getApproved(tokenId), user2);

        // User2 transfers the token to themselves
        vm.prank(user2);
        certificate.transferFrom(user1, user2, tokenId);

        assertEq(certificate.ownerOf(tokenId), user2);
        assertEq(certificate.getApproved(tokenId), address(0)); // Approval should be cleared
    }

    function testSetApprovalForAll() public {
        vm.prank(address(factory));
        certificate.mint(user1, "ipfs://test1");

        vm.prank(address(factory));
        certificate.mint(user1, "ipfs://test2");

        // Set approval for all
        vm.prank(user1);
        certificate.setApprovalForAll(user2, true);

        assertTrue(certificate.isApprovedForAll(user1, user2));

        // User2 can now transfer any of user1's tokens
        vm.prank(user2);
        certificate.transferFrom(user1, user2, 0);

        assertEq(certificate.ownerOf(0), user2);

        vm.prank(user2);
        certificate.transferFrom(user1, user2, 1);

        assertEq(certificate.ownerOf(1), user2);
        assertEq(certificate.balanceOf(user2), 2);
        assertEq(certificate.balanceOf(user1), 0);
    }

    function testSupportsInterface() public {
        // Test ERC721 interface support
        assertTrue(certificate.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(certificate.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(certificate.supportsInterface(0x01ffc9a7)); // ERC165
    }

    function testMintWithSpecialCharactersInURI() public {
        string memory specialURI = "ipfs://QmTest?param=value&other=123#fragment";

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, specialURI);

        assertEq(certificate.tokenURI(tokenId), specialURI);
    }

    function testMintWithLongURI() public {
        string memory longURI =
            "ipfs://QmVeryLongHashThatExceedsNormalLengthsAndContainsLotsOfCharacters1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, longURI);

        assertEq(certificate.tokenURI(tokenId), longURI);
    }

    function testSafeTransferFrom() public {
        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, "ipfs://test");

        // Test safeTransferFrom
        vm.prank(user1);
        certificate.safeTransferFrom(user1, user2, tokenId);

        assertEq(certificate.ownerOf(tokenId), user2);
    }

    function testSafeTransferFromWithData() public {
        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, "ipfs://test");

        bytes memory data = "test data";

        // Test safeTransferFrom with data
        vm.prank(user1);
        certificate.safeTransferFrom(user1, user2, tokenId, data);

        assertEq(certificate.ownerOf(tokenId), user2);
    }

    // Fuzz testing
    function testFuzzMintToRandomAddresses(address to) public {
        vm.assume(to != address(0)); // Can't mint to zero address
        vm.assume(to.code.length == 0); // Avoid contracts that might not handle ERC721

        string memory tokenURI = "ipfs://fuzztest";

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(to, tokenURI);

        assertEq(certificate.ownerOf(tokenId), to);
        assertEq(certificate.tokenURI(tokenId), tokenURI);
        assertEq(certificate.balanceOf(to), 1);
    }

    function testFuzzTokenURIStrings(string memory tokenURI) public {
        // Assume non-empty string to avoid edge cases
        vm.assume(bytes(tokenURI).length > 0);
        vm.assume(bytes(tokenURI).length < 1000); // Reasonable limit

        vm.prank(address(factory));
        uint256 tokenId = certificate.mint(user1, tokenURI);

        assertEq(certificate.tokenURI(tokenId), tokenURI);
    }

    function testFuzzMultipleMints(uint8 numMints) public {
        vm.assume(numMints > 0 && numMints <= 50); // Reasonable limits

        vm.startPrank(address(factory));

        for (uint8 i = 0; i < numMints; i++) {
            string memory uri = string(abi.encodePacked("ipfs://test", vm.toString(i)));
            uint256 tokenId = certificate.mint(user1, uri);
            assertEq(tokenId, i);
            assertEq(certificate.tokenURI(tokenId), uri);
        }

        vm.stopPrank();

        assertEq(certificate.balanceOf(user1), numMints);

        // Verify all tokens are owned by user1
        for (uint8 i = 0; i < numMints; i++) {
            assertEq(certificate.ownerOf(i), user1);
        }
    }

    function testAccessControlComprehensive() public {
        address[] memory nonFactoryAddresses = new address[](3);
        nonFactoryAddresses[0] = user1;
        nonFactoryAddresses[1] = user2;
        nonFactoryAddresses[2] = factoryOwner; // Even factory owner can't call mint directly

        for (uint256 i = 0; i < nonFactoryAddresses.length; i++) {
            vm.prank(nonFactoryAddresses[i]);
            vm.expectRevert(DigicharOwnershipCertificate.OnlyDigicharFactory.selector);
            certificate.mint(user1, "ipfs://test");
        }
    }

    function testMintReturnValue() public {
        vm.startPrank(address(factory));

        // Test that returned token IDs are sequential and start from 0
        for (uint256 i = 0; i < 10; i++) {
            uint256 returnedTokenId = certificate.mint(user1, "ipfs://test");
            assertEq(returnedTokenId, i);
        }

        vm.stopPrank();
    }

    function testInternalStateConsistency() public {
        vm.startPrank(address(factory));

        // Mint several tokens and verify internal state consistency
        certificate.mint(user1, "uri1");
        certificate.mint(user2, "uri2");
        certificate.mint(user1, "uri3");

        vm.stopPrank();

        // Verify total supply-like behavior (ERC721 doesn't have totalSupply by default)
        // We can infer it from the fact that token IDs are sequential
        assertEq(certificate.ownerOf(0), user1);
        assertEq(certificate.ownerOf(1), user2);
        assertEq(certificate.ownerOf(2), user1);

        // Check that non-existent token 3 doesn't have an owner
        vm.expectRevert();
        certificate.ownerOf(3);
    }

    function testMintEventEmission() public {
        string memory tokenURI = "ipfs://eventtest";

        // Check that both Transfer (from ERC721) and OwnershipCertificateMinted events are emitted
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), user1, 0);

        vm.expectEmit(false, false, false, true);
        emit OwnershipCertificateMinted(user1, 0, tokenURI);

        vm.prank(address(factory));
        certificate.mint(user1, tokenURI);
    }
}
