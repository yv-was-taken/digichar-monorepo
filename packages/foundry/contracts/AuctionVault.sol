// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Config } from "./Config.sol";

contract AuctionVault {
    using SafeTransferLib for ERC20;

    Config config;

    constructor(address _config) {
        config = Config(_config);
    }

    //errors
    error OnlyProtocolAdmin();
    error AuctionClosed();
    error AmountZero();
    error AuctionExpired();
    error InvalidCharacter();
    error AmountTooLarge();
    error AuctionStillOpen();
    error AlreadyClaimed();

    //events
    event AuctionTimeChanged(uint256 _auctionDurationTime);
    event DigicharTokenSet(address _digicharToken);
    event BidPlaced(uint256 indexed _auctionId, address indexed _user, uint256 _amount, uint256 _characterId);
    event BidWithdrawn(uint256 _auctionId, address user, uint256 _withdrawAmount);

    //state variables
    uint256 public auctionId;
    bool private _locked; //@dev used only for noReentrant modifier

    //update state variable functions
    //@TODO should be defined in (and grabbed from) config
    //@dev extract token metric constants to contract config
    uint256 initialTokenSupplyForEachCharacter = 500_000 * 1 * 10 ** 18;

    //mappings
    mapping(uint256 => Auction) public auctions;
    mapping(address => mapping(uint256 => mapping(uint8 => uint256))) public userBidBalance;
    mapping(uint256 => address) characterTokensByAuctionId;
    mapping(address => mapping(uint256 => bool)) hasUserClaimedTokens;

    //@dev not sure if this is needed, but it does create easier Ux for external user-interactions on checking for unclaimed tokens etc.
    // i guess im just not decided on if its over the tradeoff of more gas being required for this contract keeping this here
    // going to keep this here for now and worry about that later.
    mapping(uint256 => uint8) winningCharacterIndexesForEachAuction;

    //modifiers
    modifier onlyProtcolAdmin() {
        if (msg.sender != config.protocolAdmin()) revert OnlyProtocolAdmin();
        _;
    }

    modifier noReentrant() {
        if (_locked) revert("ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    //structs
    struct Character {
        string characterURI;
        string name;
        string symbol;
        uint256 poolBalance;
        bool isWinner;
    }

    struct Auction {
        Character[3] characters;
        uint256 endTime;
    }

    function getAuctionCharacterData(uint256 _auctionId, uint256 _characterIndex)
        external
        view
        returns (string memory, string memory, string memory, uint256, bool)
    {
        Character storage character = auctions[_auctionId].characters[_characterIndex];

        return (character.characterURI, character.name, character.symbol, character.poolBalance, character.isWinner);
    }

    //@TODO replace all instances of `getCurrentAuctionEndTime` with `getAuctionEndTime(uint _auctionId)`
    function getCurrentAuctionEndTime() public view returns (uint256) {
        return auctions[auctionId].endTime;
    }
    function getAuctionEndTime(uint _auctionId) public view returns (uint256) {
      return auctions[_auctionId].endTime;

    }

    //contract core

    function createAuction(string[3] memory characterURIs, string[3] memory names, string[3] memory symbols)
        public
        onlyProtcolAdmin
    {
        if (block.timestamp < auctions[auctionId].endTime) revert AuctionStillOpen();
        Auction storage newAuction = auctions[auctionId];
        newAuction.endTime = block.timestamp + config.AUCTION_DURATION_TIME();

        for (uint8 i = 0; i < 3; i++) {
            //@dev no need to set `poolBalance` or `isWinner` since both default to 0 and false respectively on initialization
            newAuction.characters[i].characterURI = characterURIs[i];
            newAuction.characters[i].name = names[i];
            newAuction.characters[i].symbol = symbols[i];
        }
    }

    function bid(uint8 _characterIndex) public payable noReentrant {
        if (msg.value == 0) revert AmountZero();
        if (block.timestamp >= getCurrentAuctionEndTime()) revert AuctionExpired();

        //@dev checking if characterURI being bid on is valid
        bytes memory characterURIbytes = bytes(auctions[auctionId].characters[_characterIndex].characterURI);
        if ((characterURIbytes).length == 0) revert InvalidCharacter();

        userBidBalance[msg.sender][auctionId][_characterIndex] += msg.value;
        auctions[auctionId].characters[_characterIndex].poolBalance += msg.value;

        emit BidPlaced(auctionId, msg.sender, msg.value, _characterIndex);
    }

    function withdrawBid(uint256 _auctionId, uint8 _characterIndex, uint256 _amount) public noReentrant {
        if (_amount == 0) revert AmountZero();
        // @dev cannot withdraw bid from winning character bid pool as auction is complete by that point
        if (auctions[_auctionId].characters[_characterIndex].isWinner) revert InvalidCharacter();

        uint256 _userBalance = userBidBalance[msg.sender][_auctionId][_characterIndex];
        if (_amount > _userBalance) revert AmountTooLarge();

        (bool success,) = payable(msg.sender).call{ value: _amount }("");
        require(success, "ETH transfer failed");
        userBidBalance[msg.sender][_auctionId][_characterIndex] -= _amount;
        auctions[auctionId].characters[_characterIndex].poolBalance -= _amount;
        emit BidWithdrawn(auctionId, msg.sender, _amount);
    }

    //this function needs to do a few different things:

    //@dev this should be able to be handled by calling digicharFactory...
    // 1. determine winning character from auction by comparing bid pools
    // 2. mint ownership certificate to top bidder from winning bid pool
    // 3. mint ERC20 token for character
    // 4. create (and lock) LP for character ERC20 token using (just winning or total?) bid pool
    // 4. update state variables relating to character token data (erc721 address, erc20 address)
    // 5. update state variables relating to bidders token claim amounts (proportionate to bid size relative to total bid pool)

    //@dev note: _winningCharacterIndex and _topBidder is determined from offchain indexing.

    function closeCurrentAuction(address _topBidder, uint8 _winningCharacterIndex) public onlyProtcolAdmin {
        if (block.timestamp < auctions[auctionId].endTime) revert AuctionStillOpen();
        auctions[auctionId].characters[_winningCharacterIndex].isWinner = true;
        winningCharacterIndexesForEachAuction[auctionId] = _winningCharacterIndex;

        string memory winningCharacterURI = auctions[auctionId].characters[_winningCharacterIndex].characterURI;
        string memory winningCharacterName = auctions[auctionId].characters[_winningCharacterIndex].name;
        string memory winningCharacterSymbol = auctions[auctionId].characters[_winningCharacterIndex].symbol;

        uint256 winningPoolBalance = auctions[auctionId].characters[_winningCharacterIndex].poolBalance;

        //if no bids in auction, close auction without creating character
        if (winningPoolBalance == 0) {
            auctionId++;
            return;
        }

        // Create character, sending winning pool balance for token creation
        address _tokenAddress = config.digicharFactory().createCharacter{ value: winningPoolBalance }(
            _topBidder, _winningCharacterIndex, winningCharacterURI, winningCharacterName, winningCharacterSymbol
        );
        characterTokensByAuctionId[auctionId] = _tokenAddress;

        auctionId++;
    }

    event TokensClaimed(address _user, uint256 _auctionId);

    function claimTokens(uint256 _auctionId) public {
        if (_auctionId == auctionId) revert AuctionStillOpen();
        uint256 unclaimedTokens = checkUnclaimedTokens(msg.sender, _auctionId);
        if (unclaimedTokens == 0) revert AmountZero();

        address _characterTokenAddress = characterTokensByAuctionId[_auctionId];
        ERC20(_characterTokenAddress).safeTransfer(msg.sender, unclaimedTokens);
        //once everything else is done..
        //mark user as having claimed tokens so they can't claim again
        hasUserClaimedTokens[msg.sender][_auctionId] = true;
        emit TokensClaimed(msg.sender, _auctionId);
    }

    function checkUnclaimedTokens(address _user, uint256 _auctionId) public view returns (uint256) {
        if (_auctionId == auctionId) revert AuctionStillOpen();
        if (hasUserClaimedTokens[_user][_auctionId]) return 0;

        uint8 _winningCharacterIndex = winningCharacterIndexesForEachAuction[_auctionId];
        //get user bid balance from auction (for winning auction pool)
        uint256 userAuctionBalance = userBidBalance[_user][_auctionId][_winningCharacterIndex];
        if (userAuctionBalance == 0) return 0;
        uint256 auctionPoolBalance = auctions[_auctionId].characters[_winningCharacterIndex].poolBalance;

        uint256 userTokenAllocation = (userAuctionBalance * initialTokenSupplyForEachCharacter) / auctionPoolBalance;

        return userTokenAllocation;
    }

    function getCharacterTokenAddress(uint256 _auctionId) public view returns (address) {
        if (_auctionId == auctionId) revert AuctionStillOpen();
        return characterTokensByAuctionId[_auctionId];
    }

    //getter functions
    function getPoolBalance(uint256 _auctionId, uint256 _characterIndex) external view returns (uint256) {
        return auctions[_auctionId].characters[_characterIndex].poolBalance;
    }

    function getUserBidBalance(address _user, uint256 _auctionId, uint8 _characterIndex)
        external
        view
        returns (uint256)
    {
        return userBidBalance[_user][_auctionId][_characterIndex];
    }
}
