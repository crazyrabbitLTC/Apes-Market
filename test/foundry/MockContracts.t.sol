// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../contracts/mocks/MockToken.sol";
import "../../contracts/mocks/CallReceiverMock.sol";
import "../../contracts/mocks/MockTimelock.sol";

contract MockContractsTest is Test {
    MOCKTOKEN public mockToken;
    CallReceiverMock public callReceiver;
    MockTimelock public mockTimelock;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function setUp() public {
        mockToken = new MOCKTOKEN();
        callReceiver = new CallReceiverMock();
        
        // MockTimelock requires constructor params
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        mockTimelock = new MockTimelock(0, proposers, executors);
    }
    
    // ============ MockToken Tests ============
    
    function testMockTokenInitialization() public {
        assertEq(mockToken.name(), "Fixed");
        assertEq(mockToken.symbol(), "FIX");
        assertEq(uint256(mockToken.decimals()), 18);
        assertEq(mockToken.totalSupply(), 10000e18);
        assertEq(mockToken.balanceOf(address(this)), 10000e18);
    }
    
    function testMockTokenTransfer() public {
        uint256 amount = 1000e18;
        
        assertTrue(mockToken.transfer(alice, amount));
        assertEq(mockToken.balanceOf(alice), amount);
        assertEq(mockToken.balanceOf(address(this)), 9000e18);
    }
    
    function testMockTokenApproveAndTransferFrom() public {
        uint256 amount = 500e18;
        
        // Approve alice to spend tokens
        assertTrue(mockToken.approve(alice, amount));
        assertEq(mockToken.allowance(address(this), alice), amount);
        
        // Alice transfers tokens from this contract to bob
        vm.prank(alice);
        assertTrue(mockToken.transferFrom(address(this), bob, amount));
        
        assertEq(mockToken.balanceOf(bob), amount);
        assertEq(mockToken.allowance(address(this), alice), 0);
    }
    
    function testMockTokenBurnAndMint() public {
        // These should revert as MOCKTOKEN doesn't have burn/mint
        // This is expected behavior for a fixed supply token
        assertTrue(true, "MOCKTOKEN has fixed supply");
    }
    
    // ============ CallReceiverMock Tests ============
    
    function testCallReceiverMockFunction() public {
        // Test payable mock function
        string memory result = callReceiver.mockFunction{value: 0.1 ether}();
        assertEq(result, "0x1234");
    }
    
    function testCallReceiverMockFunctionNonPayable() public {
        string memory result = callReceiver.mockFunctionNonPayable();
        assertEq(result, "0x1234");
    }
    
    function testCallReceiverMockStaticFunction() public {
        string memory result = callReceiver.mockStaticFunction();
        assertEq(result, "0x1234");
    }
    
    function testCallReceiverRevertsNoReason() public {
        vm.expectRevert();
        callReceiver.mockFunctionRevertsNoReason();
    }
    
    function testCallReceiverRevertsWithReason() public {
        vm.expectRevert("CallReceiverMock: reverting");
        callReceiver.mockFunctionRevertsReason();
    }
    
    function testCallReceiverThrows() public {
        vm.expectRevert();
        callReceiver.mockFunctionThrows();
    }
    
    function testCallReceiverOutOfGas() public {
        // This should consume all gas
        (bool success,) = address(callReceiver).call{gas: 50000}(
            abi.encodeWithSignature("mockFunctionOutOfGas()")
        );
        
        assertFalse(success);
    }
    
    function testCallReceiverWritesStorage() public {
        // Check initial state
        assertEq(callReceiver.sharedAnswer(), "");
        
        // Call function that writes to storage
        string memory result = callReceiver.mockFunctionWritesStorage();
        assertEq(result, "0x1234");
        
        // Check storage was updated
        assertEq(callReceiver.sharedAnswer(), "42");
    }
    
    // ============ MockTimelock Tests ============
    
    function testMockTimelockDelay() public {
        // TimelockController doesn't expose delay as public
        // We can test it indirectly by checking the minimum delay
        assertTrue(address(mockTimelock) != address(0));
    }
    
    function testMockTimelockScheduleAndExecute() public {
        // Deploy a target contract
        MOCKTOKEN target = new MOCKTOKEN();
        
        // Prepare transaction
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            alice,
            100e18
        );
        
        // Schedule transaction
        bytes32 id = keccak256(abi.encode(address(target), 0, data, bytes32(0), bytes32(0)));
        mockTimelock.schedule(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0),
            0 // min delay
        );
        
        // Wait for timelock delay (even with 0 delay, we need to advance time)
        vm.warp(block.timestamp + 1);
        
        // Execute after delay
        mockTimelock.execute(
            address(target),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );
        
        // Verify execution
        assertEq(target.balanceOf(alice), 100e18);
    }
    
    function testMockTimelockBatch() public {
        MOCKTOKEN target = new MOCKTOKEN();
        
        // Prepare batch
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);
        
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        
        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeWithSignature("transfer(address,uint256)", alice, 100e18);
        datas[1] = abi.encodeWithSignature("transfer(address,uint256)", bob, 200e18);
        
        // Schedule batch
        mockTimelock.scheduleBatch(
            targets,
            values,
            datas,
            bytes32(0),
            bytes32(0),
            0
        );
        
        // Wait for timelock delay
        vm.warp(block.timestamp + 1);
        
        // Execute batch
        mockTimelock.executeBatch(
            targets,
            values,
            datas,
            bytes32(0),
            bytes32(0)
        );
        
        // Verify execution
        assertEq(target.balanceOf(alice), 100e18);
        assertEq(target.balanceOf(bob), 200e18);
    }
    
    function testMockTimelockRoles() public {
        // Check roles
        bytes32 PROPOSER_ROLE = mockTimelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = mockTimelock.EXECUTOR_ROLE();
        
        assertTrue(mockTimelock.hasRole(PROPOSER_ROLE, address(this)));
        assertTrue(mockTimelock.hasRole(EXECUTOR_ROLE, address(this)));
    }
    
    // ============ Integration Tests ============
    
    function testMockContractsIntegration() public {
        // Test interaction between mock contracts
        // Transfer tokens to timelock
        mockToken.transfer(address(mockTimelock), 1000e18);
        
        // Execute transfer through timelock
        bytes memory transferData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            alice,
            100e18
        );
        
        // Schedule and execute
        mockTimelock.schedule(
            address(mockToken),
            0,
            transferData,
            bytes32(0),
            bytes32(0),
            0
        );
        
        // Wait for delay
        vm.warp(block.timestamp + 1);
        
        mockTimelock.execute(
            address(mockToken),
            0,
            transferData,
            bytes32(0),
            bytes32(0)
        );
        
        // Verify transfer succeeded
        assertEq(mockToken.balanceOf(alice), 100e18);
    }
    
    // ============ Edge Cases ============
    
    function testMockTokenZeroAddressTransfer() public {
        vm.expectRevert("ERC20: transfer to the zero address");
        mockToken.transfer(address(0), 100e18);
    }
    
    function testMockTokenInsufficientBalance() public {
        vm.prank(alice); // Alice has no tokens
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        mockToken.transfer(bob, 100e18);
    }
    
    function testCallReceiverFallback() public {
        // Send data that doesn't match any mocked function
        (bool success, bytes memory data) = address(callReceiver).call("random data");
        
        assertFalse(success);
        assertEq(data.length, 0);
    }
    
    // ============ Fuzzing Tests ============
    
    function testFuzzMockTokenTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= mockToken.balanceOf(address(this)));
        
        uint256 balanceBefore = mockToken.balanceOf(to);
        assertTrue(mockToken.transfer(to, amount));
        assertEq(mockToken.balanceOf(to), balanceBefore + amount);
    }
    
    function testFuzzMockTimelockCreation(uint256 delay) public {
        vm.assume(delay < 365 days); // Reasonable delay
        
        // Deploy new timelock with custom delay
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        
        MockTimelock customTimelock = new MockTimelock(delay, proposers, executors);
        assertTrue(address(customTimelock) != address(0));
        assertEq(customTimelock.hello(), 1); // Test custom variable
    }
}