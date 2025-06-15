// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { DigicharFactory } from "./DigicharFactory.sol";

contract DigicharOwnershipCertificate is ERC721 {
    //@dev why does _digicharFactory need to be payable? it shouldn't be...
    // outside the scope of current ticket though..  @TODO :)

    //@TODO move _digicharFactory to config, replace constructor arg with `address _config`
    constructor(address payable _digicharFactory) ERC721("Digichar Ownership Certificate", "DCO") {
        digicharFactory = DigicharFactory(_digicharFactory);
    }
    //errors

    error OnlyDigicharFactory();

    //events
    event OwnershipCertificateMinted(address _to, uint256 _tokenId, string _tokenURI);

    //modifiers
    modifier onlyDigicharFactory() {
        if (msg.sender != address(digicharFactory)) revert OnlyDigicharFactory();
        _;
    }
    //state variables

    uint256 public tokenId;
    DigicharFactory public digicharFactory;
    //mappings
    mapping(uint256 => string) public tokenURIs;

    //set state variable functions
    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) private {
        tokenURIs[_tokenId] = _tokenURI;
    }

    //getter functions
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return tokenURIs[id];
    }

    //contract core
    function mint(address _to, string memory _tokenURI) public onlyDigicharFactory returns (uint256) {
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        emit OwnershipCertificateMinted(_to, tokenId, _tokenURI);
        tokenId++;
        return tokenId - 1;
    }
}
