//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { AuctionVault } from "../contracts/AuctionVault.sol";

contract CreateAuction is ScaffoldETHDeploy {
    function run() external {
        vm.startBroadcast();

        // Read the latest deployment data to get AuctionVault address
        string memory deploymentFile = "./broadcast/Deploy.s.sol/31337/run-latest.json";
        string memory jsonData = vm.readFile(deploymentFile);

        // Parse the JSON to find AuctionVault contract address
        address auctionVaultAddress = vm.parseJsonAddress(jsonData, ".transactions[1].contractAddress");

        console.logString(string.concat("Using AuctionVault at: ", vm.toString(auctionVaultAddress)));

        // Connect to the deployed AuctionVault contract
        AuctionVault auctionVault = AuctionVault(auctionVaultAddress);

        // Character data (same as used in Deploy.s.sol)
        string[3] memory characterURIs = [
            "QmRRPWG96cmgTn2qSzjwr2qvfNEuhunv6FNeMFGa9bx6mQ",
            "QmPbxeGcXhYQQNgsC6a36dDyYUcHgMLnGKnF8pVFmGsvqi",
            "QmcJYkCKK7QPmYWjp4FD2e3Lv5WCGFuHNUByvGKBaytif4"
        ];
        string[3] memory names = ["Dragon", "Phoenix", "Griffin"];
        string[3] memory symbols = ["DRG", "PHX", "GRF"];

        // Create new auction
        auctionVault.createAuction(characterURIs, names, symbols);

        // Get the new auction ID
        uint256 newAuctionId = auctionVault.auctionId();
        console.logString(string.concat("Created auction #", vm.toString(newAuctionId)));

        vm.stopBroadcast();

        console.logString("Auction creation completed successfully!");
    }
}
