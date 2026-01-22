// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/Escrows.sol";
import "../src/IEscrow.sol";

contract EscrowsTest is Test {
    Escrows public escrows;

    address public buyer = address(0x1);
    address payable public seller = payable(address(0x2));
    address public arbiter = address(0x3);

    uint256 public constant PRICE = 1 ether;

    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller);
    event Deposited(uint256 indexed escrowId, uint256 amount);
    event Disputed(uint256 indexed escrowId, string evidenceUrl);
    event Confirmed(uint256 indexed escrowId);

    function setUp() public {
        escrows = new Escrows();
        vm.deal(buyer, 10 ether);
    }

    function createEscrow() internal returns (uint256) {
        vm.prank(seller);
        return escrows.createEscrow(buyer, seller, arbiter, PRICE);
    }

    function test_CreateEscrow() public {
        vm.expectEmit(true, true, true, true);
        emit EscrowCreated(0, buyer, seller);

        uint256 id = createEscrow();

        (address _buyer, address _seller, address _arbiter, uint256 amount, uint256 req, IEscrow.State state,) =
            escrows.escrows(id);

        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(_arbiter, arbiter);
        assertEq(amount, 0);
        assertEq(req, PRICE);
        assertEq(uint256(state), uint256(IEscrow.State.AWAITING_PAYMENT));
    }

    function test_Deposit() public {
        uint256 id = createEscrow();

        vm.prank(buyer);
        vm.expectEmit(true, false, false, true);
        emit Deposited(id, PRICE);

        escrows.deposit{value: PRICE}(id);

        (,,, uint256 amount,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(amount, PRICE);
        assertEq(uint256(state), uint256(IEscrow.State.AWAITING_DELIVERY));
    }

    function test_HappyPath_Complete() public {
        uint256 id = createEscrow();

        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(seller);
        escrows.markShipped(id);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        vm.expectEmit(true, false, false, false);
        emit Confirmed(id);
        escrows.confirmDelivery(id);

        (,,,,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.COMPLETE));
        assertEq(seller.balance, sellerBalanceBefore + PRICE);
    }

    function test_Dispute_And_RefundBuyer() public {
        uint256 id = createEscrow();

        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        string memory url = "https://ipfs.io/ipfs/QmHash";
        vm.prank(buyer);
        vm.expectEmit(true, false, false, true);
        emit Disputed(id, url);
        escrows.disputeDelivery(id, url);

        assertEq(escrows.getEvidence(id), url);

        (,,,,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.DISPUTED));

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(arbiter);
        escrows.decideDispute(id, 0, PRICE); // 0 to seller, PRICE to buyer

        (,,,,, state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.REFUNDED));
        assertEq(buyer.balance, buyerBalanceBefore + PRICE);
    }

    function testRevert_DepositWrongAmount() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        vm.expectRevert("Not enough value for this escrow");
        escrows.deposit{value: 0.5 ether}(id);
    }

    function test_SellerCanDispute() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        string memory url = "https://ipfs.io/ipfs/QmSellerEvidence";

        vm.prank(seller);
        vm.expectEmit(true, false, false, true);
        emit Disputed(id, url);
        escrows.disputeDelivery(id, url);

        (,,,,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.DISPUTED));
    }

    function testRevert_ThirdPartyCannotDispute() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(arbiter);
        vm.expectRevert();
        escrows.disputeDelivery(id, "url");
    }

    function testRevert_CannotDisputeBeforeDeposit() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        vm.expectRevert("Wrong state");
        escrows.disputeDelivery(id, "url");
    }

    function testRevert_DecideDispute_WrongAmount() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(buyer);
        escrows.disputeDelivery(id, "evidence");

        vm.prank(arbiter);
        vm.expectRevert("Wrong refund amount");
        escrows.decideDispute(id, 0.5 ether, 0.1 ether);
    }

    function test_Dispute_SellerWins() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(buyer);
        escrows.disputeDelivery(id, "evidence");

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(arbiter);
        escrows.decideDispute(id, PRICE, 0);

        (,,,,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.COMPLETE));
        assertEq(seller.balance, sellerBalanceBefore + PRICE);
    }

    function test_Dispute_SplitRefund() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(buyer);
        escrows.disputeDelivery(id, "evidence");

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(arbiter);
        escrows.decideDispute(id, PRICE / 2, PRICE / 2);

        (,,,,, IEscrow.State state,) = escrows.escrows(id);
        assertEq(uint256(state), uint256(IEscrow.State.REFUNDED));
        assertEq(seller.balance, sellerBalanceBefore + PRICE / 2);
        assertEq(buyer.balance, buyerBalanceBefore + PRICE / 2);
    }

    function testRevert_DecideDispute_OnlyArbiter() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);
        vm.prank(buyer);
        escrows.disputeDelivery(id, "evidence");

        vm.prank(buyer);
        vm.expectRevert("Only arbiter can call this");
        escrows.decideDispute(id, PRICE, 0);
    }

    function testRevert_DecideDispute_WrongState() public {
        uint256 id = createEscrow();
        vm.prank(buyer);
        escrows.deposit{value: PRICE}(id);

        vm.prank(arbiter);
        vm.expectRevert("Wrong state");
        escrows.decideDispute(id, PRICE, 0);
    }
}
