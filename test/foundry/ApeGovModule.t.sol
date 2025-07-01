// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../contracts/Governance/ApeGovModule.sol";
import "../../contracts/ApesMarket.sol";
import "../../contracts/Governance/ApeToken.sol";
import "../../contracts/mocks/MockToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ApeGovModuleTest is Test {
    ApeGovModule public govModule;
    ApesMarket public market;
    ApeToken public apeToken;
    
    address public superAdmin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    function setUp() public {
        // Deploy market
        market = new ApesMarket(superAdmin);
        
        // Deploy token
        apeToken = new ApeToken(address(market));
        
        // Setup market
        market.setupMarket(IERC20(address(apeToken)));
        
        // Deploy governance module with proposers and executors
        address[] memory proposersAndExecutors = new address[](1);
        proposersAndExecutors[0] = superAdmin;
        govModule = new ApeGovModule(proposersAndExecutors);
    }
    
    function testExecuteTransactionThroughModule() public {
        // The ApeToken mints to the market, so we need to transfer from there
        vm.prank(address(market));
        apeToken.transfer(address(govModule), 1000e18);
        
        // Create transaction data
        bytes memory transferData = abi.encodeWithSignature(
            "transfer(address,uint256)", 
            alice, 
            100e18
        );
        
        // Execute through module as timelock
        address timelock = address(govModule.timelock());
        vm.prank(timelock);
        bytes memory result = govModule.executeTransaction(
            address(apeToken),
            transferData,
            0
        );
        
        // Verify transfer succeeded
        assertEq(apeToken.balanceOf(alice), 100e18);
        
        // Decode return data
        bool success = abi.decode(result, (bool));
        assertTrue(success);
    }
    
    function testExecuteTransactionWithValue() public {
        // Fund the gov module
        vm.deal(address(govModule), 5 ether);
        
        // Deploy a contract that can receive ETH
        SimpleReceiver receiver = new SimpleReceiver();
        
        // Execute ETH transfer through module
        address timelock = address(govModule.timelock());
        vm.prank(timelock);
        govModule.executeTransaction(
            address(receiver),
            "",
            1 ether
        );
        
        // Verify ETH was transferred
        assertEq(address(receiver).balance, 1 ether);
    }
    
    function testNonTimelockCannotExecute() public {
        // Try to execute as non-timelock
        vm.prank(alice);
        vm.expectRevert("Caller does not have timelock Role");
        govModule.executeTransaction(
            address(apeToken),
            "",
            0
        );
    }
    
    function testExecuteFailingTransaction() public {
        // Try to execute a transaction that will fail
        bytes memory badData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            alice,
            1000000e18 // More than balance
        );
        
        address timelock = address(govModule.timelock());
        vm.prank(timelock);
        vm.expectRevert();
        govModule.executeTransaction(
            address(apeToken),
            badData,
            0
        );
    }
    
    function testModuleCanExecuteOnDifferentTargets() public {
        // Give gov module tokens from market
        vm.prank(address(market));
        apeToken.transfer(address(govModule), 500e18);
        
        // Deploy another token
        MOCKTOKEN token2 = new MOCKTOKEN();
        token2.transfer(address(govModule), 500e18);
        
        // Execute transfers through same module
        bytes memory transferData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            50e18
        );
        
        address timelock = address(govModule.timelock());
        vm.startPrank(timelock);
        
        // Execute on token 1
        govModule.executeTransaction(
            address(apeToken),
            transferData,
            0
        );
        
        // Execute on token 2
        govModule.executeTransaction(
            address(token2),
            transferData,
            0
        );
        
        vm.stopPrank();
        
        // Verify both transfers
        assertEq(apeToken.balanceOf(bob), 50e18);
        assertEq(token2.balanceOf(bob), 50e18);
    }
    
    function testComplexTransactionExecution() public {
        // Deploy a mock contract with complex function
        ComplexContract complex = new ComplexContract();
        
        // Prepare complex call
        bytes memory complexData = abi.encodeWithSignature(
            "complexFunction(address,uint256,string)",
            address(apeToken),
            123,
            "test message"
        );
        
        address timelock = address(govModule.timelock());
        vm.prank(timelock);
        bytes memory result = govModule.executeTransaction(
            address(complex),
            complexData,
            0
        );
        
        // Verify complex function was called
        (bool success, uint256 value, string memory message) = abi.decode(
            result, 
            (bool, uint256, string)
        );
        
        assertTrue(success);
        assertEq(value, 123);
        assertEq(message, "test message");
    }
}

contract SimpleReceiver {
    receive() external payable {}
}

contract ComplexContract {
    function complexFunction(
        address token,
        uint256 value,
        string memory message
    ) external returns (bool, uint256, string memory) {
        // Do some checks
        require(token != address(0), "Invalid token");
        require(value > 0, "Invalid value");
        require(bytes(message).length > 0, "Invalid message");
        
        return (true, value, message);
    }
}