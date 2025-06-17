//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { Config } from "../contracts/Config.sol";
import { AuctionVault } from "../contracts/AuctionVault.sol";
import { DigicharFactory } from "../contracts/DigicharFactory.sol";
import { DigicharOwnershipCertificate } from "../contracts/DigicharOwnershipCertificate.sol";
import { MockWETH } from "../contracts/mocks/MockWETH.sol";
import { MockUniswapV2Factory } from "../contracts/mocks/MockUniswapV2Factory.sol";
import { MockUniswapV2Router02 } from "../contracts/mocks/MockUniswapV2Router02.sol";

contract DeployAuctionContracts is ScaffoldETHDeploy {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Config contract first
        Config config = new Config();
        console.logString(string.concat("Config deployed at: ", vm.toString(address(config))));

        // Deploy AuctionVault
        AuctionVault auctionVault = new AuctionVault(address(config));
        console.logString(string.concat("AuctionVault deployed at: ", vm.toString(address(auctionVault))));

        // Deploy DigicharFactory
        DigicharFactory digicharFactory = new DigicharFactory(address(config));
        console.logString(string.concat("DigicharFactory deployed at: ", vm.toString(address(digicharFactory))));

        // Deploy DigicharOwnershipCertificate
        DigicharOwnershipCertificate ownershipCertificate =
            new DigicharOwnershipCertificate(payable(address(digicharFactory)));
        console.logString(
            string.concat("DigicharOwnershipCertificate deployed at: ", vm.toString(address(ownershipCertificate)))
        );

        // Deploy mock DEX contracts for local development only
        // @dev In production, use actual mainnet addresses:
        //      WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        //      Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        //      Router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        console.logString("Setting up DEX contracts for local development...");

        // Deploy Mock WETH for local testing
        MockWETH mockWETH = new MockWETH();
        console.logString(string.concat("MockWETH deployed at: ", vm.toString(address(mockWETH))));

        // Deploy Mock Uniswap V2 Factory
        MockUniswapV2Factory mockFactory = new MockUniswapV2Factory();
        console.logString(string.concat("MockUniswapV2Factory deployed at: ", vm.toString(address(mockFactory))));

        // Deploy Mock Uniswap V2 Router
        MockUniswapV2Router02 mockRouter = new MockUniswapV2Router02(address(mockFactory), address(mockWETH));
        console.logString(string.concat("MockUniswapV2Router02 deployed at: ", vm.toString(address(mockRouter))));

        // Set the deployed contracts in Config
        config.setOwnershipCertificate(address(ownershipCertificate));
        config.setAuctionVault(address(auctionVault));
        //@TODO this should be set in config only and not fed through constructor on DigicharOwnershipCertificate deployment
        config.setDigicharFactory(payable(address(digicharFactory)));

        // Set mock DEX addresses in Config
        config.setWETH(address(mockWETH));
        config.setSwapFactory(address(mockFactory));
        config.setSwapRouter(address(mockRouter));
        console.logString("Mock DEX addresses configured in Config contract");

        // Optionally create a sample auction for testing
        //@dev this is great for development, but come production we want to do this externally,
        // so make sure to remove this
        string[3] memory characterURIs = [
            "QmRRPWG96cmgTn2qSzjwr2qvfNEuhunv6FNeMFGa9bx6mQ",
            "QmPbxeGcXhYQQNgsC6a36dDyYUcHgMLnGKnF8pVFmGsvqi",
            "QmcJYkCKK7QPmYWjp4FD2e3Lv5WCGFuHNUByvGKBaytif4"
        ];
        string[3] memory names = ["Dragon", "Phoenix", "Griffin"];
        string[3] memory symbols = ["DRG", "PHX", "GRF"];

        auctionVault.createAuction(characterURIs, names, symbols);

        vm.stopBroadcast();

        console.logString(
            string.concat(
                "Auction contracts deployed on ",
                vm.toString(block.chainid),
                " with deployer at: ",
                vm.toString(msg.sender)
            )
        );
    }
}
