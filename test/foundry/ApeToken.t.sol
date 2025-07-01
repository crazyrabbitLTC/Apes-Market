// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../contracts/Governance/ApeToken.sol";

contract ApeTokenTest is Test {
    ApeToken public token;
    address public recipient = address(0x1234);
    
    function setUp() public {
        token = new ApeToken(recipient);
    }
    
    function testIncorrectTokenMinting() public {
        // Check total supply
        uint256 totalSupply = token.totalSupply();
        
        // This test will FAIL - expecting 10,000 tokens with 18 decimals
        // But contract only mints 10,000 units (0.00000000000001 tokens)
        assertEq(totalSupply, 10000e18, "Should mint 10,000 tokens with 18 decimals");
        
        // Check recipient balance
        uint256 recipientBalance = token.balanceOf(recipient);
        assertEq(recipientBalance, 10000e18, "Recipient should have 10,000 tokens");
        
        // Show the actual minted amount (will be 10000 without decimals)
        emit log_named_uint("Actual total supply", totalSupply);
        emit log_named_uint("Expected total supply", 10000e18);
    }
    
    function testTokenDecimals() public {
        // Verify token has standard 18 decimals
        uint8 decimals = token.decimals();
        assertEq(uint256(decimals), 18, "Token should have 18 decimals");
    }
}