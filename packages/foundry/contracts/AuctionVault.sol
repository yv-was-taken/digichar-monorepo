// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/src/tokens/ERC20.sol";

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

    event AuctionTimeChanged(uint256 _auctionDurationTime);

    function changeAuctionDurationTime(uint256 _auctionDurationTime) onlyOwner {
        auctionTime = _auctionDurationTime;
        emit AuctionTimeChanged(_auctionDurationTime);
    }

    struct Character {
        string name;
        string ticker;
        string tokenURI;
        string description;
        uint256 id;
    }

    struct Bidder {
        address wallet;
        uint256 bidAmount;
    }

    struct BidPool {
        Character character;
        uint256 poolBalance;
        //@dev is it best to put top bidder here as an address or better to put it somewhere else?
        // I guess the question I'm not sure of atm is how to handle topBidder determination without setting it on every bid in the bid function logic.
        // maybe that is the only way, but it doesn't seem very efficient...
        Bidder topBidder;
    }

    struct Auction {
        BidPool[3] characters;
        uint256 endTime;
        bool isComplete;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionId = 0;
    //@dev initializing to one for valid character id checking in bid() function, allowing for zero would create a vulnerability allowing users to bid on characters from previous auctions
    uint256 public characterId = 1;

    function createAuction(string[3] _characterName, string[3] _characterTicker, string[3] _characterTokenURI)
        public
        onlyOwner
    {
        BidPool[3] memory characterBidPools;
        for (uint8 i = 0; i < 3; i++) {
            Character character = Character({
                name: _characterName[i],
                ticker: _characterTicker[i],
                tokenURI: _characterTokenURI[i],
                id: characterId
            });
            characterId++;

            BidPool characterBidPool = BidPool({
                character: character,
                poolBalance: 0,
                topBidder: Bidder({ wallet: address(0), bidAmount: 0 })
            });
            characterBidPools.push(characterBidPool);
        }

        auctions[auctionId] = Auction({
            characters: characterBidPools,
            endTime: block.timestamp + auctionDurationTime,
            isComplete: false
        });
        auctionId++;
    }

    bool private _locked;

    modifier noReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    error AmountZero();
    error AuctionExpired();

    event NewTopBidder(uint256 indexed _auctionId, address indexed wallet, uint256 _bidAmount);
    event BidPlaced(uint256 _auctionId, uint256 _amount, uint256 _characterId);

    function bid(uint256 _auctionId, uint256 _amount, uint256 _characterId) public noReentrant {
        if (auctions[auctionId].isCompleted) revert AuctionExpired();
        if (_amount == 0) revert AmountZero();
        if (auctions[auctionId].characters[characterId].id == 0) revert InvalidCharacter();

        ERC20(ASSET).safeTransferFrom(msg.sender, address(this), _amount);
        userBidBalance[msg.sender][auctionId] += _amount;
        auctions[auctionId].characters[characterId].poolBalance += _amount;

        //@dev note: we need to move this logic off chain to a `closeAuction` function
        //... the `closeAuction` function calling flow:
        // 1. indexes the chain of bidders from the auction (offChain) to find the topBidder
        // 2. then pass the topBidder address in the function parameters
        uint256 currentTopBidderAmount = auctions[auctionid].characters[characterId].topBidder.bidAmount;
        uint256 currentBidderPoolBalance = auctions[auctionid].characters[characterId].poolBalance;
        if (currentTopBidderAmount > currentBidderPoolBalance) {
            auctions[auctionId].characters[characterId].topBidder =
                Bidder({ wallet: msg.sender, bidAmount: currentBidderPoolBalance });
            emit NewTopBidder(auctionId, msg.sender, currentBidderPoolBalance);
        }
        emit BidPlaced(auctionId, _amount, _characterId);
    }

    //@dev note: have to check if msg.sender is top bidder and revoke top bidder status if true.
    //...this creates issue though where previous top bidder would have to be discovered somehow, so annoying issue. will require some refactoring
    function withdrawBid(uint256 _auctionId) public { }

    //this function needs to do a few different things:

    //@dev this should be able to be handled by calling digicharFactory...
    // 1. determine winning character from auction by comparing bid pools
    // 2. mint ownership certificate to top bidder from winning bid pool
    // 3. mint ERC20 token for character
    // 4. create (and lock) LP for character ERC20 token using (just winning or total?) bid pool
    // 4. update state variables relating to character token data (erc721 address, erc20 address)
    // 5. update state variables relating to bidders token claim amounts (proportionate to bid size relative to total bid pool)
    function closeAuction(uint256 _auctionId, address _topBidder) public onlyOwner { }
}
