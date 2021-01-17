// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";

contract ApeToken is ERC20Snapshot {

    constructor(
        address recipient
    ) ERC20("APE Token", "APE") {
        _mint(recipient, 10000);
    }

}