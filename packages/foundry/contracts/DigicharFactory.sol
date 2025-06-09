pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { DigicharToken } from "./DigicharToken.sol";
import { AuctionVault } from "./AuctionVault.sol";
import { DigiSwapHook } from "./DigiSwapHook.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { Structs } from "./Structs.sol";

//import {IPoolInitializer_v4} from "v4-periphery/src/interfaces/IPoolInitializer_v4.sol";

//struct PoolKey {
//  Currency currency0;
//  Currency currency1;
//  uint24 fee;
//  int24 tickSpacing;
//  IHooks hooks;
//}

contract DigicharFactory is Structs {
    int24 poolTickSpacing = 100;
    uint24 lpFee = 5000;

    event PoolTickSpacingUpdated(int24 _newPoolTickSpacing);

    function updatePoolTickSpacing(int24 _newPoolTickSpacing) external onlyOwner {
        poolTickSpacing = _newPoolTickSpacing;
        emit PoolTickSpacingUpdated(_newPoolTickSpacing);
    }

    event LpFeeUpdated(uint24 _newPoolFee);

    function updateLpFee(uint24 _newLpFee) external onlyOwner {
        lpFee = _newLpFee;
        emit PoolTickSpacingUpdated(_newLpFee);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    address public owner;
    DigicharToken public digicharToken;
    DigicharOwnershipCertificate public digicharOwnershipCertificate;
    DigiswapHook public digiswapHook;
    AuctionVault public auctionVault;
    address _targetDex; //@dev, this should be of `Pool` type contract, need to surf around hyperevm and find which dex is best...

    constructor(
        address _digicharOwnershipCertificate,
        address _digicharToken,
        address _auctionVault,
        address _targetDex,
        address _digiswapHook
    ) {
        digicharToken = DigicharToken(_digicharToken);
        digicharOwnershipCertificate = DigicharOwnershipCertificate(_digicharOwnershipCertificate);
        auctionVault = AuctionVault(_auctionVault);
        targetDex = _targetDex;
        digiswapHook = DigiswapHook(_digiswapHook);
        owner = msg.sender;
    }

    event TargetDexUpdated(address _newTargetDex);

    function updateTargetDex(address _newTargetDex) onlyOwner {
        targetDex = _newTargetDex;
        emit TargetDexUpdated(_newTargetDex);
    }

    event DigiSwapHookUpdated(address _newDigiSwapHook);

    function updateTargetDex(address _newDigiSwapHook) onlyOwner {
        digiswapHook = _newDigiSwapHook;
        emit DigiSwapHookUpdated(_newDigiSwapHook);
    }

    error OnlyAuctionVault();

    modifier onlyAuctionVault() {
        if (msg.sender != auctionVault) revert OnlyAuctionVault();
        _;
    }

    function createCharacter() public OnlyAuctionVault { }

    function mintOwnershipTicket() private { }

    function mintCharacterTokens() private { }

    //@dev:
    //the startingPrice is expressed as sqrtPriceX96: floor(sqrt(token1 / token0) * 2^96)
    //  79228162514264337593543950336 is the starting price for a 1:1 pool
    //see: https://docs.uniswap.org/contracts/v4/quickstart/create-pool#3-encode-the-initializepool-parameters

    //@dev need to figure out what I want starting price to be,
    // this variable should be moved over to constants and then mul/div'd to set good unit bias for starting price, but leaving it for now @TODO
    uint256 tokenStartingPrice = 79228162514264337593543950336;

    function createPairAndAddLiquidity(address _characterToken) private {
        //@dev note: this is using uniswapV4 hooks. is uniswap v4 even deployed on hyperevm?
        // if not, does uniswap v4 contract licensing even allow for redeployment of these contracts? I don't think so given uniswap v3's strict contract limitations.
        // so worth keeping in mind before going down this rabbit hole. either way, have to figure out where in the stream to subtract and distribute fees.
        //
        //bytes[] memory params = new bytes[](2);
        //PoolKey memory pool = PoolKey({
        //  currency0: _characterToken,
        //  currency1: address(0), //@dev should we do WHYPE instead?
        //  fee: lpFee,
        //  tickSpacing: poolTickSpacing,
        //  //@dev need to implement DigiSwapHook contract to handle fee distribution I think, but not yet implemented @TODO
        //  hooks: digiswapHook
        //});
        //params[0] = abi.encodeWithSelector(
        //  IPoolInitializer_v4.initializePool.selector,
        //  pool,
        //  tokenStartingPrice
        //);
        //bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        //bytes[] memory mintParams = new bytes[](2);
        //mintParams[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        //mintParams[1] = abi.encode(pool.currency0, pool.currency1);
        //uint256 deadline = block.timestamp + 60;
        //params[1] = abi.encodeWithSelector(
        //  posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        //);

        //// approve permit2 as a spender
        //IERC20(token).approve(address(permit2), type(uint256).max);

        //// approve `PositionManager` as a spender
        //IAllowanceTransfer(address(permit2)).approve(token, address(positionManager), type(uint160).max, type(uint48).max);

        //PositionManager(posm).multicall(params);
    }
}
