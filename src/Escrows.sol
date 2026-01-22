// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./IEscrow.sol";

contract Escrows is IEscrow {
    uint256 private counter;
    mapping(uint256 => Escrow) public escrows;
    address public owner = address(0); // My potential address

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

    modifier onlyBuyerOrSeller(uint256 _id) {
        require(msg.sender == escrows[_id].buyer || msg.sender == escrows[_id].seller);
        _;
    }

    function createEscrow(address _buyer, address payable _seller, address _arbiter, uint256 _requestedAmount)
        external
        returns (uint256)
    {
        require(_buyer != address(0) && _seller != address(0) && _arbiter != address(0), "Invalid address");
        require(_seller == msg.sender, "Only seller can create escrow");

        uint256 escrowId = counter++;
        escrows[escrowId] = Escrow({
            buyer: _buyer,
            seller: _seller,
            arbiter: _arbiter,
            amount: 0,
            requestedAmount: _requestedAmount,
            state: State.AWAITING_PAYMENT,
            evidenceUrl: ""
        });

        emit EscrowCreated(escrowId, _buyer, _seller);
        return escrowId;
    }

    function deposit(uint256 _escrowId)
        external
        payable
        onlyBuyer(_escrowId)
        inState(_escrowId, State.AWAITING_PAYMENT)
    {
        require(msg.value > 0, "Deposit must be > 0");
        require(msg.value == escrows[_escrowId].requestedAmount, "Not enough value for this escrow");

        escrows[_escrowId].amount = msg.value;
        escrows[_escrowId].state = State.AWAITING_DELIVERY;

        emit Deposited(_escrowId, msg.value);
    }

    function markShipped(uint256 _escrowId) external onlySeller(_escrowId) inState(_escrowId, State.AWAITING_DELIVERY) {
        emit ItemShipped(_escrowId);
    }

    function confirmDelivery(uint256 _escrowId)
        external
        onlyBuyer(_escrowId)
        inState(_escrowId, State.AWAITING_DELIVERY)
    {
        escrows[_escrowId].state = State.COMPLETE;

        uint256 payment = escrows[_escrowId].amount;
        escrows[_escrowId].amount = 0;

        (bool sent,) = escrows[_escrowId].seller.call{value: payment}("");
        require(sent, "Failed to send Ether");

        emit Confirmed(_escrowId);
    }

    function disputeDelivery(uint256 _escrowId, string calldata _evidenceUrl)
        external
        onlyBuyerOrSeller(_escrowId)
        inState(_escrowId, State.AWAITING_DELIVERY)
    {
        escrows[_escrowId].state = State.DISPUTED;
        escrows[_escrowId].evidenceUrl = _evidenceUrl;
        emit Disputed(_escrowId, _evidenceUrl);
    }

    function decideDispute(uint256 _escrowId, uint256 sellerRefund, uint256 buyerRefund)
        external
        onlyArbiter(_escrowId)
        inState(_escrowId, State.DISPUTED)
    {
        require(sellerRefund + buyerRefund == escrows[_escrowId].amount, "Wrong refund amount");

        if (buyerRefund > 0) {
            escrows[_escrowId].state = State.REFUNDED;
            escrows[_escrowId].amount = escrows[_escrowId].amount - buyerRefund - sellerRefund;

            (bool sentSeller,) = escrows[_escrowId].seller.call{value: sellerRefund}("");
            (bool sentBuyer,) = escrows[_escrowId].buyer.call{value: buyerRefund}("");

            require(sentSeller && sentBuyer, "Failed to send Ether");
            require(escrows[_escrowId].amount == 0, "Wrong amount"); //Shouldn't be necessary but I'm not familiar with solidity enough to trust it
        } else {
            escrows[_escrowId].state = State.COMPLETE;
            uint256 payment = escrows[_escrowId].amount;
            escrows[_escrowId].amount = 0;

            (bool sent,) = escrows[_escrowId].seller.call{value: payment}("");
            require(sent, "Failed to send Ether");
        }
        emit DisputeResolved(_escrowId, sellerRefund, buyerRefund);
    }

    function cancelEscrow(uint256 _escrowId) external onlySeller(_escrowId) inState(_escrowId, State.AWAITING_PAYMENT) {
        escrows[_escrowId].state = State.CANCELED;

        emit Cancelled(_escrowId);
    }

    function checkEscrow(uint256 _escrowId) external view onlyBuyerOrSeller(_escrowId) returns (Escrow memory) {
        return escrows[_escrowId];
    }

    function getEvidence(uint256 _escrowId) external view inState(_escrowId, State.DISPUTED) returns (string memory) {
        return escrows[_escrowId].evidenceUrl;
    }

    function selfDestruct() external {
        require(msg.sender == owner, "Only owner can call this");
        selfdestruct(payable(owner));
    }
}
