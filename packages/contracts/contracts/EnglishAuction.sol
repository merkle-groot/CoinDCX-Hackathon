// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IERC721Receiver} from  "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract EnglishAuction is IERC721Receiver {

    event ContractInitialised();
    event AuctionStart(uint256 auctionId, uint256 timestamp);
    event AuctionEnd(uint256 auctionId, uint256 timestamp);
    event BidEvent(address indexed bidder, uint256 indexed tokenId, uint256 bidAmount);

    enum Status{
        uninitialized,
        initialized,
        ended
    }

    uint256 private itemCounter;

    struct Bid{
        uint256 highestBidAmount;
        address bidder;
        uint256 timestamp;
    }

    // 0 - initialized
    // 1-- auction started
    // 2 --auction ended
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


    mapping(address => uint256) unusedBidAmount;
    mapping(address => mapping (uint256 => uint256)) auctionItemIds;
    mapping(uint256 => AuctionItem) auctionItems;
    mapping(uint256 => Bid) highestBid;

    constructor(){
        emit ContractInitialised();
    }
    
    function initialiseAuction(address _tokenAddress,  uint256 _tokenId, uint256 duration, uint256 _minimumBid) external returns(bool success){   
        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctionItems[itemCounter] = AuctionItem(
            {
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

        event AuctionStart(uint256 auctionId, uint256 timestamp);
        itemCounter++;
        
        return true;
    }   

    function placeBid(uint256 _id) external payable returns(bool success){
        require(block.timestamp <= auctionItems[_id].maturity, "Auction ended");
        require(msg.value > auctionItems[_id].minimumBid, "Bid smaller than minimum bid");
        require(msg.value > highestBid[_id].highestBidAmount, "Bid not sufficient");
        
        unusedBidAmount[highestBid[_id].bidder] -= msg.value;
        highestBid[_id] = Bid(msg.value,  msg.sender, block.timestamp);
        emit BidEvent(msg.sender, _id, msg.value);
        
        return true;
    }

    function withdrawUnusedBid(uint256 _id) external returns(uint256 amount){
        uint256 withdrawAmount = unusedBidAmount[msg.sender];
        require(withdrawAmount > 0, "No amount to be withdrawn");
        (bool success, ) = msg.sender.call{value:withdrawAmount}("");
        require(success, "Transfer failed.");
        unusedBidAmount[msg.sender] = 0;

        return withdrawAmount;
    }

    function selectWinner(uint256 _id) external returns(address winner){
        require(block.timestamp > auctionItems[_id].maturity, "Auction ongoing");

        auctionItems[_id].winner = highestBid[_id].bidder;
        auctionItems[_id].auctionState = Status.ended;

        emit AuctionEnd(_id, block.timestamp);
        return auctionItems[_id].winner;
    }

    function collectNFT(uint256 _id) external returns(bool success){
        require(auctionItems[_id].auctionState == Status.ended, "Auction not ended yet");
        require(auctionItems[_id].winner == msg.sender, "Not the winner");

        IERC721(auctionItems[_id].tokenAddress).safeTransferFrom(address(this), msg.sender, auctionItems[_id].tokenId);
        auctionItems[_id].collected = true;
        return true;
    }

    // This fallback function 
    // will keep all the Ether
    fallback () external payable{
        revert();
    }


    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4){
        return 0x150b7a02;
    }

}