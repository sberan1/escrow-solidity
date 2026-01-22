// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./IEscrow.sol";

contract Escrows is IEscrow{
    uint256 private counter;
    mapping(uint256 => Escrow) public escrows;

    modifier onlyBuyer(uint256 _id) {
        require(msg.sender == escrows[_id].buyer, "Only buyer can call this");
        _;
    }

    modifier onlySeller(uint256 _id) {
        require(msg.sender == escrows[_id].seller, "Only seller can call this");
        _;
    }

    modifier onlyArbiter(uint256 _id) {
        require(msg.sender == escrows[_id].arbiter, "Only arbiter can call this");
        _;
    }

    modifier inState(uint256 _id, State _state) {
        require(escrows[_id].state == _state, "Wrong state");
        _;
    }

    function createEscrow(address _buyer, address payable _seller, address _arbiter, uint256 _requestedAmount) external returns(bool){
        require(_buyer != address(0) && _seller != address(0) && _arbiter != address(0), "Invalid address");
        require(_seller == msg.sender, "Only seller can create escrow");

        uint256 escrowId = counter++;
        escrows[escrowId] = Escrow(
            _buyer,
            _seller,
            _arbiter,
            0,
            _requestedAmount,
            State.AWAITING_PAYMENT
        );

        emit EscrowCreated(counter, _buyer, _seller);
        return true;
    }

    function deposit(uint256 _escrowId) external payable onlyBuyer(_escrowId){
        require(msg.value > 0, "Deposit must be > 0");
        require(escrows[_escrowId].state == State.AWAITING_PAYMENT, "Wrong state");
        require(msg.value == escrows[_escrowId].requestedAmount, "Not enough value for this escrow");

        escrows[_escrowId].amount = msg.value;
        escrows[_escrowId].state = State.AWAITING_DELIVERY;

        emit Deposited(_escrowId, msg.value);
    }

    function markShipped(uint256 _escrowId) external onlySeller(_escrowId){
        require(escrows[_escrowId].state == State.AWAITING_DELIVERY, "Wrong state");
        emit ItemShipped(_escrowId);
    }

    function confirmDelivery(uint256 _escrowId) external onlyArbiter(_escrowId){
        require(escrows[_escrowId].state == State.AWAITING_DELIVERY, "Wrong state");
        escrows[_escrowId].state = State.COMPLETE;

        uint256 payment = escrows[_escrowId].amount;
        escrows[_escrowId].amount = 0;

        (bool sent, ) = escrows[_escrowId].seller.call{value: payment}("");
        require(sent, "Failed to send Ether");

        emit Confirmed(_escrowId);
    }

    function disputeDelivery(uint256 _escrowId, string calldata _evidenceUrl) external onlyBuyer(_escrowId){
        require(escrows[_escrowId].state == State.AWAITING_DELIVERY, "Wrong state");

        escrows[_escrowId].state = State.DISPUTED;
        emit Disputed(_escrowId, _evidenceUrl);
    }

    function decideDispute(uint256 _escrowId, uint256 sellerRefund, uint256 buyerRefund) external onlyArbiter(_escrowId){
        require(escrows[_escrowId].state == State.DISPUTED, "Wrong state");
        require(sellerRefund + buyerRefund == escrows[_escrowId].amount, "Wrong refund amount");

        if(buyerRefund > 0){
            escrows[_escrowId].state = State.REFUNDED;
            escrows[_escrowId].amount = escrows[_escrowId].amount - buyerRefund - sellerRefund;

            (bool sentSeller, ) = escrows[_escrowId].seller.call{value: sellerRefund}("");
            (bool sentBuyer, ) = escrows[_escrowId].buyer.call{value: buyerRefund}("");

            require(sentSeller && sentBuyer, "Failed to send Ether");
            require(escrows[_escrowId].amount == 0, "Wrong amount"); //Shouldn't be necessary but I'm not familiar with solidity enough to trust it
        }
        else
        {
            escrows[_escrowId].state = State.COMPLETE;
            uint256 payment = escrows[_escrowId].amount;
            escrows[_escrowId].amount = 0;

            (bool sent, ) = escrows[_escrowId].seller.call{value: payment}("");
            require(sent, "Failed to send Ether");
        }
        emit DisputeResolved(_escrowId, sellerRefund, buyerRefund);
    }

}
