// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IERC721Receiver} from  "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title An Auction contract that implements English Auction
/// @author vhawk19
/// @notice Can be utilised to auction an NFT emulating an English auction style. For further reference -> https://www.wallstreetmojo.com/english-auction/
/// @dev Is IERC721Receiver so that it can receieve NFTs
contract EnglishAuction is IERC721Receiver {

/// @dev events for their respective actions
    event ContractInitialised();
    event AuctionStart(uint256 auctionId, uint256 timestamp);
    event AuctionEnd(uint256 auctionId, uint256 timestamp);
    event BidEvent(address indexed bidder, uint256 indexed tokenId, uint256 bidAmount);

    enum Status{
        uninitialized,
        initialized,
        ended
    }
/// @dev keeps track of items, i.e. an ID system to uniquely identify an NFT
    uint256 private itemCounter;

/// @dev the structure of the bid placed by a user
    struct Bid{
        uint256 highestBidAmount;
        address bidder;
        uint256 timestamp;
    }

    // 0 - initialized
    // 1-- auction started
    // 2 --auction ended
/// @dev stores meta information with regards to the NFT 
    struct AuctionItem {
        address tokenAddress;
        address tokenOwner;
        uint256 tokenId;
        uint256 minimumBid;
        address winner;
        Status auctionState;
        bool collected;
        uint256 maturity;
    }

/// @dev the bid amount that did not get selected
    mapping(address => uint256) unusedBidAmount;
/// @dev a mapping of an (NFT contract address, token id) =>  item id
    mapping(address => mapping (uint256 => uint256)) auctionItemIds;
/// @dev mapping of item if to the auction item
    mapping(uint256 => AuctionItem) auctionItems;
/// @dev the highest bid for a given item id
    mapping(uint256 => Bid) highestBid;

    constructor(){
        emit ContractInitialised();
    }
    ///@dev intialiseAuction, lets the owner create a new NFT to be auction with a particular auction stratergy
    ///@param _tokenAddress address of the nft token
    ///@param _tokenId the tokenId of the NFT
    ///@param duration the duration for which the auction remains valid
    ///@param _minimumBid the minimumBid Which is to be placed for a bid to be valid
    function initialiseAuction(address _tokenAddress,  uint256 _tokenId, uint256 duration, uint256 _minimumBid) external returns(bool success){   
        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctionItems[itemCounter]  = AuctionItem({
                tokenAddress : _tokenAddress,
                tokenOwner : msg.sender,
                tokenId : _tokenId,
                winner : msg.sender,
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
    /// @dev function to be called for placing a valid bid for a given contract
    /// @param _id the id of the auction item on which the bid is to be placed
    /// @return success a boolean which indicated whether the bid was placed was succesfully or not
    function placeBid(uint256 _id) external payable returns(bool success){
        require(block.timestamp <= auctionItems[_id].maturity, "Auction ended");
        require(msg.value > auctionItems[_id].minimumBid, "Bid smaller than minimum bid");
        require(msg.value > highestBid[_id].highestBidAmount, "Bid not sufficient");
        
        unusedBidAmount[highestBid[_id].bidder] -= msg.value;
        highestBid[_id] = Bid(msg.value,  msg.sender, block.timestamp);
        emit BidEvent(msg.sender, _id, msg.value);
        
        return true;
    }
    /// @dev function to be called for withdrawing unused bids
    /// @param _id the id of the auction item on which withdraw is to be done
    /// @return amount the amount of unused bids that gets withdrawn
    function withdrawUnusedBid(uint256 _id) external returns(uint256 amount){
        uint256 withdrawAmount = unusedBidAmount[msg.sender];
        require(withdrawAmount > 0, "No amount to be withdrawn");
        (bool success, ) = msg.sender.call{value:withdrawAmount}("");
        require(success, "Transfer failed.");
        unusedBidAmount[msg.sender] = 0;

        return withdrawAmount;
    }
    /// @dev function to be called for selecting the winner
    /// @param _id the id of the auction item on which the winner is computed
    /// @return winner returns the address of the winner
    function selectWinner(uint256 _id) external returns(address winner){
        require(block.timestamp > auctionItems[_id].maturity, "Auction ongoing");

        auctionItems[_id].winner = highestBid[_id].bidder;
        auctionItems[_id].auctionState = Status.ended;

        emit AuctionEnd(_id, block.timestamp);
        return auctionItems[_id].winner;
    }

    /// @dev function to be called for collecting the NFT by the winner
    /// @param _id the id of the auction item on which collect is to be done
    /// @return success a boolean which indicated whether it was succesful or not
    function collectNFT(uint256 _id) external returns(bool success){
        require(auctionItems[_id].auctionState == Status.ended, "Auction not ended yet");
        require(auctionItems[_id].winner == msg.sender, "Not the winner");

        IERC721(auctionItems[_id].tokenAddress).safeTransferFrom(address(this), msg.sender, auctionItems[_id].tokenId);
        auctionItems[_id].collected = true;
        return true;
    }

    fallback() external payable {
        // emit Received(msg.value);
    }
    
    receive() external payable {
        // emit Received(msg.value);
    }
    ///@dev function which is executed when an NFt is deposited into the contract
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4){
        return 0x150b7a02;
    }

}