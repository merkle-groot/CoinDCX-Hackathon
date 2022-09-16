// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.8;

// import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// contract Sealed is IERC721Receiver {
//     event ContractInitialisedEvent();
//     event AuctionStartEvent(uint256 indexed auctionId, uint256 timestamp);
//     event AuctionRevealStartEvent(uint256 indexed auctionId, uint256 timestamp);
//     event AuctionEndEvent(uint256 indexed auctionId, uint256 timestamp);
//     event BidEvent(address indexed bidder, uint256 indexed auctionId, bytes32 commitmentHash);
//     event BidReveal(address indexed bidder, uint256 indexed auctionId, uint256 amount);

//     // 0 - initialized
//     // 1-- auction started
//     // 2 --auction ended
//     enum Status{
//         uninitialized,
//         initialized,
//         revealPeriod,
//         ended
//     }

//     uint256 private itemCounter;

//     struct Bid {
//         uint256 highestBidAmount;
//         address bidder;
//         uint256 timestamp;
//     }

  
//     struct AuctionItem {
//         address tokenAddress;
//         address tokenOwner;
//         uint256 tokenId;
//         address winner;
//         Status auctionState;
//         bool collected;
//         uint256 auctionTime;
//         uint256 revealTime;
//         uint256 minimumBid;
//     }

//     mapping(address => uint256) public unusedBidAmount;
//     mapping(address => mapping (uint256 => uint256)) public auctionItemIds;
//     mapping(uint256 => AuctionItem) public auctionItems;
//     mapping(uint256 => mapping (address => bytes32)) public commitments;
//     mapping(uint256 => Bid) public highestBid;
//     constructor() public{   
//         emit ContractInitialisedEvent();
//     }
    
//     ///@dev intialiseAuction, lets the owner create a new NFT to be auction with a particular auction stratergy
//     ///@param _tokenAddress address of the nft token
//     ///@param _tokenId the tokenId of the NFT
//     ///@param _duration the duration for which the auction remains valid
//     ///@param _minimumBid the minimumBid Which is to be placed for a bid to be valid
//     function initialiseAuction(address _tokenAddress, uint256 _tokenId, uint256 _duration, uint256 _minimumBid) external returns(bool success){   
//         IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
//         auctionItems[itemCounter]  = AuctionItem(
//             {
//                 tokenAddress : _tokenAddress,
//                 tokenOwner : msg.sender,
//                 tokenId : _tokenId,
//                 winner : msg.sender,
//                 auctionState : Status.initialized,
//                 collected : false,
//                 auctionTime : block.timestamp + _duration,
//                 revealTime : block.timestamp + (_duration * 2),
//                 minimumBid : _minimumBid
//             }
//         );
//         auctionItemIds[_tokenAddress][_tokenId] = itemCounter;

//         emit AuctionStartEvent(itemCounter, block.timestamp);
//         itemCounter++;
//         return true;
//     }   

//     function placeBid(uint256 _id, bytes32 _commitmentHash) external payable returns(bool success){
//         require(block.timestamp <= auctionItems[_id].auctionTime, "Auction ended");
//         require(commitments[_id][msg.sender] == 0, "Bid already placed by the user");

//         commitments[_id][msg.sender] = _commitmentHash;

//         emit BidEvent(msg.sender, _id, _commitmentHash);
//         return true;
//     }
//     function toggleRevealPeriod(uint256 _id) external returns(bool success){
//         require(block.timestamp > auctionItems[_id].auctionTime, "Auction ongoing");

//         auctionItems[_id].auctionState = Status.revealPeriod;

//         emit AuctionRevealStartEvent(_id, block.timestamp);
//         return true;
//     }

//     function revealBid(uint256 _id, uint256 _bid, uint256 _secret) external returns(bool success){
//         require(auctionItems[_id].auctionState == Status.revealPeriod, "Auction is not in the reveal period");
//         require(commitments[_id][msg.sender] != 0, "User did not make a commitment");
//         require(keccak256(abi.encode(_bid, _secret)) == commitments[_id][msg.sender], "Doesn't match with commitment");

//         if(_bid > highestBid[_id].highestBidAmount && _bid > auctionItems[_id].minimumBid){
//             highestBid[_id] = Bid(_id, msg.sender, block.timestamp);
//         }

//         emit BidReveal(msg.sender, _id, _bid);
//         return true;
//     }
//     function toggleEnd(uint256 _id) external returns(bool success){
//         require(auctionItems[_id].auctionState == Status.revealPeriod, "Auction is not in the reveal period");
//         require(block.timestamp > auctionItems[_id].revealTime, "Reveal period ongoing");

//         auctionItems[_id].auctionState = Status.ended;
//         auctionItems[_id].winner = highestBid[_id].bidder;

//         emit AuctionEndEvent(_id, block.timestamp);
//         return true;
//     }
//     function collectNFT(uint256 _id) external payable returns(bool success){
//         require(auctionItems[_id].auctionState == Status.ended, "Auction not ended yet");
//         require(auctionItems[_id].winner == msg.sender, "Not the winner");
//         require(msg.value >= highestBid[_id].highestBidAmount);

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