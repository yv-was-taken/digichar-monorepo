// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { DigicharToken } from "./DigicharToken.sol";
import { Config } from "./Config.sol";
import { AuctionVault } from "./AuctionVault.sol";

contract DigicharFactory {
    using SafeTransferLib for ERC20;

    Config config;

    constructor(address _config) {
        config = Config(_config);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //errors
    error OnlyAuctionVault();
    error OnlyProtocolAdmin();
    error InsufficientBalance();

    //events
    event TokenCreated(address indexed _token, string _name, string _symbol);
    event PairCreated(address indexed _token, address indexed _pair);
    event SwapFactorySet(address indexed _swapFactory);
    event LPInitialized(
        address indexed _token, address indexed _pair, uint256 _amountToken, uint256 _amountEth, uint256 _liquidity
    );
    event Received(address, uint256);

    //state variables

    //modifiers
    modifier onlyAuctionVault() {
        if (msg.sender != address(config.auctionVault())) revert OnlyAuctionVault();
        _;
    }

    modifier onlyProtocolAdmin() {
        if (msg.sender != config.protocolAdmin()) revert OnlyProtocolAdmin();
        _;
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
        uint256 _ownershipCertificateTokenId = config.ownershipCertificate().mint(_winningBidder, _characterTokenURI);

        //@dev create character token using LP from winning bid pool to DigicharFactory
        uint256 _auctionId = config.auctionVault().auctionId();

        uint256 winningPoolBalance = config.auctionVault().getPoolBalance(_auctionId, _winningCharacterIndex);
        if (msg.value != winningPoolBalance) revert InsufficientBalance();

        address _tokenAddress = createToken(_ownershipCertificateTokenId, _characterName, _characterSymbol);
        address _pairAddress = createTokenPair(_tokenAddress);
        createLPforTokenPair(
            _tokenAddress,
            _pairAddress,
            //@dev locking half of total supply in LP
            // this amount needs to be played with to find a good starting value
            (config.INITIAL_CHARACTER_TOKEN_SUPPLY() / 2) * 10 ** config.CHARACTER_TOKEN_DECIMALS(),
            //@dev setting tokenAmountMin and ethAmountMin to zero as not needed metric for initial LP creation
            0,
            0
        );
        //@dev now that LP is created (and burned), send rest of tokens back to auction vault for token claim.
        ERC20(_tokenAddress).safeTransfer(
            address(config.auctionVault()),
            (config.INITIAL_CHARACTER_TOKEN_SUPPLY() / 2) * 10 ** config.CHARACTER_TOKEN_DECIMALS()
        );

        return _tokenAddress;
    }

    function createToken(uint256 _ownershipCertificateTokenId, string memory _name, string memory _symbol)
        private
        returns (address)
    {
        address tokenAddress = address(
            new DigicharToken(
                address(config), _ownershipCertificateTokenId, _name, _symbol, config.CHARACTER_TOKEN_DECIMALS()
            )
        );
        return tokenAddress;
    }

    function createTokenPair(address _tokenAddress) private returns (address pair) {
        // Create swap pair
        pair = config.swapFactory().createPair(_tokenAddress, address(config.WETH()));
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
        //@dev not sure if `InsufficientBalance` is the best error message to send here
        // feel like we could improve on that.
        if (msg.value == 0 || tokenAmount == 0) revert InsufficientBalance();

        // Approve router
        DigicharToken(token).approve(address(config.swapRouter()), tokenAmount);

        // Add liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = config.swapRouter().addLiquidityETH{
            value: msg.value
        }(
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
            (bool success,) = payable(address(config.protocolAdmin())).call{ value: msg.value - amountETH }("");
            require(success, "ETH transfer failed");
        }
        emit LPInitialized(token, pair, amountToken, amountETH, liquidity);
    }
}
