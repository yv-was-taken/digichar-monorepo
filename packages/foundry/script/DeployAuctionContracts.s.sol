//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { Config } from "../contracts/Config.sol";
import { AuctionVault } from "../contracts/AuctionVault.sol";
import { DigicharFactory } from "../contracts/DigicharFactory.sol";
import { DigicharOwnershipCertificate } from "../contracts/DigicharOwnershipCertificate.sol";

contract DeployAuctionContracts is ScaffoldETHDeploy {
    function run() external {
        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //if (deployerPrivateKey == 0) {
        //    revert InvalidPrivateKey(
        //        "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
        //    );
        //}
        //vm.startBroadcast(deployerPrivateKey);

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

        // Set the deployed contracts in Config
        config.setOwnershipCertificate(address(ownershipCertificate));
        config.setAuctionVault(address(auctionVault));
        //@TODO this should be set in config only and not fed through constructor on DigicharOwnershipCertificate deployment
        config.setDigicharFactory(payable(address(digicharFactory)));

        // Optionally create a sample auction for testing
        string[3] memory characterURIs =
            ["https://ipfs.io/ipfs/QmChar1", "https://ipfs.io/ipfs/QmChar2", "https://ipfs.io/ipfs/QmChar3"];
        string[3] memory names = ["Dragon", "Phoenix", "Griffin"];
        string[3] memory symbols = ["DRG", "PHX", "GRF"];

        auctionVault.createAuction(characterURIs, names, symbols);

        //vm.stopBroadcast();

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
