interface IEnglishAuction {
    event ContractInitialisedEvent();
    event AuctionStartEvent();
    event AuctionEndEvent();
    event BidEvent(address indexed bidder, uint256 indexed auctionId, uint256 bidAmount);

}