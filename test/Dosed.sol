// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Dosed.sol";

contract DosedTest is Test {
    Dosed public dosed;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    RevertingReceiver public receiver;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        user4 = address(0x4);
        receiver = new RevertingReceiver();
        
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(address(receiver), 10 ether);
        
        dosed = new Dosed{value: 0 ether}();
    }

    function testInitialState() public {
        assertEq(dosed.dosed(), false);
        assertEq(address(dosed).balance, 0);
        assertEq(dosed.balanceOf(user1), 0);
    }

    function testDeposit() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(user1), 0.5 ether);
        assertEq(address(dosed).balance, 0.5 ether);
    }

    function testDepositInvalidAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("InvalidAmount");
        dosed.deposit{value: 0.3 ether}();
        vm.stopPrank();
    }

    function testDepositLocked() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user2);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user3);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user4);
        vm.expectRevert("deposit locked");
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        dosed.withdraw();
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(user1), 0);
        assertEq(address(dosed).balance, 0);
    }

    function testWithdrawZeroBalance() public {
        vm.startPrank(user1);
        vm.expectRevert();
        dosed.withdraw();
        vm.stopPrank();
    }

    function testDosedTrigger() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user2);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user3);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        address payable contractAddress = payable(address(dosed));
        DummyContract dummy = new DummyContract();
        dummy.sendEther{value: 18.5 ether}(contractAddress);
        
        vm.startPrank(user3);
        dosed.withdraw();
        vm.stopPrank();
        
        assertTrue(dosed.dosed());
        assertEq(dosed.balanceOf(user3), 0.5 ether);
    }

    function testDestWhenDosed() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user2);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.startPrank(user3);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        address payable contractAddress = payable(address(dosed));
        DummyContract dummy = new DummyContract();
        dummy.sendEther{value: 18.5 ether}(contractAddress);
        
        vm.startPrank(user3);
        dosed.withdraw();
        vm.stopPrank();
        
        dosed.dest();
    }

    function testMaxDepositExceeded() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        dosed.deposit{value: 0.5 ether}();
        vm.expectRevert("Max deposit exceeded");
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
    }

    function testWithdrawTransferFailure() public {
        vm.startPrank(address(receiver));
        dosed.deposit{value: 0.5 ether}();
        vm.expectRevert();
        dosed.withdraw(); // Reverts due to receiver rejecting ETH
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(address(receiver)), 0.5 ether); // Balance unchanged
        assertEq(address(dosed).balance, 0.5 ether); // Funds stay in contract
    }

    function testDestWhenNotDosed() public {
        vm.startPrank(user1);
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.expectRevert("Not dosed");
        dosed.dest();
    }
}

contract RevertingReceiver {
    receive() external payable {
        revert("No ETH accepted");
    }
}

contract DummyContract {
    constructor() payable {}
    
    function sendEther(address payable target) external payable {
        selfdestruct(target);
    }
}