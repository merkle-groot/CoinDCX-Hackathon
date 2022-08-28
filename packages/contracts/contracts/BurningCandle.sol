// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IERC721Receiver} from  "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @title An auctions contract toolbox
/// @author Blockheads
/// @notice You can use this contract for only the most basic simulation
/// @dev All function calls are currently implemented without side effects
/// @custom:experimental This is an experimental contract.
contract BurningCandle is VRFConsumerBaseV2, IERC721Receiver {
    VRFCoordinatorV2Interface COORDINATOR;
    /// @dev These are events which maybe used for collecting logs/aggregating for insights 
    event ContractInitialised();
    event AuctionStart(uint256 indexed auctionId, uint256 timestamp);
    event AuctionEnd(uint256 indexed auctionId, uint256 timestamp);
    event BidEvent(address indexed bidder, uint256 indexed tokenId, uint256 bidAmount);
    event OracleUpdate(uint256 indexed auctionId);

    /// @dev An enum which represents the current state of the action and list the prmissable state it may enter 
    enum Status{
        uninitialized,
        initialized,
        oracle_requested,
        ended
    }
    /// @dev A struct which is used to represent the bid details, the bid amount, bidder etc
    struct Bid{
        uint256 highestBidAmount;
        address bidder;
        uint256 timestamp;
    }

    // 0 - initialized
    // 1-- auction started
    // 2 --auction ended
    /// @dev The struct that maintains the state of the auction item
    struct AuctionItem {
        address tokenAddress;
        address tokenOwner;
        uint256 tokenId;
        uint256 minimumBid;
        uint256 winningIndex;
        Status auctionState;
        bool collected;
        uint256 maturity;
    }
    /// @dev Keeps track of the number items
    uint256 private itemCounter;
    uint64 immutable s_subscriptionId;
    bytes32 immutable s_keyHash;
    uint32 constant callbackGasLimit = 40000;
    uint16 constant requestConfirmations = 3;
    uint32 constant numWords =  1;

    mapping(address => uint256) public totalBidAmount;
    mapping(address => mapping (uint256 => uint256)) public auctionItemIds;
    mapping(uint256 => AuctionItem) public auctionItems;
    mapping(uint256 => mapping (uint256 => Bid)) public bids;
    mapping(uint256 => uint256) public noOfBids;
    mapping(uint256 => Bid) public highestBid;

    // map rollers to requestIds
    mapping(uint256 => uint256) private requestId_to_auctionId;
    ///@dev constructor which initialises the VRF consumer
    constructor(uint64 _s_subscriptionId, address _vrfCoordinator, bytes32 _s_keyHash) VRFConsumerBaseV2(_vrfCoordinator){
        s_subscriptionId = _s_subscriptionId;
        s_keyHash = _s_keyHash;

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        emit ContractInitialised();
    }
    
    ///@dev intialiseAuction, lets the owner create a new NFT to be auction with a particular auction stratergy
    ///@param _tokenAddress address of the nft token
    ///@param _tokenId the tokenId of the NFT
    ///@param duration the duration for which the auction remains valid
    ///@param _minimumBid the minimumBid Which is to be placed for a bid to be valid
    function initialiseAuction(address _tokenAddress,  uint256 _tokenId, uint256 duration, uint256 _minimumBid) external returns(bool success){   
        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctionItems[itemCounter] = AuctionItem(
            {
                tokenAddress : _tokenAddress,
                tokenOwner : msg.sender,
                tokenId : _tokenId,
                winningIndex : 0,
                auctionState : Status.initialized,
                minimumBid: _minimumBid,
                collected : false,
                maturity : block.timestamp + duration
            }
        );
        auctionItemIds[_tokenAddress][_tokenId] = itemCounter;

        emit AuctionStart(itemCounter, block.timestamp);
        itemCounter++;
        
        return true;
    }   
    /// @dev place a bid to the contract
    /// @param _id the id of the auction item on which the bid is to be placed
    /// @return success a boolean which indicated whether it was succesful or not
    function placeBid(uint256 _id) external payable returns(bool success){
        require(block.timestamp <= auctionItems[_id].maturity, "Auction ended");
        require(msg.value > auctionItems[_id].minimumBid, "Bid smaller than minimum bid");
        require(msg.value > highestBid[_id].highestBidAmount, "Bid not sufficient");
        
        highestBid[_id] = Bid(msg.value,  msg.sender, block.timestamp);
        bids[_id][noOfBids[_id]] = Bid(msg.value,  msg.sender, block.timestamp);
        totalBidAmount[msg.sender] += msg.value;
        noOfBids[_id]++;
        emit BidEvent(msg.sender, _id, msg.value);
        
        return true;
    }

    /// @dev withdraw funds which dont constitute towards a placed bid
    /// @param _id the id of the auction item on which the bid is to be placed
    /// @return amount, the amount withdrawn from the contract
    function withdrawUnusedBid(uint256 _id) external returns(uint256 amount){
        uint256 withdrawAmount = totalBidAmount[msg.sender];
        require(withdrawAmount > 0, "No amount to be withdrawn");
        (bool success, ) = msg.sender.call{value:withdrawAmount}("");
        require(success, "Transfer failed.");
        totalBidAmount[msg.sender] = 0;

        return withdrawAmount;
    }
    /// @dev select the winner of the given auction
    /// @param _id the id of the auction item on which the bid is to be placed
    /// @return success, whether the given function was executed successfully or not
    function selectWinner(uint256 _id) external returns(bool success){
        require(block.timestamp > auctionItems[_id].maturity, "Auction ongoing");

        // ChainLink VRF
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );


        // auctionItems[_id].winner = highestBid[_id].bidder;
        auctionItems[_id].auctionState = Status.oracle_requested;
        requestId_to_auctionId[requestId] = _id;
        return true;
        // emit AuctionEnd(_id, block.timestamp);
        // return auctionItems[_id].winner;
    }
    ///@dev VRFConsumer functions
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 auctionId = requestId_to_auctionId[requestId];
        uint256 bidsCount = noOfBids[auctionId];
        
        uint256 five_percent = uint256(bidsCount * 5 ) / uint256(100);
        uint256 random_value = (randomWords[0] % five_percent) + 1;
        auctionItems[auctionId].winningIndex = bidsCount - random_value;
        auctionItems[auctionId].auctionState = Status.ended;
        emit OracleUpdate(auctionId);
    }

    /// @dev function which is utilised to collect the NFT for the winner
    /// @param _id the id of the auction item on which collect is to be done
    /// @return success a boolean which indicated whether it was succesful or not
    function collectNFT(uint256 _id) external returns(bool success){
        uint256 requiredIndex = auctionItems[_id].winningIndex;
        require(auctionItems[_id].auctionState == Status.ended, "Auction not ended yet");
        require(bids[_id][requiredIndex].bidder == msg.sender, "Not the winner");
        
        IERC721(auctionItems[_id].tokenAddress).safeTransferFrom(address(this), msg.sender, auctionItems[_id].tokenId);
        auctionItems[_id].collected = true;
        return true;
    }

    // This fallback function 
    // will keep all the Ether
    fallback () external payable{
        revert();
    }

    ///@dev function which is executed when an NFt is deposited into the contract
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4){
        return 0x150b7a02;
    }

}