// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DigicharFactory } from "./DigicharFactory.sol";
import { DigicharToken } from "./DigicharToken.sol";

contract AuctionVault {
    using SafeTransferLib for ERC20;

    error OnlyOwner();
    error AuctionClosed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    //asset for vault deposits
    ERC20 public immutable ASSET;
    address public owner;
    DigicharFactory digicharFactory;
    DigicharToken digicharToken;

    event DigicharFactorySet(address _digicharFactory);

    function setDigicharFactory(address payable _digicharFactory) public onlyOwner {
        digicharFactory = DigicharFactory(_digicharFactory);
        emit DigicharFactorySet(_digicharFactory);
    }

    event DigicharTokenSet(address _digicharToken);

    function setDigicharToken(address _digicharToken) public onlyOwner {
        digicharToken = DigicharToken(_digicharToken);
        emit DigicharTokenSet(_digicharToken);
    }

    constructor(address _asset) {
        owner = msg.sender;
        ASSET = ERC20(_asset);
    }

    uint256 auctionDurationTime = 4 hours;

    event AuctionTimeChanged(uint256 _auctionDurationTime);

    function changeAuctionDurationTime(uint256 _auctionDurationTime) public onlyOwner {
        auctionDurationTime = _auctionDurationTime;
        emit AuctionTimeChanged(_auctionDurationTime);
    }

    struct BidPool {
        string characterURI;
        uint256 poolBalance;
    }

    struct Auction {
        BidPool[3] characters;
        uint256 endTime;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionId;

    function createAuction(string[3] memory characterURIs) public onlyOwner {
        Auction storage newAuction = auctions[auctionId];
        newAuction.endTime = block.timestamp + auctionDurationTime;

        for (uint8 i = 0; i < 3; i++) {
            newAuction.characters[i].characterURI = characterURIs[i];
            newAuction.characters[i].poolBalance = 0;
        }

        auctionId++;
    }

    bool private _locked;

    modifier noReentrant() {
        if (_locked) revert("ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    error AmountZero();
    error AuctionExpired();
    error InvalidCharacter();

    event BidPlaced(uint256 indexed _auctionId, address indexed _user, uint256 _amount, uint256 _characterId);

    mapping(address => mapping(uint256 => mapping(uint8 => uint256))) public userBidBalance;

    function bid(uint256 _amount, uint8 _characterIndex) public noReentrant {
        if (auctions[auctionId].endTime >= block.timestamp) revert AuctionExpired();
        if (_amount == 0) revert AmountZero();

        //@dev checking if characterURI being bid on is valid
        bytes memory characterURIbytes = bytes(auctions[auctionId].characters[_characterIndex].characterURI);
        if ((characterURIbytes).length == 0) revert InvalidCharacter();

        ERC20(ASSET).safeTransferFrom(msg.sender, address(this), _amount);
        userBidBalance[msg.sender][auctionId][_characterIndex] += _amount;
        auctions[auctionId].characters[_characterIndex].poolBalance += _amount;

        emit BidPlaced(auctionId, msg.sender, _amount, _characterIndex);
    }

    event BidWithdrawn(uint256 _auctionId, address user, uint256 _withdrawAmount);

    error AmountTooLarge();

    function withdrawBid(uint256 _amount, uint8 _characterIndex) public {
        if (auctions[auctionId].endTime >= block.timestamp) revert AuctionExpired();
        if (_amount == 0) revert AmountZero();

        uint256 characterPoolBalance = userBidBalance[msg.sender][auctionId][_characterIndex];
        if (_amount > characterPoolBalance) revert AmountTooLarge();

        ERC20(ASSET).safeTransfer(msg.sender, _amount);
        userBidBalance[msg.sender][auctionId][_characterIndex] -= _amount;
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

    error AuctionStillOpen();

    //@dev note: _winningCharacterIndex and _topBidder is determined from offchain indexing.
    function closeCurrentAuction(uint256 _winningCharacterIndex, address _topBidder) public onlyOwner {
        if (block.timestamp >= auctions[auctionId].endTime) revert AuctionStillOpen();

        string memory winningCharacterURI = auctions[auctionId].characters[_winningCharacterIndex].characterURI;
        // Get winning bid pool amount
        uint256 winningPoolBalance = auctions[auctionId].characters[_winningCharacterIndex].poolBalance;

        // Create character, sending winning pool balance for token creation
        digicharFactory.createCharacter{ value: winningPoolBalance }(
            _topBidder, _winningCharacterIndex, winningCharacterURI
        );
        auctionId++;
    }

    function claimTokens(uint256 _auctionId) public {
        if (block.timestamp >= auctions[auctionId].endTime) revert AuctionStillOpen();
        //@TODO
    }

    function getPoolBalance(uint256 _auctionId, uint256 _characterIndex) external view returns (uint256) {
        return auctions[_auctionId].characters[_characterIndex].poolBalance;
    }

    function getUserBidBalance(address _user, uint256 _auctionId, uint8 _characterIndex)
        external
        view
        returns (uint256)
    {
        return userBidBalance[_user][auctionId][_characterIndex];
    }
}
