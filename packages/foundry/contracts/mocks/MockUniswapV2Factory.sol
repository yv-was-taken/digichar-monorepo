// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

/**
 * @title MockUniswapV2Factory
 * @dev Mock implementation of Uniswap V2 Factory for local testing
 * This contract provides the minimal functionality needed for character token deployment testing
 */
contract MockUniswapV2Factory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    address public override feeTo;
    address public override feeToSetter;

    constructor() {
        feeToSetter = msg.sender;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS");

        // Deploy a mock pair contract (simplified - just returns a predictable address)
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(this),
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // Mock init code hash
                        )
                    )
                )
            )
        );

        // Deploy a minimal mock pair contract
        MockUniswapV2Pair mockPair = new MockUniswapV2Pair{ salt: keccak256(abi.encodePacked(token0, token1)) }();
        pair = address(mockPair);

        // Initialize the pair
        mockPair.initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}

/**
 * @title MockUniswapV2Pair
 * @dev Minimal mock implementation of a Uniswap V2 pair for testing
 */
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() { }

    function initialize(address _token0, address _token1) external {
        require(token0 == address(0) && token1 == address(0), "UniswapV2: ALREADY_INITIALIZED");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function mint(address to) external returns (uint256 liquidity) {
        // Simplified liquidity calculation for testing
        // In reality, this would involve complex math based on reserves
        liquidity = 1000 * 10 ** 18; // Mock liquidity amount

        if (to != address(0)) {
            totalSupply += liquidity;
            balanceOf[to] += liquidity;
            emit Transfer(address(0), to, liquidity);
        }

        // Update reserves (simplified)
        reserve0 = uint112(token0.balance);
        reserve1 = uint112(token1.balance);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);

        emit Mint(msg.sender, reserve0, reserve1);
        emit Sync(reserve0, reserve1);

        return liquidity;
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf[address(this)];

        // Simplified burning logic
        amount0 = (liquidity * reserve0) / totalSupply;
        amount1 = (liquidity * reserve1) / totalSupply;

        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        totalSupply -= liquidity;
        balanceOf[address(this)] -= liquidity;
        emit Transfer(address(this), address(0), liquidity);

        // Transfer tokens back (simplified)
        reserve0 -= uint112(amount0);
        reserve1 -= uint112(amount1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);

        emit Burn(msg.sender, amount0, amount1, to);
        emit Sync(reserve0, reserve1);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "UniswapV2: INSUFFICIENT_BALANCE");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function sync() external {
        reserve0 = uint112(token0.balance);
        reserve1 = uint112(token1.balance);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        emit Sync(reserve0, reserve1);
    }
}
