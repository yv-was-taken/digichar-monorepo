// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { DigicharToken } from "./DigicharToken.sol";
import { AuctionVault } from "./AuctionVault.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";

contract DigicharFactory {
    error OnlyAuctionVault();

    modifier onlyAuctionVault() {
        if (msg.sender != address(auctionVault)) revert OnlyAuctionVault();
        _;
    }

    error OnlyOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    address public owner;
    AuctionVault public auctionVault;
    address targetDex; //@dev, need to surf around hyperevm and find which dex is best...

    constructor(address _auctionVault) {
        auctionVault = AuctionVault(_auctionVault);
        owner = msg.sender;
    }

    event TargetDexUpdated(address _newTargetDex);

    function updateTargetDex(address _newTargetDex) public onlyOwner {
        targetDex = _newTargetDex;
        emit TargetDexUpdated(_newTargetDex);
    }

    DigicharOwnershipCertificate digicharOwnershipCertificate;

    event DigicharOwnershipCertificateSet(address _digicharOwnershipCertificate);

    function setDigicharOwnershipCertificate(address _digicharOwnershipCertificate) external onlyOwner {
        digicharOwnershipCertificate = DigicharOwnershipCertificate(_digicharOwnershipCertificate);
        emit DigicharOwnershipCertificateSet(_digicharOwnershipCertificate);
    }

    function createCharacter(
        address _winningBidder,
        uint256 _winningCharacterIndex,
        string memory _characterTokenURI,
        string memory _characterName,
        string memory _characterSymbol
    ) public payable onlyAuctionVault {
        //@dev mint character nft and send them ownership certificate
        digicharOwnershipCertificate.mint(_winningBidder, _characterTokenURI);

        //@dev create character token using LP from winning bid pool to DigicharFactory
        uint256 _auctionId = auctionVault.auctionId();
        uint256 winningPoolBalance = auctionVault.getPoolBalance(_auctionId, _winningCharacterIndex);

        //@TODO create token pair, create LP using `winningPoolBalance`, lock LP by sending LP to zero address
        address _tokenAddress = createToken(_characterName, _characterSymbol);
        address _pairAddress = createTokenPair(_tokenAddress);
        createLPforTokenPair(
            _tokenAddress,
            _pairAddress,
            //@dev locking half of total supply in LP
            // this amount needs to be played with to find a good starting value
            // @TODO extract token supply metrics to contract config
            500_000 / 2,
            //@dev setting tokenAmountMin and ethAmountMin to zero as not needed metric for initial LP creation
            0,
            0
        );
    }

    event TokenCreated(address indexed _token, string _name, string _symbol);

    function createToken(string memory _name, string memory _symbol) private returns (address) {
        address tokenAddress = address(new DigicharToken(address(auctionVault), _name, _symbol));
        return tokenAddress;
    }

    event PairCreated(address indexed _token, address indexed _pair);

    function createTokenPair(address _tokenAddress) private returns (address pair) {
        // Create swap pair
        address weth = swapRouter.WETH();
        pair = swapFactory.createPair(_tokenAddress, weth);
        emit PairCreated(_tokenAddress, pair);

        return (pair);
    }

    IUniswapV2Router02 swapRouter;

    event SwapRouterSet(address indexed _swapRouter);

    function setSwapRouter(address _swapRouter) external onlyOwner {
        swapRouter = IUniswapV2Router02(_swapRouter);
        emit SwapRouterSet(_swapRouter);
    }

    IUniswapV2Factory swapFactory;

    event SwapFactorySet(address indexed _swapFactory);

    function setSwapFactory(address _swapFactory) external onlyOwner {
        swapFactory = IUniswapV2Factory(_swapFactory);
        emit SwapFactorySet(_swapFactory);
    }

    event LPInitialized(
        address indexed _token, address indexed _pair, uint256 _amountToken, uint256 _amountEth, uint256 _liquidity
    );

    function createLPforTokenPair(
        address token,
        address pair,
        uint256 tokenAmount, //@dev should be fetched from contract config
        uint256 tokenAmountMin, //@dev should be fetched from contract config
        uint256 ethAmountMin //@dev should be fetched from contract config
    ) private {
        require(msg.value > 0, "Must send ETH");
        require(tokenAmount > 0, "Token amount must be > 0");

        // Approve router
        DigicharToken(token).approve(address(swapRouter), tokenAmount);

        // Add liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = swapRouter.addLiquidityETH{ value: msg.value }(
            token,
            tokenAmount,
            tokenAmountMin,
            ethAmountMin,
            msg.sender,
            block.timestamp + 1 //deadline
        );

        //// Refund excess tokens and ETH
        //if (tokenAmount > amountToken) {
        //    SimpleToken(token).transfer(msg.sender, tokenAmount - amountToken);
        //}
        if (msg.value > amountETH) {
            //@dev sending leftover ETH from LP creation back to AuctionVault
            (bool success,) = payable(address(auctionVault)).call{ value: msg.value - amountETH }("");
            require(success, "ETH transfer failed");
        }
        emit LPInitialized(token, pair, amountToken, amountETH, liquidity);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
