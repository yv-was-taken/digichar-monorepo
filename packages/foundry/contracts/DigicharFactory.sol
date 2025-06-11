// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { DigicharToken } from "./DigicharToken.sol";
import { Config } from "./Config.sol";
import { AuctionVault } from "./AuctionVault.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";

contract DigicharFactory is Config {
    using SafeTransferLib for ERC20;

    constructor(address _auctionVault) Config(protocolAdmin) {
        auctionVault = AuctionVault(_auctionVault);
        owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //errors
    error OnlyAuctionVault();
    error OnlyOwner();
    error InsufficientBalance();

    //events
    event TargetDexUpdated(address _newTargetDex);
    event DigicharOwnershipCertificateSet(address _digicharOwnershipCertificate);
    event TokenCreated(address indexed _token, string _name, string _symbol);
    event PairCreated(address indexed _token, address indexed _pair);
    event SwapFactorySet(address indexed _swapFactory);
    event LPInitialized(
        address indexed _token, address indexed _pair, uint256 _amountToken, uint256 _amountEth, uint256 _liquidity
    );
    event Received(address, uint256);

    //state variables
    address public owner;
    AuctionVault public auctionVault;
    address targetDex; //@dev, need to surf around hyperevm and find which dex is best...
    IUniswapV2Factory swapFactory;
    DigicharOwnershipCertificate digicharOwnershipCertificate;

    //modifiers
    modifier onlyAuctionVault() {
        if (msg.sender != address(auctionVault)) revert OnlyAuctionVault();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    function setSwapFactory(address _swapFactory) external onlyOwner {
        swapFactory = IUniswapV2Factory(_swapFactory);
        emit SwapFactorySet(_swapFactory);
    }

    function updateTargetDex(address _newTargetDex) public onlyOwner {
        targetDex = _newTargetDex;
        emit TargetDexUpdated(_newTargetDex);
    }

    function setDigicharOwnershipCertificate(address _digicharOwnershipCertificate) external onlyOwner {
        digicharOwnershipCertificate = DigicharOwnershipCertificate(_digicharOwnershipCertificate);
        emit DigicharOwnershipCertificateSet(_digicharOwnershipCertificate);
    }

    //contract core

    function createCharacter(
        address _winningBidder,
        uint256 _winningCharacterIndex,
        string memory _characterTokenURI,
        string memory _characterName,
        string memory _characterSymbol
    ) external payable onlyAuctionVault returns (address) {
        //@dev mint character nft and send them ownership certificate
        uint256 _ownershipCertificateTokenId = digicharOwnershipCertificate.mint(_winningBidder, _characterTokenURI);

        //@dev create character token using LP from winning bid pool to DigicharFactory
        uint256 _auctionId = auctionVault.auctionId();

        uint256 winningPoolBalance = auctionVault.getPoolBalance(_auctionId, _winningCharacterIndex);
        if (msg.value != winningPoolBalance) revert InsufficientBalance();

        address _tokenAddress = createToken(_ownershipCertificateTokenId, _characterName, _characterSymbol);
        address _pairAddress = createTokenPair(_tokenAddress);
        createLPforTokenPair(
            _tokenAddress,
            _pairAddress,
            //@dev locking half of total supply in LP
            // this amount needs to be played with to find a good starting value
            (INITIAL_CHARACTER_TOKEN_SUPPLY / 2) * 10 ** CHARACTER_TOKEN_DECIMALS,
            //@dev setting tokenAmountMin and ethAmountMin to zero as not needed metric for initial LP creation
            0,
            0
        );
        //@dev now that LP is created (and burned), send rest of tokens back to auction vault for token claim.
        ERC20(_tokenAddress).safeTransfer(
            address(auctionVault), (INITIAL_CHARACTER_TOKEN_SUPPLY / 2) * 10 ** CHARACTER_TOKEN_DECIMALS
        );

        return _tokenAddress;
    }

    function createToken(uint256 _ownershipCertificateTokenId, string memory _name, string memory _symbol)
        private
        returns (address)
    {
        address tokenAddress = address(new DigicharToken(_ownershipCertificateTokenId, _name, _symbol));
        return tokenAddress;
    }

    function createTokenPair(address _tokenAddress) private returns (address pair) {
        // Create swap pair
        pair = swapFactory.createPair(_tokenAddress, address(WETH));
        emit PairCreated(_tokenAddress, pair);

        return (pair);
    }

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
            address(0), // Send LP tokens to zero address to lock liquidity
            block.timestamp + 1 //deadline
        );

        //// Refund excess tokens and ETH
        //if (tokenAmount > amountToken) {
        //    SimpleToken(token).transfer(msg.sender, tokenAmount - amountToken);
        //}
        if (msg.value > amountETH) {
            //@dev sending leftover ETH from LP creation back to AuctionVault
            (bool success,) = payable(address(protocolAdmin)).call{ value: msg.value - amountETH }("");
            require(success, "ETH transfer failed");
        }
        emit LPInitialized(token, pair, amountToken, amountETH, liquidity);
    }
}
