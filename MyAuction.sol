// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./SampleToken.sol";

contract Auction {
    
    address payable internal auction_owner;
    uint256 public auction_start;
    uint256 public auction_end;
    uint256 public highestBid;
    address public highestBidder;
 
    bool ownerWithdrew;

    enum auction_state{
        CANCELLED,STARTED
    }

    struct  car
    {
        string  Brand;
        string  Rnumber;
    }
    
    car public Mycar;
    address[] bidders;

    mapping(address => uint) public bids;

    auction_state public STATE;


    modifier an_ongoing_auction() {
        require(block.timestamp <= auction_end && STATE == auction_state.STARTED);
        _;
    }
    
    modifier only_owner() {
        require(msg.sender==auction_owner);
        _;
    }
    
    function bid(uint256 _amount) public virtual payable returns (bool) {}
    function withdraw() public virtual returns (bool) {}
    function cancel_auction() external virtual returns (bool) {}
    
    event BidEvent(address indexed highestBidder, uint256 highestBid);
    event WithdrawalEvent(address withdrawer, uint256 amount);
    event CanceledEvent(string message, uint256 time);  
    
}

contract MyAuction is Auction {

    SampleToken public tokenContract;
    
    constructor (uint _biddingTime, address payable _owner, string memory _brand, string memory _Rnumber, SampleToken _tokenContract, ProductIdentification _prodId) {
        require(_prodId.productExistsString(_brand));

        tokenContract = _tokenContract;
        auction_owner = _owner;
        auction_start = block.timestamp;
        auction_end = auction_start + _biddingTime*1 hours;
        STATE = auction_state.STARTED;
        Mycar.Brand = _brand;
        Mycar.Rnumber = _Rnumber;
    } 
    
    function get_owner() public view returns(address) {
        return auction_owner;
    }
    
    fallback () external payable {
        
    }
    
    receive () external payable {
        
    }
    
    function bid(uint256 _amount) public payable an_ongoing_auction override returns (bool) {
        require(bids[msg.sender] == 0, "You can only bid once");
        require(_amount> highestBid,"You can't bid, Make a higher Bid");

        require(msg.sender != auction_owner, "You can't bid. Owner can't bid on his own auction.");

        uint256 originalHighestBid = highestBid;
        address originalHighestBidder = highestBidder;

        highestBid = _amount;
        highestBidder = msg.sender;
        bidders.push(msg.sender);
        bids[msg.sender] = _amount;

        if (tokenContract.balances(msg.sender) < _amount ||
           !tokenContract.transferFrom(msg.sender, address(this), _amount)) {

            highestBid = originalHighestBid;
            highestBidder = originalHighestBidder;
            delete bidders[bidders.length - 1];
            bids[msg.sender] = 0;

            revert("Insufficient funds, or not allowed to transferFrom");
        }

        emit BidEvent(highestBidder,  highestBid);


        return true;
    } 
    
    function cancel_auction() external only_owner an_ongoing_auction override returns (bool) {
    
        STATE = auction_state.CANCELLED;
        emit CanceledEvent("Auction Cancelled", block.timestamp);
        return true;
    }
    
    function withdraw() public override returns (bool) {
        
        require(block.timestamp > auction_end || STATE == auction_state.CANCELLED,"You can't withdraw, the auction is still open");
        require(msg.sender != highestBidder, "You can't withdraw, you won the auction");
        require(msg.sender == auction_owner || bids[msg.sender] > 0, "You can't withdraw nothing");
        require(msg.sender != auction_owner || !ownerWithdrew, "Owner already withdrew");
        uint256 amount;

        if (msg.sender != auction_owner) {
            amount = bids[msg.sender];
            bids[msg.sender] = 0;
        } else {
            amount = highestBid;
            ownerWithdrew = true;
        }

        if (!tokenContract.transfer(msg.sender, amount)) {
            if (msg.sender != auction_owner) {
                bids[msg.sender] = amount;
            } else {
                ownerWithdrew = false;
            }

            revert();
        }

        emit WithdrawalEvent(msg.sender, amount);
        return true;
      
    }
    
    function destruct_auction() external only_owner returns (bool) {
        require(block.timestamp > auction_end || STATE == auction_state.CANCELLED,"You can't destruct the contract,The auction is still open");

        bool success = true;

        for(uint i = 0; i < bidders.length; i++)
        {
            if (bids[bidders[i]] > 0) {

                uint256 amount = bids[bidders[i]];
                bids[bidders[i]] = 0;

                if (bidders[i] != highestBidder) {
                    if (!tokenContract.transfer(bidders[i], amount)) {
                        bids[bidders[i]] = amount;
                        success = false;
                    }
                }
            }
        }
        if (!ownerWithdrew) {
            ownerWithdrew = true;

            if (!tokenContract.transfer(auction_owner, highestBid)) {
                ownerWithdrew = false;
                success = false;
            }
        }

        if (success) {
            selfdestruct(auction_owner);
            return true;
        }
        
        return false;
    
    } 
}


