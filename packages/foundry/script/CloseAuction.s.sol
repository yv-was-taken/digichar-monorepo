//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { AuctionVault } from "../contracts/AuctionVault.sol";

contract CloseAuction is ScaffoldETHDeploy {
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
        
        // Get current auction info
        uint256 currentAuctionId = auctionVault.auctionId();
        console.logString(string.concat("Current auction ID: ", vm.toString(currentAuctionId)));
        
        // Check auction end time
        uint256 auctionEndTime = auctionVault.getCurrentAuctionEndTime();
        console.logString(string.concat("Auction end time: ", vm.toString(auctionEndTime)));
        console.logString(string.concat("Current time: ", vm.toString(block.timestamp)));
        
        if (block.timestamp < auctionEndTime) {
            console.logString("WARNING: Auction has not yet expired!");
            console.logString("Continuing anyway for testing purposes...");
        }
        
        // Get pool balances for each character to determine winner
        uint256 char0Pool = auctionVault.getPoolBalance(currentAuctionId, 0);
        uint256 char1Pool = auctionVault.getPoolBalance(currentAuctionId, 1);
        uint256 char2Pool = auctionVault.getPoolBalance(currentAuctionId, 2);
        
        console.logString(string.concat("Character 0 (Dragon) pool: ", vm.toString(char0Pool)));
        console.logString(string.concat("Character 1 (Phoenix) pool: ", vm.toString(char1Pool)));
        console.logString(string.concat("Character 2 (Griffin) pool: ", vm.toString(char2Pool)));
        
        // Determine winning character (highest pool balance)
        uint8 winningCharacterIndex = 0;
        uint256 highestPool = char0Pool;
        
        if (char1Pool > highestPool) {
            winningCharacterIndex = 1;
            highestPool = char1Pool;
        }
        
        if (char2Pool > highestPool) {
            winningCharacterIndex = 2;
            highestPool = char2Pool;
        }
        
        string[3] memory characterNames = ["Dragon", "Phoenix", "Griffin"];
        console.logString(string.concat("Winning character: ", characterNames[winningCharacterIndex]));
        console.logString(string.concat("Winning pool amount: ", vm.toString(highestPool)));
        
        // For simplicity, use the deployer as the top bidder (in real scenario, you'd need to determine this offchain)
        address topBidder = msg.sender;
        console.logString(string.concat("Top bidder (using deployer): ", vm.toString(topBidder)));
        
        // Close the auction
        auctionVault.closeCurrentAuction(topBidder, winningCharacterIndex);
        
        // Verify the auction was closed
        uint256 newAuctionId = auctionVault.auctionId();
        console.logString(string.concat("New auction ID after closing: ", vm.toString(newAuctionId)));
        
        vm.stopBroadcast();
        
        console.logString("Auction closed successfully!");
    }
}