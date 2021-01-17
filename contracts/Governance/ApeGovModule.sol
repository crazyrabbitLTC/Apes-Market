// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/TimelockController.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../Governance/ApeToken.sol";

contract ApeGovModule is AccessControl {
    using Address for address;

    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    // 16 hours delay
    // It should be updated to a much longer time after. 
    uint256 public constant delay = 3840;

    // Address of the Ape Token
    ApeToken public ape;

    // Address of the timelock
    TimelockController public timelock;

    // Event emitted when a transaction is executed
    event ExecuteTransaction(address indexed target, uint256 value, bytes data);

    constructor(address[] memory proposersAndExecutors) {
        ape = new ApeToken(address(this));
        timelock = new TimelockController(delay, proposersAndExecutors, proposersAndExecutors);

        // Set Timelock Role
        _setupRole(TIMELOCK_ROLE, address(timelock));


        // Set Roles Admin
        _setRoleAdmin(TIMELOCK_ROLE, TIMELOCK_ROLE);

    }

    function executeTransaction(
        address target,
        bytes memory data,
        uint256 value
    ) external payable returns (bytes memory) {
        require(hasRole(TIMELOCK_ROLE, msg.sender), "Caller does not have timelock Role");

        bytes memory returnData =
            target.functionCallWithValue(data, value, "ApeExecute::Error: Unable to execute transaction");

        emit ExecuteTransaction(target, value, data);
        return returnData;
    }
}
