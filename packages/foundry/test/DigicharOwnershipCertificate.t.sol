// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/DigicharOwnershipCertificate.sol";
import "../contracts/DigicharFactory.sol";
import "../contracts/Config.sol";

contract DigicharOwnershipCertificateTest is Test {
    AuctionVault public auctionVault;
    DigicharOwnershipCertificate public ownershipCertificate;
    DigicharFactory public digicharFactory;
    Config public config;
    MockUniswapV2Factory swapFactory;
    MockUniswapV2Router swapRouter;
    ERC20 public weth;

    address public protocolAdmin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public nonFactory = address(0x4);

    event OwnershipCertificateMinted(address _to, uint256 _tokenId, string _tokenURI);
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function setUp() public {
        vm.startPrank(protocolAdmin);

        config = new Config();

        auctionVault = new AuctionVault(address(config));
        digicharFactory = new DigicharFactory(address(config));
        ownershipCertificate = new DigicharOwnershipCertificate(payable(address(digicharFactory)));

        weth = new CustomCoin();
        swapFactory = new MockUniswapV2Factory();
        swapRouter = new MockUniswapV2Router(address(weth));

        config.setAuctionVault(address(auctionVault));
        config.setDigicharFactory(payable(address(digicharFactory)));
        config.setOwnershipCertificate(address(ownershipCertificate));

        config.setSwapFactory(address(swapFactory));
        config.setSwapRouter(address(swapRouter));
        config.setWETH(address(weth));

        vm.stopPrank();
    }

    function testMintSuccess() public {
        string memory tokenURI = "ipfs://QmTest123";

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 0);

        vm.expectEmit(false, false, false, true);
        emit OwnershipCertificateMinted(user1, 0, tokenURI);

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, tokenURI);

        assertEq(tokenId, 0);
        assertEq(ownershipCertificate.ownerOf(0), user1);
        assertEq(ownershipCertificate.tokenURI(0), tokenURI);
        assertEq(ownershipCertificate.balanceOf(user1), 1);
    }

    function testMintOnlyDigicharFactory() public {
        vm.prank(nonFactory);
        vm.expectRevert(DigicharOwnershipCertificate.OnlyDigicharFactory.selector);
        ownershipCertificate.mint(user1, "ipfs://test");
    }

    function testMintMultiple() public {
        string memory tokenURI1 = "ipfs://QmTest1";
        string memory tokenURI2 = "ipfs://QmTest2";
        string memory tokenURI3 = "ipfs://QmTest3";

        vm.startPrank(address(digicharFactory));

        uint256 tokenId1 = ownershipCertificate.mint(user1, tokenURI1);
        uint256 tokenId2 = ownershipCertificate.mint(user2, tokenURI2);
        uint256 tokenId3 = ownershipCertificate.mint(user1, tokenURI3);

        vm.stopPrank();

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);

        assertEq(ownershipCertificate.ownerOf(0), user1);
        assertEq(ownershipCertificate.ownerOf(1), user2);
        assertEq(ownershipCertificate.ownerOf(2), user1);

        assertEq(ownershipCertificate.tokenURI(0), tokenURI1);
        assertEq(ownershipCertificate.tokenURI(1), tokenURI2);
        assertEq(ownershipCertificate.tokenURI(2), tokenURI3);

        assertEq(ownershipCertificate.balanceOf(user1), 2);
        assertEq(ownershipCertificate.balanceOf(user2), 1);
    }

    function testTokenURIRetrieval() public {
        string memory tokenURI = "ipfs://QmLongHashExample123456789";

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, tokenURI);

        assertEq(ownershipCertificate.tokenURI(tokenId), tokenURI);
    }

    function testTokenURIForNonExistentToken() public {
        // ERC721 typically reverts for non-existent tokens, but our implementation returns empty string
        // Let's test what actually happens
        string memory result = ownershipCertificate.tokenURI(999);
        assertEq(result, ""); // Our implementation returns empty string for non-set URIs
    }

    function testTokenIdIncrementing() public {
        vm.startPrank(address(digicharFactory));

        uint256 tokenId1 = ownershipCertificate.mint(user1, "uri1");
        uint256 tokenId2 = ownershipCertificate.mint(user1, "uri2");
        uint256 tokenId3 = ownershipCertificate.mint(user1, "uri3");
        uint256 tokenId4 = ownershipCertificate.mint(user2, "uri4");
        uint256 tokenId5 = ownershipCertificate.mint(user2, "uri5");

        vm.stopPrank();

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
        assertEq(tokenId4, 3);
        assertEq(tokenId5, 4);

        // Verify all tokens exist and have correct owners
        assertEq(ownershipCertificate.ownerOf(0), user1);
        assertEq(ownershipCertificate.ownerOf(1), user1);
        assertEq(ownershipCertificate.ownerOf(2), user1);
        assertEq(ownershipCertificate.ownerOf(3), user2);
        assertEq(ownershipCertificate.ownerOf(4), user2);

        assertEq(ownershipCertificate.balanceOf(user1), 3);
        assertEq(ownershipCertificate.balanceOf(user2), 2);
    }

    function testEmptyTokenURI() public {
        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, "");

        assertEq(ownershipCertificate.tokenURI(tokenId), "");
        assertEq(ownershipCertificate.ownerOf(tokenId), user1);
    }

    function testMintToZeroAddress() public {
        // Should revert when trying to mint to zero address
        vm.prank(address(digicharFactory));
        vm.expectRevert(); // ERC721 should revert on mint to zero address
        ownershipCertificate.mint(address(0), "ipfs://test");
    }

    function testTransferAfterMint() public {
        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, "ipfs://test");

        // Test transfer functionality (inherited from ERC721)
        vm.prank(user1);
        ownershipCertificate.transferFrom(user1, user2, tokenId);

        assertEq(ownershipCertificate.ownerOf(tokenId), user2);
        assertEq(ownershipCertificate.balanceOf(user1), 0);
        assertEq(ownershipCertificate.balanceOf(user2), 1);
    }

    function testApprovalAndTransfer() public {
        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, "ipfs://test");

        // Approve user2 to transfer the token
        vm.prank(user1);
        ownershipCertificate.approve(user2, tokenId);

        assertEq(ownershipCertificate.getApproved(tokenId), user2);

        // User2 transfers the token to themselves
        vm.prank(user2);
        ownershipCertificate.transferFrom(user1, user2, tokenId);

        assertEq(ownershipCertificate.ownerOf(tokenId), user2);
        assertEq(ownershipCertificate.getApproved(tokenId), address(0)); // Approval should be cleared
    }

    function testSetApprovalForAll() public {
        vm.prank(address(digicharFactory));
        ownershipCertificate.mint(user1, "ipfs://test1");

        vm.prank(address(digicharFactory));
        ownershipCertificate.mint(user1, "ipfs://test2");

        // Set approval for all
        vm.prank(user1);
        ownershipCertificate.setApprovalForAll(user2, true);

        assertTrue(ownershipCertificate.isApprovedForAll(user1, user2));

        // User2 can now transfer any of user1's tokens
        vm.prank(user2);
        ownershipCertificate.transferFrom(user1, user2, 0);

        assertEq(ownershipCertificate.ownerOf(0), user2);

        vm.prank(user2);
        ownershipCertificate.transferFrom(user1, user2, 1);

        assertEq(ownershipCertificate.ownerOf(1), user2);
        assertEq(ownershipCertificate.balanceOf(user2), 2);
        assertEq(ownershipCertificate.balanceOf(user1), 0);
    }

    function testSupportsInterface() public {
        // Test ERC721 interface support
        assertTrue(ownershipCertificate.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(ownershipCertificate.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(ownershipCertificate.supportsInterface(0x01ffc9a7)); // ERC165
    }

    function testMintWithSpecialCharactersInURI() public {
        string memory specialURI = "ipfs://QmTest?param=value&other=123#fragment";

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, specialURI);

        assertEq(ownershipCertificate.tokenURI(tokenId), specialURI);
    }

    function testMintWithLongURI() public {
        string memory longURI =
            "ipfs://QmVeryLongHashThatExceedsNormalLengthsAndContainsLotsOfCharacters1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, longURI);

        assertEq(ownershipCertificate.tokenURI(tokenId), longURI);
    }

    function testSafeTransferFrom() public {
        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, "ipfs://test");

        // Test safeTransferFrom
        vm.prank(user1);
        ownershipCertificate.safeTransferFrom(user1, user2, tokenId);

        assertEq(ownershipCertificate.ownerOf(tokenId), user2);
    }

    function testSafeTransferFromWithData() public {
        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, "ipfs://test");

        bytes memory data = "test data";

        // Test safeTransferFrom with data
        vm.prank(user1);
        ownershipCertificate.safeTransferFrom(user1, user2, tokenId, data);

        assertEq(ownershipCertificate.ownerOf(tokenId), user2);
    }

    // Fuzz testing
    function testFuzzMintToRandomAddresses(address to) public {
        vm.assume(to != address(0)); // Can't mint to zero address
        vm.assume(to.code.length == 0); // Avoid contracts that might not handle ERC721

        string memory tokenURI = "ipfs://fuzztest";

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(to, tokenURI);

        assertEq(ownershipCertificate.ownerOf(tokenId), to);
        assertEq(ownershipCertificate.tokenURI(tokenId), tokenURI);
        assertEq(ownershipCertificate.balanceOf(to), 1);
    }

    function testFuzzTokenURIStrings(string memory tokenURI) public {
        // Assume non-empty string to avoid edge cases
        vm.assume(bytes(tokenURI).length > 0);
        vm.assume(bytes(tokenURI).length < 1000); // Reasonable limit

        vm.prank(address(digicharFactory));
        uint256 tokenId = ownershipCertificate.mint(user1, tokenURI);

        assertEq(ownershipCertificate.tokenURI(tokenId), tokenURI);
    }

    function testFuzzMultipleMints(uint8 numMints) public {
        vm.assume(numMints > 0 && numMints <= 50); // Reasonable limits

        vm.startPrank(address(digicharFactory));

        for (uint8 i = 0; i < numMints; i++) {
            string memory uri = string(abi.encodePacked("ipfs://test", vm.toString(i)));
            uint256 tokenId = ownershipCertificate.mint(user1, uri);
            assertEq(tokenId, i);
            assertEq(ownershipCertificate.tokenURI(tokenId), uri);
        }

        vm.stopPrank();

        assertEq(ownershipCertificate.balanceOf(user1), numMints);

        // Verify all tokens are owned by user1
        for (uint8 i = 0; i < numMints; i++) {
            assertEq(ownershipCertificate.ownerOf(i), user1);
        }
    }

    function testAccessControlComprehensive() public {
        address[] memory nonFactoryAddresses = new address[](3);
        nonFactoryAddresses[0] = user1;
        nonFactoryAddresses[1] = user2;
        nonFactoryAddresses[2] = protocolAdmin; // Even protocol admin can't call mint directly

        for (uint256 i = 0; i < nonFactoryAddresses.length; i++) {
            vm.prank(nonFactoryAddresses[i]);
            vm.expectRevert(DigicharOwnershipCertificate.OnlyDigicharFactory.selector);
            ownershipCertificate.mint(user1, "ipfs://test");
        }
    }

    function testMintReturnValue() public {
        vm.startPrank(address(digicharFactory));

        // Test that returned token IDs are sequential and start from 0
        for (uint256 i = 0; i < 10; i++) {
            uint256 returnedTokenId = ownershipCertificate.mint(user1, "ipfs://test");
            assertEq(returnedTokenId, i);
        }

        vm.stopPrank();
    }

    function testInternalStateConsistency() public {
        vm.startPrank(address(digicharFactory));

        // Mint several tokens and verify internal state consistency
        ownershipCertificate.mint(user1, "uri1");
        ownershipCertificate.mint(user2, "uri2");
        ownershipCertificate.mint(user1, "uri3");

        vm.stopPrank();

        // Verify total supply-like behavior (ERC721 doesn't have totalSupply by default)
        // We can infer it from the fact that token IDs are sequential
        assertEq(ownershipCertificate.ownerOf(0), user1);
        assertEq(ownershipCertificate.ownerOf(1), user2);
        assertEq(ownershipCertificate.ownerOf(2), user1);

        // Check that non-existent token 3 doesn't have an owner
        vm.expectRevert();
        ownershipCertificate.ownerOf(3);
    }

    function testMintEventEmission() public {
        string memory tokenURI = "ipfs://eventtest";

        // Check that both Transfer (from ERC721) and OwnershipCertificateMinted events are emitted
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), user1, 0);

        vm.expectEmit(false, false, false, true);
        emit OwnershipCertificateMinted(user1, 0, tokenURI);

        vm.prank(address(digicharFactory));
        ownershipCertificate.mint(user1, tokenURI);
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
