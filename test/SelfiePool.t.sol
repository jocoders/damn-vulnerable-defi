// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SelfiePool, SelfiePoolAttacker} from "../src/SelfiePool.sol";
import {SimpleGovernance} from "../src/SimpleGovernance.sol";
import {DamnValuableVotes} from "../src/DamnValuableVotes.sol";

import {Test, console} from "forge-std/Test.sol";

contract SelfiePoolTest is Test {
    SelfiePool public selfiePool;
    SimpleGovernance public simpleGovernance;
    DamnValuableVotes public damnValuableVotes;
    SelfiePoolAttacker public selfiePoolAttacker;

    address zeroAddress = address(0x0000000000000000000000000000000000000000);

    uint256 public constant SUPPLY = 1_500_000e18;

    function setUp() public {
        damnValuableVotes = new DamnValuableVotes(SUPPLY);
        simpleGovernance = new SimpleGovernance(damnValuableVotes);
        selfiePool = new SelfiePool(damnValuableVotes, simpleGovernance);

        damnValuableVotes.delegate(address(this));

        damnValuableVotes.delegate(address(selfiePool));
        damnValuableVotes.transfer(address(selfiePool), SUPPLY);

        vm.startPrank(address(selfiePool));
        damnValuableVotes.delegate(address(selfiePool));
        vm.stopPrank();

        assertEq(damnValuableVotes.balanceOf(address(selfiePool)), SUPPLY);
        selfiePoolAttacker = new SelfiePoolAttacker{value: 1 ether}(selfiePool, simpleGovernance, damnValuableVotes);
        assertEq(address(selfiePoolAttacker).balance, 1 ether);
    }

    function testflashLoan() public {
        selfiePoolAttacker.getFlashLoan();

        vm.warp(block.timestamp + 3 days);
        selfiePoolAttacker.executeAction();

        uint256 balance = damnValuableVotes.balanceOf(address(selfiePoolAttacker));
        assertEq(balance, SUPPLY, "Balance of attacker is not equal to supply");
    }
}
