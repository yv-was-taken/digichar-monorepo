// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}

/**
 * @title MockUniswapV2Router02
 * @dev Simplified mock implementation of Uniswap V2 Router for local testing
 * Only implements the functions actually used by DigicharFactory
 */
contract MockUniswapV2Router02 {
    address public immutable factoryAddress;
    address public immutable WETHAddress;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address factory_, address WETH_) {
        factoryAddress = factory_;
        WETHAddress = WETH_;
    }

    function factory() external view returns (address) {
        return factoryAddress;
    }

    function WETH() external view returns (address) {
        return WETHAddress;
    }

    receive() external payable {
        assert(msg.sender == WETHAddress);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        require(msg.value > 0, "UniswapV2Router: INSUFFICIENT_ETH");
        require(amountTokenDesired > 0, "UniswapV2Router: INSUFFICIENT_TOKEN");

        amountToken = amountTokenDesired;
        amountETH = msg.value;

        require(amountToken >= amountTokenMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountETH >= amountETHMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");

        // Get or create pair
        address pair = IUniswapV2Factory(factoryAddress).getPair(token, WETHAddress);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(factoryAddress).createPair(token, WETHAddress);
        }

        // Convert ETH to WETH and transfer to pair
        IWETH(WETHAddress).deposit{ value: amountETH }();
        IWETH(WETHAddress).transfer(pair, amountETH);

        // Transfer tokens to pair
        IERC20(token).transferFrom(msg.sender, pair, amountToken);

        // Mock liquidity calculation
        liquidity = sqrt(amountToken * amountETH);

        // Handle liquidity tokens based on 'to' address
        if (to == address(0)) {
            // LP tokens are burned (sent to zero address to lock liquidity)
            // This is what the DigicharFactory does - no need to track LP tokens
        } else {
            // In a real implementation, this would mint LP tokens to the 'to' address
            // For our mock, we just return a liquidity value
        }
    }

    // Helper function for liquidity calculation
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
