// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool, Attacker} from "../src/SideEntrance.sol";

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
