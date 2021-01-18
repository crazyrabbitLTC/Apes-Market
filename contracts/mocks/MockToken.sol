pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract MOCKTOKEN is ERC20 {
    constructor() ERC20("Fixed", "FIX") {
        console.log("Message sender: ", msg.sender);
        _mint(msg.sender, 10000e18);
    }
}