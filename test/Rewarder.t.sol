// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Claim} from "../src/Rewarder.sol";

import {TheRewarderDistributor} from "../src/Rewarder.sol";
import {Merkle} from "../src/Merkle.sol";

contract RewardToken is ERC20, Ownable2Step, ERC20Burnable {
    constructor() ERC20("RewardToken", "RTK") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract RewarderTest is Test {
    TheRewarderDistributor public rewarder;
    RewardToken public rewardToken1;
    RewardToken public rewardToken2;

    Merkle public merkle;

    bytes32 public merkleRoot;
    bytes32[] public leaves;

    uint256 private constant TOKEN_SUPPLY = 1000e18;
    uint256 private constant REWARD_BALANCE = 100e18;
    uint256 private constant REWARD_AMOUNT = 10e18;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address jo = makeAddr("jo");

    function setUp() public {
        rewarder = new TheRewarderDistributor();
        rewardToken1 = new RewardToken();
        rewardToken2 = new RewardToken();

        rewardToken1.mint(address(this), TOKEN_SUPPLY);
        rewardToken2.mint(address(this), TOKEN_SUPPLY);

        uint256 rewarderBalance1 = rewardToken1.balanceOf(address(this));
        uint256 rewarderBalance2 = rewardToken2.balanceOf(address(this));

        assertEq(rewarderBalance1, TOKEN_SUPPLY, "This should have the full amount of rewardToken1");
        assertEq(rewarderBalance2, TOKEN_SUPPLY, "This should have the full amount of rewardToken2");

        merkle = new Merkle();
        leaves = new bytes32[](3);
        leaves[0] = keccak256(abi.encodePacked(alice, REWARD_AMOUNT));
        leaves[1] = keccak256(abi.encodePacked(bob, REWARD_AMOUNT));
        leaves[2] = keccak256(abi.encodePacked(jo, REWARD_AMOUNT));

        merkleRoot = merkle.getRoot(leaves);

        rewardToken1.approve(address(rewarder), REWARD_BALANCE);
        rewardToken2.approve(address(rewarder), REWARD_BALANCE);

        rewarder.createDistribution(rewardToken1, merkleRoot, REWARD_BALANCE);
        rewarder.createDistribution(rewardToken2, merkleRoot, REWARD_BALANCE);
    }

    function testClaim() public {
        aliceClaim();

        bytes32[] memory proofBob = merkle.getProof(leaves, 1);

        IERC20[] memory tokens = getListOfTokens1(8, address(rewardToken1));
        Claim[] memory claims = getClaims(0, REWARD_AMOUNT, 0, proofBob, 8);

        vm.startPrank(bob);
        rewarder.claimRewards(claims, tokens);
        vm.stopPrank();

        uint256 afterBobBalance1 = rewardToken1.balanceOf(bob);

        assertEq(afterBobBalance1, REWARD_AMOUNT * 8, "Bob should have 80 ether of rewardToken1");

        IERC20[] memory tokens1 = getListOfTokens1(10, address(rewardToken2));
        Claim[] memory claims1 = getClaims(0, REWARD_AMOUNT, 0, proofBob, 10);

        vm.startPrank(bob);
        rewarder.claimRewards(claims1, tokens1);
        vm.stopPrank();

        uint256 afterBobBalance2 = rewardToken2.balanceOf(bob);
        assertEq(afterBobBalance2, REWARD_AMOUNT * 10, "Bob should have 0 ether of rewardToken2");
    }

    function aliceClaim() private {
        bytes32[] memory proofAlice = merkle.getProof(leaves, 0);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(address(rewardToken1));
        tokens[1] = IERC20(address(rewardToken2));

        Claim[] memory claims = getClaims(0, REWARD_AMOUNT, 0, proofAlice, 2);

        vm.startPrank(alice);
        rewarder.claimRewards(claims, tokens);
        vm.stopPrank();

        uint256 afterAliceBalance1 = rewardToken1.balanceOf(alice);
        uint256 afterAliceBalance2 = rewardToken2.balanceOf(alice);

        assertEq(afterAliceBalance1, REWARD_AMOUNT * 2, "Alice should have 20 ether of rewardToken1");
        assertEq(afterAliceBalance2, 0, "Alice should have 0 ether of rewardToken2");
    }

    function getListOfTokens1(uint256 _length, address _token) internal returns (IERC20[] memory tokens) {
        tokens = new IERC20[](_length);

        for (uint256 i = 0; i < _length; i++) {
            tokens[i] = IERC20(_token);
        }
    }

    function getClaims(
        uint256 _batchNumber,
        uint256 _amount,
        uint256 _tokenIndex,
        bytes32[] memory _proof,
        uint256 length
    ) internal returns (Claim[] memory inputClaims) {
        inputClaims = new Claim[](length);

        for (uint256 i = 0; i < length; i++) {
            inputClaims[i] = getClaim(_batchNumber, _amount, _tokenIndex, _proof);
        }
    }

    function getClaim(uint256 _batchNumber, uint256 _amount, uint256 _tokenIndex, bytes32[] memory _proof)
        internal
        returns (Claim memory claim)
    {
        claim.batchNumber = _batchNumber;
        claim.amount = _amount;
        claim.tokenIndex = _tokenIndex;
        claim.proof = _proof;
    }
}
