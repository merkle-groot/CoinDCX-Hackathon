// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@OpenZeppelin/openzeppelin-contracts/token/ERC721/IERC721Reciever.sol";
import "@OpenZeppelin/openzeppelin-contracts/token/ERC721/IERC721.sol";

contract EnglishAuction is IERC721Reciever {
    event ContractInitialised();
    event AuctionStart();
    event AuctionEnd();
    event Bid(address indexed bidder, address indexed auctionId, uint256 bidAmount);

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

    }
    
    function initialiseAuction(address _tokenAddress,  uint256 _tokenId, uint256 duration, uint256 _minimumBid) external returns(bool success){   
        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctionItems[itemCounter] = AuctionItem(
            {
                tokenAddress : _tokenAddress,
                tokenOwner : msg.sender,
                tokenId : _tokenId,
                winner : msg.sender,
                auctionState : 1,
                collected : 0,
                maturity : block.timestamp + duration
            }
        );
        auctionItemIds[_tokenAddress][_tokenId] = itemCounter;
        itemCounter++;
        return 1;
    }   

    function placeBid(uint256 _id) external payable returns(bool success){
        require(block.timestamp <= auctionItems[_id].maturity, "Auction ended");
        require(msg.value > highestBid[_id].highestBidAmount, "Bid not sufficient");
        
        unusedBidAmount[highestBid[_id].bidder] -= msg.value;
        highestBid[_id] = Bid(msg.value,  msg.sender, block.timestamp);
        emit Bid(msg.sender, _id, msg.value);
        
        return 1;
    }

    function withdrawUnusedBid(uint256 _id) external returns(uint256 amount){
        require(unusedBidAmount[_id][msg.sender] > 0, "No amount to be withdrawn");
        msg.sender.transfer(unusedBidAmount[_id]);
        unusedBidAmount[_id] = 0;
    }

    function selectWinner(uint256 _id) external returns(address winner){
        require(block.timestamp > auctionItems[_id].maturity, "Auction ongoing");

        auctionItems[_id].winner = highestBid[_id].bidder;
        auctionItems[_id].status = Status.ended;
    }

    function collectNFT(uint256 _id) external returns(bool success){
        require(auctionItems[_id].status == Status.ended, "Auction not ended yet");
        require(auctionItems[_id].winner == msg.sender, "Not the winner");

        IERC721(auctionItems[_id].tokenAddress).safeTransferFrom(address(this), msg.sender, auctionItems[_id].tokenId);
        auctionItems[_id].collected = 1;
    }

    // This fallback function 
    // will keep all the Ether
    fallback () public payable{
        revert();
    }
    // function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4){
    //     AuctionItem currentAuction = auctionItems[][data]
    //     require()
    // }



}