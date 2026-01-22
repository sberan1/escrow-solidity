// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IEscrow {
    enum State {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        DISPUTED,
        REFUNDED,
        CANCELED
    }

    struct Escrow {
        address buyer;
        address payable seller;
        address arbiter;
        uint256 amount;
        uint256 requestedAmount;
        State state;
        string evidenceUrl;
    }

    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller);
    event Deposited(uint256 indexed escrowId, uint256 amount);
    event ItemShipped(uint256 indexed escrowId);
    event Confirmed(uint256 indexed escrowId);
    event DisputeResolved(uint256 indexed escrowId, uint256 sellerRefund, uint256 buyerRefund);
    event Disputed(uint256 indexed escrowId, string evidenceUrl);
    event Cancelled(uint256 indexed escrowId);

    function createEscrow(address _buyer, address payable _seller, address _arbiter, uint256 _requestedAmount)
        external
        returns (uint256);
    function deposit(uint256 _escrowId) external payable;
    function checkEscrow(uint256 _escrowId) external view returns (Escrow memory);
    function markShipped(uint256 _escrowId) external;
    function confirmDelivery(uint256 _escrowId) external;
    function disputeDelivery(uint256 _escrowId, string calldata _evidenceUrl) external;
    function decideDispute(uint256 _escrowId, uint256 sellerRefund, uint256 buyerRefund) external;
    function getEvidence(uint256 _escrowId) external view returns (string memory);
    function cancelEscrow(uint256 _escrowId) external;
}
