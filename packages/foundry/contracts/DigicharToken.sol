// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { Config } from "./Config.sol";
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";

contract DigicharToken is ERC20, Config {
    using SafeTransferLib for ERC20;

    uint256 public immutable ownershipCertificateTokenId;

    // DEX integration
    //IUniswapV2Router02 public immutable swapRouter;

    // Whitelist for tax exemptions (LP contracts, etc.)
    mapping(address => bool) public taxExempt;

    // DEX contracts that should trigger tax
    mapping(address => bool) public isDEX;

    // Events
    event TaxCollected(address indexed from, address indexed to, uint256 tokenAmount, uint256 ethAmount);
    event TaxExemptionSet(address indexed account, bool exempt);
    event LiquidityLocked(uint256 tokenAmount, uint256 ethAmount);

    function getOwnershipCertificateOwner() private view returns (address) {
        address ownershipCertificateOwner = ownershipCertificate.ownerOf(ownershipCertificateTokenId);
        return ownershipCertificateOwner;
    }

    modifier onlyCharacterOwnerOrProtocolAdmin() {
        address ownershipCertificateOwner = getOwnershipCertificateOwner();

        require(msg.sender == ownershipCertificateOwner || msg.sender == protocolAdmin, "Unauthorized");
        _;
    }

    constructor(uint256 _ownershipCertificateTokenId, string memory _name, string memory _symbol)
        ERC20(_name, _symbol, 18)
        Config(protocolAdmin)
    {
        ownershipCertificateTokenId = _ownershipCertificateTokenId;

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
        uint256 ownerTax = (amount * PROTOCOL_ADMIN_TAX_BPS) / BASIS_POINTS;
        uint256 creatorTax = (amount * CHARACTER_OWNER_TAX_BPS) / BASIS_POINTS;
        uint256 totalTax = ownerTax + creatorTax;
        uint256 transferAmount = amount - totalTax;

        // Execute transfers
        balanceOf[from] -= amount;
        balanceOf[to] += transferAmount;
        balanceOf[address(this)] += totalTax;

        emit Transfer(from, to, transferAmount);
        emit Transfer(from, address(this), totalTax);

        // Convert tax to ETH and distribute
        _convertAndDistributeTax(ownerTax, creatorTax, from);

        return true;
    }

    function _convertAndDistributeTax(uint256 ownerTax, uint256 creatorTax, address from) internal {
        uint256 totalTax = ownerTax + creatorTax;
        if (totalTax == 0) return;

        // Split owner tax: 0.75% for LP lock, 0.25% for vault
        uint256 lpLockTokens = (ownerTax * LP_LOCK_BPS) / PROTOCOL_ADMIN_TAX_BPS;
        uint256 vaultTokens = ownerTax - lpLockTokens;

        // Convert vault portion and creator tax to WETH
        uint256 tokensToSwap = vaultTokens + creatorTax;
        uint256 wethReceived = 0;

        if (tokensToSwap > 0) {
            wethReceived = _swapTokensForWETH(tokensToSwap);
        }

        if (wethReceived > 0) {
            // Calculate WETH distribution
            uint256 protocolAdminWethAllocation = (wethReceived * vaultTokens) / tokensToSwap;
            uint256 characterOwnerWethAllocation = wethReceived - protocolAdminWethAllocation;

            // Distribute WETH
            if (protocolAdminWethAllocation > 0) {
                WETH.safeTransfer(protocolAdmin, protocolAdminWethAllocation);
                emit TaxCollected(from, protocolAdmin, vaultTokens, protocolAdminWethAllocation);
            }

            if (characterOwnerWethAllocation > 0) {
                address ownershipCertificateOwner = getOwnershipCertificateOwner();
                WETH.safeTransfer(ownershipCertificateOwner, characterOwnerWethAllocation);
                emit TaxCollected(from, ownershipCertificateOwner, creatorTax, characterOwnerWethAllocation);
            }
        }

        // Lock LP portion into liquidity pool
        if (lpLockTokens > 0) {
            _lockLiquidity(lpLockTokens);
        }
    }

    function _swapTokensForWETH(uint256 tokenAmount) internal returns (uint256) {
        if (tokenAmount == 0) return 0;

        // Approve router to spend tokens
        approve(address(swapRouter), tokenAmount);

        // Set up swap path
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(WETH);

        try swapRouter.swapExactTokensForTokens(
            tokenAmount,
            0, // Accept any amount of WETH
            path,
            address(this),
            block.timestamp + 300
        ) returns (uint256[] memory amounts) {
            return amounts[1]; // Return WETH amount
        } catch {
            // If swap fails, return 0 (tax tokens remain in contract)
            return 0;
        }
    }

    function _lockLiquidity(uint256 tokenAmount) internal {
        if (tokenAmount == 0) return;

        // Split tokens: half to swap for WETH, half to pair with that WETH
        uint256 halfTokens = tokenAmount / 2;
        uint256 otherHalf = tokenAmount - halfTokens;

        // Swap half tokens for WETH
        uint256 wethForLP = _swapTokensForWETH(halfTokens);

        if (wethForLP > 0) {
            // Add liquidity (LP tokens are burned by sending to dead address)
            _addLiquidityAndBurn(otherHalf, wethForLP);
            emit LiquidityLocked(tokenAmount, wethForLP);
        }
    }

    function _addLiquidityAndBurn(uint256 tokenAmount, uint256 wethAmount) internal {
        // Approve router to spend tokens
        approve(address(swapRouter), tokenAmount);
        WETH.approve(address(swapRouter), wethAmount);

        try swapRouter.addLiquidity(
            address(this),
            address(WETH),
            tokenAmount,
            wethAmount,
            0, // Accept any amount of tokens
            0, // Accept any amount of WETH
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
}
