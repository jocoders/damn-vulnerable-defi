// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";
// import {NaiveReceiverPool} from "../src/NaiveReceiverPool.sol";
// import {WETH} from "@solmate/src/tokens/WETH.sol";
// import {BasicForwarder} from "../src/BasicForwarder.sol";
// import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";

// contract NaiveReceive is Test {
//     WETH public weth;
//     NaiveReceiverPool public pool;
//     FlashLoanReceiver public receiver;
//     BasicForwarder public forwarder;

//     address feeReceiver = makeAddr("feeReceiver");
//     mapping(address => uint256) public nonces;

//     function setUp() public {
//         weth = new WETH();
//         forwarder = new BasicForwarder();
//         pool = new NaiveReceiverPool{value: 1000 ether}(address(forwarder), payable(address(weth)), feeReceiver);
//         receiver = new FlashLoanReceiver(address(pool));

//         uint256 ethBalance = address(weth).balance;
//         uint256 wethBalance = weth.balanceOf(address(pool));

//         assertEq(ethBalance, 1000 ether, "ethBalance should be 1000 ether");
//         assertEq(wethBalance, 1000 ether, "wethBalance should be 1000 ether");

//         weth.deposit{value: 10 ether}();
//         weth.transfer(address(receiver), 10 ether);

//         uint256 receiverWethBalance = weth.balanceOf(address(receiver));
//         assertEq(receiverWethBalance, 10 ether, "receiverWethBalance should be 10 ether");
//     }

//     function testFlashLoan() public {
//         address token = address(weth);
//         uint256 amount = 100 ether;
//         bytes memory data = "";

//         initiateFlashLoan(address(forwarder), address(pool), token, amount, data);
//     }

//     function initiateFlashLoan(address forwarder, address pool, address token, uint256 amount, bytes memory data)
//         internal
//     {
//         uint256 currentNonce = nonces[msg.sender];
//         BasicForwarder.Request memory request = BasicForwarder.Request({
//             from: msg.sender,
//             target: pool,
//             value: 1,
//             gas: 100000,
//             nonce: currentNonce,
//             data: abi.encodeWithSelector(
//                 NaiveReceiverPool.flashLoan.selector, IERC3156FlashBorrower(msg.sender), token, amount, data
//             ),
//             deadline: block.timestamp + 1 days
//         });
//         bytes memory signature = signRequest(request);
//         BasicForwarder(forwarder).execute(request, signature);
//         nonces[msg.sender] = currentNonce + 1;
//     }
// }
