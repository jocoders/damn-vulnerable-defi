pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UnstoppableVault} from "../src/UnstoppableVault.sol";
import {UnstoppableMonitor} from "../src/UnstoppableMonitor.sol";
import {ERC20} from "@solmate/src/tokens/ERC4626.sol";

contract DVTToken is ERC20 {
    constructor(address owner, uint256 initialSupply) ERC20("Too Damn Valuable Token", "DVT", 18) {
        _mint(owner, initialSupply);
    }
}

contract SetupContract {
    UnstoppableVault public vault;
    UnstoppableMonitor public monitor;

    uint256 public constant DVT_INITIAL_SUPPLY = 1_000_000e18;
    DVTToken public dvt;

    address public OWNER = address(this);
    address public FEE_RECIPIENT;

    function setUp(address owner, address feeRecipient) public {
        OWNER = owner;
        FEE_RECIPIENT = feeRecipient;

        dvt = new DVTToken(OWNER, DVT_INITIAL_SUPPLY);
        vault = new UnstoppableVault(dvt, OWNER, FEE_RECIPIENT);
        monitor = new UnstoppableMonitor(address(vault));

        dvt.approve(address(vault), DVT_INITIAL_SUPPLY - 10e18);
        vault.deposit(DVT_INITIAL_SUPPLY - 10e18, OWNER);

        uint256 balance = dvt.balanceOf(address(this));
        uint256 balanceVault = dvt.balanceOf(address(vault));

        // console.log('BALANCE_AFTER_TRANSFER', balance);
        // console.log('BALANCE_VAULT', balanceVault);

        assert(balance == 10e18);
        assert(balanceVault == DVT_INITIAL_SUPPLY - 10e18);
    }

    function testCheckFlashLoan(uint256 amount, uint256 amountDeposit) public {
        //require(amount <= 10e18, 'Amount must be less than 10 DVT');

        dvt.approve(address(vault), amountDeposit);
        vault.deposit(amountDeposit, address(this));

        monitor.checkFlashLoan(amount);

        bool paused = vault.paused();
        assert(paused == true);
    }
}
