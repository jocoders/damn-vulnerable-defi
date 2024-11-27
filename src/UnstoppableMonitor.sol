// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC3156FlashBorrower } from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import { Owned } from '@solmate/src/auth/Owned.sol';
import { UnstoppableVault, ERC20 } from './UnstoppableVault.sol';
import { Test, console } from 'forge-std/Test.sol';
import { ERC4626 } from '@solmate/src/tokens/ERC4626.sol';

/**
 * @notice Permissioned contract for on-chain monitoring of the vault's flashloan feature.
 */
contract UnstoppableMonitor is Owned, IERC3156FlashBorrower {
  UnstoppableVault private immutable vault;

  error UnexpectedFlashLoan();

  event FlashLoanStatus(bool success);

  constructor(address _vault) Owned(msg.sender) {
    vault = UnstoppableVault(_vault);
  }

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata
  ) external returns (bytes32) {
    if (initiator != address(this) || msg.sender != address(vault) || token != address(vault.asset()) || fee != 0) {
      revert UnexpectedFlashLoan();
    }

    ERC20(token).approve(address(vault), amount);

    return keccak256('IERC3156FlashBorrower.onFlashLoan');
  }

  function checkFlashLoan(uint256 amount) external onlyOwner {
    require(amount > 0);
    address asset = address(vault.asset());

    try vault.flashLoan(this, asset, amount, bytes('')) {
      emit FlashLoanStatus(true);
    } catch {
      console.log('1_PAUSED_CONTRACT!!!');
      emit FlashLoanStatus(false);
      vault.setPause(true);
      vault.transferOwnership(owner);
    }
  }
}
