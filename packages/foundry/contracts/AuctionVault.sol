pragma solidity ^0.8.19;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract AuctionVault {

  error OnlyOwner();
  error AuctionClosed();

  modifier onlyOwner() {
    if (msg.sender != owner) revert OnlyOwner();
    _; 
  }

  //asset for vault deposits
  ERC20 public immutable ASSET;
  address public owner;

  constructor(address _asset) {
    owner = msg.sender;
    ASSET = ERC20(_asset);
  }

  uint256 auctionDurationTime = 4 hours;
  
  event AuctionTimeChanged(uint _auctionDurationTime);

  function changeAuctionDurationTime(uint _auctionDurationTime) onlyOwner {
    auctionTime = _auctionDurationTime;
    emit AuctionTimeChanged(_auctionDurationTime);
  }


  struct Character {
    string name;
    string ticker;
    string tokenURI;
    string description;
    uint id;
  }

  struct BidPool {
    Character character;
    uint poolBalance;
    //@dev is it best to put top bidder here as an address or better to put it somewhere else?
    // I guess the question I'm not sure of atm is how to handle topBidder determination without setting it on every bid in the bid function logic.
    // maybe that is the only way, but it doesn't seem very efficient...
    address topBidder;
  }

  struct Auction {
    BidPool[3] characters;
    uint endTime;
    bool isComplete;
  }

  mapping(uint256 => Auction) public auctions;
  uint public auctionId = 0;

  function createAuction(Character[3] memory _characters) public onlyOwner {
    BidPool[3] memory characterBidPools;
    for (let i = 0; i < 3; i++) {
      BidPool memory characterBidPool = BidPool({
        character: _characters[i],
        poolBalance: 0,
        topBidder: address(0)
      });
      characterBidPools.push(characterBidPool);
    }

    auctions[auctionId] = Auction({
      characters: characterBidPools,
      endTime: block.timestamp + auctionDurationTime,
      isComplete: false
    })
  }

  function bid(uint _auctionId, ) public {
    

  }

  //@dev is this needed? not sure if its best to allow for bid withdraw... need to decide.
  function withdrawBid(uint auctionId, ) public {

  }

  //this function needs to do a few different things:
  // 1. determine winning character from auction by comparing bid pools
  // 2. mint ownership certificate to top bidder from winning bid pool
  // 3. mint ERC20 token for character
  // 4. create (and lock) LP for character ERC20 token using (just winning or total?) bid pool 
  // 4. update state variables relating to character token data (erc721 address, erc20 address)
  // 5. update state variables relating to bidders token claim amounts (proportionate to bid size relative to total bid pool)
  function handleAuctionCompletion() public onlyOwner {

  }

}
