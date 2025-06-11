// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract DigicharToken is ERC20 {
    using SafeTransferLib for ERC20;
    //@TODO rename `auctionVault` to `protocol`

    address public immutable auctionVault;
    DigicharOwnershipCertificate public immutable ownershipCertificate; //@TODO extract to contract config
    uint256 public immutable ownershipCertificateTokenId;

    // Tax configuration
    //@TODO extract to contract config
    uint256 public constant PROTOCOL_TAX_BPS = 100; // 1%
    uint256 public constant CREATOR_TAX_BPS = 100; // 1%
    uint256 public constant TOTAL_TAX_BPS = 200; // 2% total
    uint256 public constant BASIS_POINTS = 10_000;

    // Liquidity lock configuration (0.75% of protocol tax goes to LP)
    //@TODO extract to contract config
    uint256 public constant LP_LOCK_BPS = 75; // 0.75%
    uint256 public constant VAULT_NET_BPS = 25; // 0.25% (1% - 0.75%)

    // DEX integration
    IUniswapV2Router02 public immutable swapRouter;
    IWETH public immutable WETH;
    address public liquidityPool; // The main trading pair for this token

    // Whitelist for tax exemptions (LP contracts, etc.)
    mapping(address => bool) public taxExempt;

    // DEX contracts that should trigger tax
    mapping(address => bool) public isDEX;

    // Events
    event TaxCollected(address indexed from, address indexed to, uint256 tokenAmount, uint256 ethAmount);
    event TaxExemptionSet(address indexed account, bool exempt);
    event LiquidityLocked(uint256 tokenAmount, uint256 ethAmount);
    event LiquidityPoolSet(address _liquidityPool);

    function getOwnershipCertificateOwner() private view returns (address) {
        address ownershipCertificateOwner = ownershipCertificate.ownerOf(ownershipCertificateTokenId);
        return ownershipCertificateOwner;
    }

    modifier onlyCreatorOrVault() {
        address ownershipCertificateOwner = getOwnershipCertificateOwner();

        require(msg.sender == ownershipCertificateOwner || msg.sender == auctionVault, "Unauthorized");
        _;
    }

    function setLiquidityPool(address _liquidityPool) public onlyCreatorOrVault {
        liquidityPool = _liquidityPool;
        emit LiquidityPoolSet(_liquidityPool);
    }

    constructor(
        //@TODO rename to `protocol`
        //@TODO extract to contract config instead of passing as constructor argument
        address _auctionVault,
        //@TODO need to extract `ownershipCertificate` to contract config
        //address _ownershipCertificate,
        uint256 _ownershipCertificateTokenId,
        string memory _name,
        string memory _symbol,
        //@TODO extract to contract config instead of passing as constructor argument
        address _swapRouter
    ) ERC20(_name, _symbol, 18) {
        require(_auctionVault != address(0), "Invalid auction vault");
        //require(_tokenOwner != address(0), "Invalid token creator");
        require(_swapRouter != address(0), "Invalid router");

        auctionVault = _auctionVault;
        //@TODO need to extract `ownershipCertificate` to contract config
        //ownershipCertificate = DigicharOwnershipCertificate(_ownershipCertificate);
        ownershipCertificateTokenId = _ownershipCertificateTokenId;
        swapRouter = IUniswapV2Router02(_swapRouter);
        WETH = IWETH(IUniswapV2Router02(_swapRouter).WETH());

        // Exempt creator and vault from taxes
        //@dev owner of ownership certificate needs to be checked if tax exempt on every transfer
        //... since owner may change at any time
        //@TODO
        //taxExempt[_tokenOwner] = true;
        taxExempt[_auctionVault] = true;
        taxExempt[address(this)] = true;

        // Mint initial supply to deployer
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // Check if this is a taxable swap
        if (shouldApplyTax(from, to)) {
            return _transferWithTax(from, to, amount);
        }

        // Standard transfer without tax
        return super.transferFrom(from, to, amount);
    }

    function _transferWithTax(address from, address to, uint256 amount) internal returns (bool) {
        uint256 allowanceAmount = allowance[from][msg.sender];
        if (allowanceAmount != type(uint256).max) {
            allowance[from][msg.sender] = allowanceAmount - amount;
        }

        // Calculate tax amounts
        uint256 protocolTax = (amount * PROTOCOL_TAX_BPS) / BASIS_POINTS;
        uint256 creatorTax = (amount * CREATOR_TAX_BPS) / BASIS_POINTS;
        uint256 totalTax = protocolTax + creatorTax;
        uint256 transferAmount = amount - totalTax;

        // Execute transfers
        balanceOf[from] -= amount;
        balanceOf[to] += transferAmount;
        balanceOf[address(this)] += totalTax;

        emit Transfer(from, to, transferAmount);
        emit Transfer(from, address(this), totalTax);

        // Convert tax to ETH and distribute
        _convertAndDistributeTax(protocolTax, creatorTax, from);

        return true;
    }

    function _convertAndDistributeTax(uint256 protocolTax, uint256 creatorTax, address from) internal {
        uint256 totalTax = protocolTax + creatorTax;
        if (totalTax == 0) return;

        // Split protocol tax: 0.75% for LP lock, 0.25% for vault
        uint256 lpLockTokens = (protocolTax * LP_LOCK_BPS) / PROTOCOL_TAX_BPS;
        uint256 vaultTokens = protocolTax - lpLockTokens;

        // Convert vault portion and creator tax to ETH
        uint256 tokensToSwap = vaultTokens + creatorTax;
        uint256 ethReceived = 0;

        if (tokensToSwap > 0) {
            ethReceived = _swapTokensForETH(tokensToSwap);
        }

        if (ethReceived > 0) {
            // Calculate ETH distribution
            uint256 vaultEth = (ethReceived * vaultTokens) / tokensToSwap;
            uint256 creatorEth = ethReceived - vaultEth;

            // Distribute ETH
            if (vaultEth > 0) {
                _safeTransferETH(auctionVault, vaultEth);
                emit TaxCollected(from, auctionVault, vaultTokens, vaultEth);
            }

            if (creatorEth > 0) {
                address ownershipCertificateOwner = getOwnershipCertificateOwner();
                _safeTransferETH(ownershipCertificateOwner, creatorEth);
                emit TaxCollected(from, ownershipCertificateOwner, creatorTax, creatorEth);
            }
        }

        // Lock LP portion into liquidity pool
        if (lpLockTokens > 0) {
            _lockLiquidity(lpLockTokens);
        }
    }

    function _swapTokensForETH(uint256 tokenAmount) internal returns (uint256) {
        if (tokenAmount == 0) return 0;

        // Approve router to spend tokens
        approve(address(swapRouter), tokenAmount);

        // Set up swap path
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(WETH);

        try swapRouter.swapExactTokensForETH(
            tokenAmount,
            0, // Accept any amount of ETH
            path,
            address(this),
            block.timestamp + 300
        ) returns (uint256[] memory amounts) {
            return amounts[1]; // Return ETH amount
        } catch {
            // If swap fails, return 0 (tax tokens remain in contract)
            return 0;
        }
    }

    function _lockLiquidity(uint256 tokenAmount) internal {
        if (tokenAmount == 0 || liquidityPool == address(0)) return;

        // Split tokens: half to swap for ETH, half to pair with that ETH
        uint256 halfTokens = tokenAmount / 2;
        uint256 otherHalf = tokenAmount - halfTokens;

        // Swap half tokens for ETH
        uint256 ethForLP = _swapTokensForETH(halfTokens);

        if (ethForLP > 0) {
            // Add liquidity (LP tokens are burned by sending to dead address)
            _addLiquidityAndBurn(otherHalf, ethForLP);
            emit LiquidityLocked(tokenAmount, ethForLP);
        }
    }

    function _addLiquidityAndBurn(uint256 tokenAmount, uint256 ethAmount) internal {
        // Approve router to spend tokens
        approve(address(swapRouter), tokenAmount);

        try swapRouter.addLiquidityETH{ value: ethAmount }(
            address(this),
            tokenAmount,
            0, // Accept any amount of tokens
            0, // Accept any amount of ETH
            address(0xdead), // Send LP tokens to dead address (permanent lock)
            block.timestamp + 300
        ) {
            // Liquidity added successfully
        } catch {
            // If adding liquidity fails, tokens remain in contract
            // Could emit an event or handle differently
        }
    }

    function shouldApplyTax(address from, address to) internal view returns (bool) {
        // No tax if either party is exempt
        if (taxExempt[from] || taxExempt[to]) {
            return false;
        }
        address ownershipCertificateOwner = ownershipCertificate.ownerOf(ownershipCertificateTokenId);
        if (from == ownershipCertificateOwner || to == ownershipCertificateOwner) {
            return false;
        }

        // Apply tax if interacting with a known DEX
        return isDEX[from] || isDEX[to];
    }

    receive() external payable { }

    function _safeTransferETH(address to, uint256 amount) internal {
        if (amount == 0) return;

        SafeTransferLib.safeTransferETH(to, amount);
    }
}
