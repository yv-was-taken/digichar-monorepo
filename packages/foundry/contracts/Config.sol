// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";

contract Config {
    //@TODO get rid of constructor arg and set protocol admin as msg.sender
    constructor(address _protocolAdmin) {
        _protocolAdmin = protocolAdmin;
    }

    error OnlyProtocolAdmin();

    modifier onlyProtocolAdmin() virtual {
        if (msg.sender != protocolAdmin) revert OnlyProtocolAdmin();
        _;
    }

    address protocolAdmin;

    //immutable constants
    uint256 public constant INITIAL_CHARACTER_TOKEN_SUPPLY = 1_000_000;
    uint256 public constant CHARACTER_TOKEN_DECIMALS = 18;
    DigicharOwnershipCertificate public ownershipCertificate;
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
    IUniswapV2Router02 swapRouter;
    ERC20 public WETH;

    event WethSet(address _weth);

    function setWETH(address _weth) external onlyProtocolAdmin {
        WETH = ERC20(_weth);
        emit WethSet(_weth);
    }

    event SwapRouterSet(address indexed _protocolAdmin, address indexed_swapRouter);

    function setSwapRouter(address _swapRouter) external onlyProtocolAdmin {
        require(_swapRouter != address(0), "Invalid router");
        swapRouter = IUniswapV2Router02(_swapRouter);
        emit SwapRouterSet(protocolAdmin, _swapRouter);
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

    event ProtocolAdminAdminUpdated(address _protocolAdmin);

    function updateProtocolAdminAdmin(address _protocolAdmin) external onlyProtocolAdmin {
        protocolAdmin = _protocolAdmin;
        emit ProtocolAdminAdminUpdated(_protocolAdmin);
    }
}
