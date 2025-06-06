// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DigicharFactory } from "./DigicharFactory.sol";
import { DigicharToken } from "./DigicharToken.sol";

contract AuctionVault is Structs{
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
    function setDigicharFactory(address _digicharFactory) public onlyOwner {
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
        Character character;
        uint256 poolBalance;
    }

    struct Auction {
        BidPool[3] characters;
        uint256 endTime;
        bool isClosed; //@dev is this variable needed? can just use endTime for everything, right?
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionId = 0;
    //@dev initializing to one for valid character id checking in bid() function, allowing for zero would create a vulnerability allowing users to bid on characters from previous auctions
    uint256 public characterId = 1;

    function createAuction(
        string[3] memory _characterName,
        string[3] memory _characterTicker,
        string[3] memory _characterTokenURI,
        string[3] memory _characterDescription
    ) public onlyOwner {
        BidPool[3] memory characterBidPools;
        for (uint8 i = 0; i < 3; i++) {
            Character memory character = Character({
                name: _characterName[i],
                ticker: _characterTicker[i],
                tokenURI: _characterTokenURI[i],
                description: _characterDescription[i],
                id: characterId
            });
            characterId++;

            BidPool memory characterBidPool = BidPool({ character: character, poolBalance: 0 });
            characterBidPools[i] = characterBidPool;
        }

        auctions[auctionId] =
            Auction({ characters: characterBidPools, endTime: block.timestamp + auctionDurationTime, isClosed: false });
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

    mapping(address => mapping(uint256 => uint256)) public userBidBalance;

    function bid(uint256 _amount, uint256 _characterIndex) public noReentrant {
        if (auctions[auctionId].endTime >= block.timestamp) revert AuctionExpired();
        if (_amount == 0) revert AmountZero();
        if (auctions[auctionId].characters[_characterIndex].character.id == 0) revert InvalidCharacter();

        ERC20(ASSET).safeTransferFrom(msg.sender, address(this), _amount);
        userBidBalance[msg.sender][auctionId] += _amount;
        auctions[auctionId].characters[_characterIndex].poolBalance += _amount;

        emit BidPlaced(auctionId, msg.sender, _amount, auctions[auctionId].characters[_characterIndex].character.id);
    }

    event BidWithdrawn(uint256 _auctionId, address user, uint256 _withdrawAmount);

    function withdrawBid(uint256 _amount) public {
        if (auctions[auctionId].endTime >= block.timestamp) revert AuctionExpired();
        if (_amount == 0) revert AmountZero();
        ERC20(ASSET).safeTransfer(msg.sender, _amount);
        userBidBalance[msg.sender][auctionId] -= _amount;
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
    //@dev note: _auctionWinnerCharacterIndex and _topBidder is determined from offchain indexing.
    function closeCurrentAuction(uint _auctionWinnerCharacterIndex, address _topBidder) public onlyOwner {
        if (block.timestamp >= auctions[auctionId].endTime) revert AuctionStillOpen();

        Character memory winningCharacter = auctions[auctionId].characters[_auctionWinnerCharacterIndex].character;
  
        digicharFactory.createCharacter(winningCharacter, _topBidder);
        //

        //mint ownership certificate
        uint ownershipCertificateId = digicharFactory.mintOwnershipCertificate(winningCharacter, _topBidder);
        //send ownership certificate to top bidder
        DigicharFactory(digicharFactory).transferFrom(address(this), _topBidder, ownershipCertificateId);

        //mint character tokens 
        address digicharTokenAddress = digicharFactory.mintTokens(winningCharacter, _topBidder);
        //create LP for character token using winning bid pool balance

        
        //send lp to burn address


    }

    function claimTokens(uint _auctionId) public {
        if (block.timestamp >= auctions[auctionId].endTime) revert AuctionStillOpen();
    }
}
