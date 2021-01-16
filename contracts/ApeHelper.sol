// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract ApeHelper {
using SafeERC20 for IERC20;

    event ApePaid(address token, address recipient, uint256 value);

    constructor(IERC20 _token, address _recipient, uint256 _value){
        IERC20 token = IERC20(_token);
        token.safeTransfer(_recipient, _value);
        emit ApePaid(address(token), _recipient, _value);
    }
}