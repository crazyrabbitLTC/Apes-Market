# Security Audit Report - Apes Market

## Executive Summary

This security audit report covers the Apes Market Solidity codebase. The audit identified several critical, high, medium, and low severity issues that should be addressed before deployment to mainnet.

## Audit Scope

The following contracts were reviewed:
- `ApesMarket.sol` - Main marketplace contract
- `ApeGovernorAlpha.sol` - Governance contract
- `ApeToken.sol` - ERC20 token implementation
- `ApeGovModule.sol` - Governance module
- `ApeHelper.sol` - Helper contract
- Mock contracts (for testing purposes)

## Critical Severity Issues

### 1. Incorrect Arithmetic Operations in ApesMarket.sol

**Location**: `ApesMarket.sol` lines 294-296

**Issue**: The reward calculation logic has several bugs:
```solidity
apeDistributed.add(amount); // Result not stored
apeRewardRatio.add(1); // Result not stored
```

**Impact**: The `apeDistributed` and `apeRewardRatio` variables are never updated because SafeMath operations return a new value rather than modifying the original. This breaks the entire reward distribution mechanism.

**Recommendation**: 
```solidity
apeDistributed = apeDistributed.add(amount);
apeRewardRatio = apeRewardRatio.add(1);
```

### 2. Reentrancy Vulnerability in executeTransaction

**Location**: `ApesMarket.sol` line 281-291

**Issue**: The `executeTransaction` function makes an external call without following checks-effects-interactions pattern and doesn't use the `nonReentrant` modifier.

**Impact**: Malicious contracts could potentially re-enter and drain funds or manipulate state.

**Recommendation**: Add `nonReentrant` modifier to the function.

### 3. Missing License Identifier

**Location**: `contracts/mocks/MockToken.sol` line 1

**Issue**: Missing SPDX license identifier will cause compilation warnings/errors in Solidity 0.7.0.

**Recommendation**: Add `// SPDX-License-Identifier: MIT` at the beginning of the file.

## High Severity Issues

### 1. Centralization Risk in ApesMarket

**Location**: `ApesMarket.sol` constructor and role setup

**Issue**: The CREATOR_ROLE has significant privileges including:
- Setting up the market (one-time)
- Receiving 2.5% of tokens (250 tokens out of 10,000)

**Impact**: While setup can only be done once, the initial creator has significant control.

**Recommendation**: Consider implementing a multi-sig or DAO-controlled setup process.

### 2. Incorrect Token Minting in ApeToken

**Location**: `ApeToken.sol` line 11

**Issue**: The token mints only 10,000 units without considering decimals:
```solidity
_mint(recipient, 10000);
```

**Impact**: If the token has 18 decimals (standard), only 0.00000000000001 tokens are minted, making the token essentially worthless.

**Recommendation**: 
```solidity
_mint(recipient, 10000 * 10**18); // or 10000e18
```

### 3. Hardcoded Console Import in Production

**Location**: Multiple files including `ApesMarket.sol`, `Greeter.sol`, `MockToken.sol`

**Issue**: Hardhat console import (`import "hardhat/console.sol"`) is included in production contracts.

**Impact**: This will cause deployment failures on mainnet and increases gas costs.

**Recommendation**: Remove all console imports and console.log statements before deployment.

## Medium Severity Issues

### 1. Incorrect Payment Distribution

**Location**: `ApesMarket.sol` line 252

**Issue**: The comment says "Split half the tokens with msg.sender" but the payer field is used incorrectly:
```solidity
allApesByIndex[id].value, // This should be paymentAmount
allApesByIndex[id].payer  // This is logged as payment amount
```

**Impact**: Event emission has incorrect values which could confuse off-chain monitoring.

**Recommendation**: Fix the event parameters to match the actual values.

### 2. Gas Measurement Inaccuracy

**Location**: `ApesMarket.sol` line 211

**Issue**: Gas measurement includes the entire function execution, not just the deployment:
```solidity
allApesByIndex[id].gasUsed = startGas.sub(gasleft());
```

**Impact**: The recorded gas usage will be inflated and inaccurate.

**Recommendation**: Measure gas only around the Create2 deployment call.

### 3. Weak Access Control in Governance

**Location**: `ApeGovernorAlpha.sol` guardian functions

**Issue**: The guardian has significant powers including:
- Canceling proposals
- Setting timelock admin
- Accepting admin role

**Impact**: Single point of failure if guardian key is compromised.

**Recommendation**: Implement time delays or multi-sig requirements for guardian actions.

## Low Severity Issues

### 1. Inefficient Storage Access

**Location**: `ApesMarket.sol` multiple locations

**Issue**: The contract repeatedly accesses `allApesByIndex[id]` from storage instead of caching it in memory.

**Impact**: Higher gas costs for users.

**Recommendation**: Cache the struct in memory at the beginning of functions.

### 2. Missing Input Validation

**Location**: Multiple contracts

**Issue**: Several functions lack input validation:
- No zero address checks in constructors
- No validation of array lengths in some functions
- No validation of numerical inputs

**Impact**: Could lead to unexpected behavior or wasted gas.

**Recommendation**: Add comprehensive input validation.

### 3. Outdated Solidity Version

**Location**: All contracts

**Issue**: Using Solidity 0.7.0 which is outdated.

**Impact**: Missing important security features and optimizations from newer versions.

**Recommendation**: Upgrade to Solidity 0.8.x for built-in overflow protection and other improvements.

### 4. Inconsistent Error Messages

**Location**: Throughout the codebase

**Issue**: Error messages have inconsistent formatting and some are missing.

**Impact**: Harder to debug and monitor.

**Recommendation**: Standardize error message format.

## Informational Issues

### 1. Unused Imports

**Location**: Various contracts

**Issue**: Some imports are not used (e.g., `Counters` might not be needed if using simple increment).

**Recommendation**: Remove unused imports to reduce contract size.

### 2. Magic Numbers

**Location**: Multiple locations

**Issue**: Hard-coded values like `250e18`, `25`, `2`, etc.

**Recommendation**: Define as named constants for better readability.

### 3. Missing Events

**Location**: `ApeHelper.sol` and others

**Issue**: Some state changes don't emit events.

**Recommendation**: Emit events for all significant state changes.

### 4. Incomplete NatSpec Documentation

**Location**: Most contracts

**Issue**: Functions lack proper NatSpec documentation.

**Recommendation**: Add comprehensive documentation for all public/external functions.

## Best Practice Recommendations

1. **Implement Circuit Breakers**: Add pause functionality for emergency situations.

2. **Add Upgrade Mechanism**: Consider using proxy patterns for upgradeability.

3. **Formal Verification**: Consider formal verification for critical functions.

4. **Gas Optimization**: Several areas could be optimized for gas usage:
   - Pack struct variables efficiently
   - Use `calldata` instead of `memory` where possible
   - Cache array lengths in loops

5. **Testing**: Ensure comprehensive test coverage including:
   - Edge cases
   - Reentrancy tests
   - Access control tests
   - Integration tests

## Conclusion

The codebase contains several critical issues that must be addressed before deployment. The most severe issues are:

1. Broken arithmetic operations in reward calculations
2. Incorrect token minting amounts
3. Reentrancy vulnerabilities
4. Production code containing debug imports

Additionally, the codebase would benefit from:
- Upgrading to Solidity 0.8.x
- Implementing comprehensive input validation
- Adding proper documentation
- Improving test coverage

It is strongly recommended to fix all critical and high severity issues, and carefully consider the medium and low severity issues before deploying to mainnet.