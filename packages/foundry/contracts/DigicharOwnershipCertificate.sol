// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { Structs } from "./Structs.sol";
import { DigicharFactory } from "./DigicharFactory.sol";

contract DigicharOwnershipCertificate is ERC721, Structs {
    uint256 tokenId;
    DigicharFactory digicharFactory;

    error OnlyDigicharFactory();

    modifier onlyDigicharFactory() {
        if (msg.sender != digicharFactory) revert OnlyDigicharFactory();
        _;
    }

    constructor(address _digicharFactory) {
        ERC721("Digichar Ownership Certificate", "DCO");
        digicharFactory = DigicharFactory(_digicharFactory);
    }

    mapping(uint256 => string) public tokenURIs;

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal virtual {
        tokenURIs[_tokenId] = _tokenURI;
    }

    event OwnershipCertificateMinted(address _to, uint256 _tokenId, string _tokenURI);

    function mint(address _to, uint256 _tokenURI) public onlyDigicharFactory {
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        emit OwnershipCertificateMinted(_to, tokenId);
        tokenId++;
    }
}
