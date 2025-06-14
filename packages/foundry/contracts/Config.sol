// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { DigicharFactory } from "./DigicharFactory.sol";
import { AuctionVault } from "./AuctionVault.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

contract Config {
    constructor() {
        protocolAdmin = msg.sender;
    }

    error OnlyProtocolAdmin();

    modifier onlyProtocolAdmin() {
        if (msg.sender != protocolAdmin) revert OnlyProtocolAdmin();
        _;
    }

    address public protocolAdmin;

    //protocol contracts
    AuctionVault public auctionVault;
    DigicharFactory public digicharFactory;
    DigicharOwnershipCertificate public ownershipCertificate;

    //immutable constants
    uint256 public constant INITIAL_CHARACTER_TOKEN_SUPPLY = 1_000_000;
    uint8 public constant CHARACTER_TOKEN_DECIMALS = 18;
    uint256 public constant BASIS_POINTS = 10_000;

    // Tax configuration
    uint256 public PROTOCOL_ADMIN_TAX_BPS = 100; // 1%
    uint256 public CHARACTER_OWNER_TAX_BPS = 100; // 1%
    uint256 public LP_LOCK_BPS = 75; // 0.75%
    uint256 public AUCTION_DURATION_TIME = 4 hours;

    event AuctionDurationSet(address indexed _protocolAdmin, uint256 indexed _auctionDuration);

    function setAuctionDuration(uint256 _auctionDuration) external onlyProtocolAdmin {
        AUCTION_DURATION_TIME = _auctionDuration;
        emit AuctionDurationSet(protocolAdmin, _auctionDuration);
    }

    //dex addresses
    IUniswapV2Router02 public swapRouter;
    IUniswapV2Factory public swapFactory;
    ERC20 public WETH;

    event WethSet(address _weth);

    function setWETH(address _weth) external onlyProtocolAdmin {
        WETH = ERC20(_weth);
        emit WethSet(_weth);
    }

    event SwapRouterSet(address indexed _protocolAdmin, address indexed_swapRouter);

    function setSwapRouter(address _swapRouter) external onlyProtocolAdmin {
        swapRouter = IUniswapV2Router02(_swapRouter);
        emit SwapRouterSet(protocolAdmin, _swapRouter);
    }

    event SwapFactorySet(address indexed _protocolAdmin, address indexed_swapRouter);

    function setSwapFactory(address _swapFactory) external onlyProtocolAdmin {
        swapFactory = IUniswapV2Factory(_swapFactory);
        emit SwapFactorySet(protocolAdmin, _swapFactory);
    }

    event ProtocolAdminTaxBpsSet(address indexed _protocolAdmin, uint256 _PROTOCOL_ADMIN_TAX_BPS);

    function setProtocolAdminTaxBps(uint256 _PROTOCOL_ADMIN_TAX_BPS) external onlyProtocolAdmin {
        PROTOCOL_ADMIN_TAX_BPS = _PROTOCOL_ADMIN_TAX_BPS;
        emit ProtocolAdminTaxBpsSet(protocolAdmin, _PROTOCOL_ADMIN_TAX_BPS);
    }

    event CharacterOwnerTaxBpsSet(address indexed _protocolAdmin, uint256 _CHARACTER_OWNER_TAX_BPS);

    function setCharacterOwnerTaxBps(uint256 _CHARACTER_OWNER_TAX_BPS) external onlyProtocolAdmin {
        CHARACTER_OWNER_TAX_BPS = _CHARACTER_OWNER_TAX_BPS;
        emit CharacterOwnerTaxBpsSet(protocolAdmin, _CHARACTER_OWNER_TAX_BPS);
    }

    event LpLockBpsSet(address indexed _protocolAdmin, uint256 _LP_LOCK_BPS);

    function setLpLockBps(uint256 _LP_LOCK_BPS) external onlyProtocolAdmin {
        LP_LOCK_BPS = _LP_LOCK_BPS;
        emit LpLockBpsSet(protocolAdmin, _LP_LOCK_BPS);
    }

    event OwnershipCertificateSet(address indexed _protocolAdmin, address _ownershipCertificate);

    function setOwnershipCertificate(address _ownershipCertificate) external onlyProtocolAdmin {
        ownershipCertificate = DigicharOwnershipCertificate(_ownershipCertificate);
        emit OwnershipCertificateSet(protocolAdmin, _ownershipCertificate);
    }

    event AuctionVaultSet(address indexed _protocolAdmin, address _auctionVault);

    function setAuctionVault(address _auctionVault) external onlyProtocolAdmin {
        auctionVault = AuctionVault(_auctionVault);
        emit AuctionVaultSet(protocolAdmin, _auctionVault);
    }

    event DigicharFactorySet(address indexed _protocolAdmin, address _digicharFactory);

    function setDigicharFactory(address payable _digicharFactory) external onlyProtocolAdmin {
        digicharFactory = DigicharFactory(_digicharFactory);
        emit DigicharFactorySet(protocolAdmin, _digicharFactory);
    }

    event ProtocolAdminUpdated(address _protocolAdmin);

    function updateProtocolAdmin(address _protocolAdmin) external onlyProtocolAdmin {
        protocolAdmin = _protocolAdmin;
        emit ProtocolAdminUpdated(_protocolAdmin);
    }
}
