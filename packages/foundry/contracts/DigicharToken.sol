pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract DigicharToken is ERC20 {
    constructor(address _auctionVault, string memory _name, string memory _symbol) ERC20(_name, _symbol, 18) {
        //@dev minting to digicharFactory for LP creation (to then send to auction vault for token claim)
        _mint(msg.sender, 1_000_000 * 10 ** uint256(18));
    }
    //@TODO tax logic for protocol/owner revenue?
    //...not sure if better here or inside a V4 hook... TBD on further inquiry
}
