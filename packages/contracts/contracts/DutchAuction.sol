// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.8;

// import {IERC721Receiver} from  "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// contract DutchAuction is IERC721Receiver {

//     event ContractInitialised();
//     event AuctionStart(uint256 auctionId, uint256 timestamp);
//     event AuctionEnd(uint256 auctionId, uint256 timestamp);
//     event BidEvent(address indexed bidder, uint256 indexed tokenId, uint256 bidAmount);

//     enum Status{
//         uninitialized,
//         initialized,
//         ended
//     }

//     uint256 private itemCounter;

//     struct Bid{
//         uint256 highestBidAmount;
//         address bidder;
//         uint256 timestamp;
//     }

//     // 0 - initialized
//     // 1-- auction started
//     // 2 --auction ended
//     struct AuctionItem {
//         address tokenAddress;
//         address tokenOwner;
//         uint256 tokenId;
//         address winner;
//         Status auctionState;
//         bool collected;
//         uint256 maturity;
//         uint256 duration;
//         uint256 discount;
//       uint256 startingPrice;
//     }


//     mapping(address => mapping (uint256 => uint256)) public auctionItemIds;
//     mapping(uint256 => AuctionItem) public auctionItems;
//     Bid winningBid;
//     constructor(){
//         emit ContractInitialised();
//     }

 
//     function currentPrice(AuctionItem memory auctionItem) public view returns(uint256 price){
//         uint256 timeElapsed = auctionItem.maturity - block.timestamp;
//         uint256 discountRate = timeElapsed*1000000/auctionItem.duration;
//          price = auctionItem.startingPrice - (auctionItem.discount*discountRate);
        
//     }
//     function initialiseAuction(address _tokenAddress,  uint256 _tokenId, uint256 _duration, uint256 _minimumBid, uint256 _startBid) external returns(bool success){   
//         IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
//         auctionItems[itemCounter]  = AuctionItem(
//             {
//                 tokenAddress : _tokenAddress,
//                 tokenOwner : msg.sender,
//                 tokenId : _tokenId,
//                 winner : msg.sender,
//                 auctionState : Status.initialized,
//                 discount: _minimumBid,
//                 collected : false,
//                 maturity : block.timestamp + _duration,
//                 duration: _duration,
//                 startingPrice: _startBid
//             });

//         auctionItemIds[_tokenAddress][_tokenId] = itemCounter;

//         emit AuctionStart(itemCounter, block.timestamp);
//         itemCounter++;

//         return true;
//     }   

//     function placeBid(uint256 _id) external payable returns(bool success){
//         require(block.timestamp <= auctionItems[_id].maturity, "Auction ended");
//         require(msg.value <= currentPrice( auctionItems[_id]), "Amount larger than current rate");
        

//         winningBid = Bid(msg.value,  msg.sender, block.timestamp);
//         auctionItems[_id].auctionState = Status.ended;
//         auctionItems[_id].winner = msg.sender;
//         emit BidEvent(msg.sender, _id, msg.value);
        
        
//         return true;
//     }



//     function collectNFT(uint256 _id) external returns(bool success){
//         require(auctionItems[_id].auctionState == Status.ended, "Auction not ended yet");
//         require(auctionItems[_id].winner == msg.sender, "Not the winner");

//         IERC721(auctionItems[_id].tokenAddress).safeTransferFrom(address(this), msg.sender, auctionItems[_id].tokenId);
//         auctionItems[_id].collected = true;
//         return true;
//     }

//     // This fallback function 
//     // will keep all the Ether
//     fallback () external payable{
//         revert();
//     }


//     function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4){
//         return 0x150b7a02;
//     }

// }
