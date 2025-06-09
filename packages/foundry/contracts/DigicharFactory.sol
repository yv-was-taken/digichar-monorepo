// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { DigicharToken } from "./DigicharToken.sol";
import { AuctionVault } from "./AuctionVault.sol";
import { DigicharOwnershipCertificate } from "./DigicharOwnershipCertificate.sol";
import { Structs } from "./Structs.sol";

contract DigicharFactory is Structs {
    error OnlyAuctionVault();

    modifier onlyAuctionVault() {
        if (msg.sender != auctionVault) revert OnlyAuctionVault();
        _;
    }

    error OnlyOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    address public owner;
    AuctionVault public auctionVault;
    address targetDex; //@dev, need to surf around hyperevm and find which dex is best...

    constructor(address _auctionVault) {
        auctionVault = AuctionVault(_auctionVault);
        owner = msg.sender;
    }

    event TargetDexUpdated(address _newTargetDex);

    function updateTargetDex(address _newTargetDex) public onlyOwner {
        targetDex = _newTargetDex;
        emit TargetDexUpdated(_newTargetDex);
    }

    DigicharOwnershipCertificate digicharOwnershipCertificate;

    event DigicharOwnershipCertificateSet(address _digicharOwnershipCertificate);

    function setDigicharOwnershipCertificate(address _digicharOwnershipCertificate) external onlyOwner {
        digicharOwnershipCertificate = DigicharOwnershipCertificate(_digicharOwnershipCertificate);
        emit DigicharOwnershipCertificateSet(_digicharOwnershipCertificate);
    }

    function createCharacter(address _winningBidder, uint256 _winningCharacterIndex, string _characterTokenURI)
        public
        OnlyAuctionVault
    {
        //@dev mint character nft and send them ownership certificate
        digicharOwnershipCertificate.mint(_winningBidder, _characterTokenURI);

        //@dev create character token using LP from winning bid pool to DigicharFactory
        uint256 characterAuctionId = auctionVault.auctionId();
        uint256 winningPoolBalance =
            auctionVault.auctions[characterAuctionId].characters[_winningCharacterIndex].poolBalance;
        //@TODO create token pair, create LP using `winningPoolBalance`, lock LP by sending LP to zero address
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
