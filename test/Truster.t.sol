// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {DamnValuableToken, TrusterLenderPool, Target} from "../src/Truster.sol";

/**
 * @title Truster Vulnerability Demonstration
 * @notice Demonstrates the exploitation of the flash loan mechanism in the TrusterLenderPool contract
 *
 * @dev The vulnerability exists because:
 * - The `flashLoan` function allows executing arbitrary functions on any contract with data provided by the borrower.
 * - This can be used to manipulate contract states or interact with other contracts during the flash loan execution.
 *
 * Attack flow:
 * 1. Attacker contract (e.g., `Target`) calls `flashLoan`, specifying the token contract (`token`) as the target.
 * 2. The call data includes a command to `approve` a large amount of tokens on behalf of `TrusterLenderPool` to the attacker’s address.
 * 3. After the `flashLoan` execution, the attacker can use `transferFrom` to move the approved tokens to their address, effectively "stealing" the tokens.
 */
contract TrusterTest is Test {
    DamnValuableToken public token;
    TrusterLenderPool public pool;
    Target public target;

    uint256 private constant POOL_BALANCE = 1_000_000e18;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        target = new Target(pool, address(token));

        token.transfer(address(pool), POOL_BALANCE);
    }

    function testFlashLoan() public {
        target.getFlashLoan();

        uint256 balance = token.balanceOf(address(target));
        assertEq(balance, POOL_BALANCE);
    }
}
