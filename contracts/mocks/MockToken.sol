// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MOCKTOKEN is ERC20 {
    constructor() ERC20("Fixed", "FIX") {
        _mint(msg.sender, 10000e18);
    }
}