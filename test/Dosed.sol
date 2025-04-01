// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Dosed.sol";

contract DosedTest is Test {
    Dosed public dosed;
    address public owner;
    UserContract public user1; // Using a contract as user1 to handle reverting receiver case

    function setUp() public {
        owner = address(this);
        user1 = new UserContract();
        
        vm.deal(address(user1), 10 ether);
        
        dosed = new Dosed{value: 0 ether}();
    }

    function testInitialState() public {
        assertEq(dosed.dosed(), false);
        assertEq(address(dosed).balance, 0);
        assertEq(dosed.balanceOf(address(user1)), 0);
    }

    function testDeposit() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(address(user1)), 0.5 ether);
        assertEq(address(dosed).balance, 0.5 ether);
    }

    function testDepositInvalidAmount() public {
        vm.startPrank(address(user1));
        vm.expectRevert("InvalidAmount");
        dosed.deposit{value: 0.3 ether}();
        vm.stopPrank();
    }

    function testDepositLocked() public {
        // Use forced ETH to reach 2 ether limit with one user
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        address payable contractAddress = payable(address(dosed));
        DummyContract dummy = new DummyContract();
        dummy.sendEther{value: 1.5 ether}(contractAddress); // Total: 2 ether
        
        vm.startPrank(address(user1));
        vm.expectRevert("deposit locked");
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        user1.setReverts(false); // Ensure it accepts ETH
        dosed.withdraw();
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(address(user1)), 0);
        assertEq(address(dosed).balance, 0);
    }

    function testWithdrawZeroBalance() public {
        vm.startPrank(address(user1));
        vm.expectRevert();
        dosed.withdraw();
        vm.stopPrank();
    }

    function testDosedTrigger() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        address payable contractAddress = payable(address(dosed));
        DummyContract dummy = new DummyContract();
        dummy.sendEther{value: 19.5 ether}(contractAddress); // Total: 20 ether
        
        vm.startPrank(address(user1));
        user1.setReverts(false); // Ensure it accepts ETH (though not needed here)
        dosed.withdraw();
        vm.stopPrank();
        
        assertTrue(dosed.dosed());
        assertEq(dosed.balanceOf(address(user1)), 0.5 ether);
    }

    function testDestWhenDosed() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        address payable contractAddress = payable(address(dosed));
        DummyContract dummy = new DummyContract();
        dummy.sendEther{value: 19.5 ether}(contractAddress); // Total: 20 ether
        
        vm.startPrank(address(user1));
        dosed.withdraw();
        vm.stopPrank();
        
        dosed.dest();
    }

    function testMaxDepositExceeded() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        dosed.deposit{value: 0.5 ether}(); // balanceOf[user1] = 1 ether
        vm.expectRevert("Max deposit exceeded");
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
    }

    function testWithdrawTransferFailure() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        user1.setReverts(true); // Make it reject ETH
        vm.expectRevert();
        dosed.withdraw();
        vm.stopPrank();
        
        assertEq(dosed.balanceOf(address(user1)), 0.5 ether); // Balance unchanged
        assertEq(address(dosed).balance, 0.5 ether);
    }

    function testDestWhenNotDosed() public {
        vm.startPrank(address(user1));
        dosed.deposit{value: 0.5 ether}();
        vm.stopPrank();
        
        vm.expectRevert("Not dosed");
        dosed.dest();
    }
}

// User contract that can toggle reverting on ETH receipt
contract UserContract {
    bool public reverts;

    function setReverts(bool _reverts) external {
        reverts = _reverts;
    }

    receive() external payable {
        if (reverts) {
            revert("No ETH accepted");
        }
    }
}

contract DummyContract {
    constructor() payable {}
    
    function sendEther(address payable target) external payable {
        selfdestruct(target);
    }
}