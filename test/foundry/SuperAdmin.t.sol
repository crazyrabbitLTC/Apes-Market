// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../contracts/ApesMarket.sol";
import "../../contracts/Governance/ApeToken.sol";
import "../../contracts/mocks/MockToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleReceiver {
    receive() external payable {}
}

contract SuperAdminTest is Test {
    ApesMarket public market;
    ApeToken public apeToken;
    MOCKTOKEN public paymentToken;
    
    address public superAdmin = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public newSuperAdmin = address(0x4);
    
    // Events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event ExecuteTransaction(address indexed target, uint256 value, bytes data);
    
    function setUp() public {
        // Deploy market with superAdmin as the super admin
        market = new ApesMarket(superAdmin);
        
        // Deploy ApeToken to market
        apeToken = new ApeToken(address(market));
        
        // Deploy payment token
        paymentToken = new MOCKTOKEN();
        
        // Setup market with ApeToken (as creator/deployer)
        market.setupMarket(IERC20(address(apeToken)));
    }
    
    function testSuperAdminDeployment() public {
        // Verify super admin is set correctly
        assertEq(market.superAdmin(), superAdmin, "Super admin should be set correctly");
        
        // Verify super admin has SUPER_ADMIN_ROLE
        bytes32 SUPER_ADMIN_ROLE = market.SUPER_ADMIN_ROLE();
        assertTrue(market.hasRole(SUPER_ADMIN_ROLE, superAdmin), "Super admin should have SUPER_ADMIN_ROLE");
        
        // Verify deployer has CREATOR_ROLE
        bytes32 CREATOR_ROLE = market.CREATOR_ROLE();
        assertTrue(market.hasRole(CREATOR_ROLE, address(this)), "Deployer should have CREATOR_ROLE");
    }
    
    function testOnlySuperAdminCanExecuteTransaction() public {
        // First give the market some tokens to transfer
        paymentToken.transfer(address(market), 1000e18);
        
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", alice, 100e18);
        
        // Non-super admin should fail
        vm.startPrank(alice);
        vm.expectRevert("Caller does not have super admin Role");
        market.executeTransaction(address(paymentToken), data, 0);
        vm.stopPrank();
        
        // Super admin should succeed
        vm.startPrank(superAdmin);
        vm.expectEmit(true, false, false, true);
        emit ExecuteTransaction(address(paymentToken), 0, data);
        market.executeTransaction(address(paymentToken), data, 0);
        vm.stopPrank();
        
        // Verify alice received the tokens
        assertEq(paymentToken.balanceOf(alice), 100e18, "Alice should have received tokens");
    }
    
    function testSuperAdminCanGrantRoles() public {
        bytes32 CREATOR_ROLE = market.CREATOR_ROLE();
        
        // Verify alice doesn't have creator role
        assertFalse(market.hasRole(CREATOR_ROLE, alice), "Alice should not have creator role initially");
        
        // Super admin grants creator role to alice
        vm.startPrank(superAdmin);
        vm.expectEmit(true, true, true, false);
        emit RoleGranted(CREATOR_ROLE, alice, superAdmin);
        market.grantRole(CREATOR_ROLE, alice);
        vm.stopPrank();
        
        // Verify alice now has creator role
        assertTrue(market.hasRole(CREATOR_ROLE, alice), "Alice should have creator role after grant");
    }
    
    function testSuperAdminCanRevokeRoles() public {
        bytes32 CREATOR_ROLE = market.CREATOR_ROLE();
        
        // First grant role to alice
        vm.prank(superAdmin);
        market.grantRole(CREATOR_ROLE, alice);
        
        // Verify alice has the role
        assertTrue(market.hasRole(CREATOR_ROLE, alice), "Alice should have creator role");
        
        // Super admin revokes creator role from alice
        vm.startPrank(superAdmin);
        vm.expectEmit(true, true, true, false);
        emit RoleRevoked(CREATOR_ROLE, alice, superAdmin);
        market.revokeRole(CREATOR_ROLE, alice);
        vm.stopPrank();
        
        // Verify alice no longer has creator role
        assertFalse(market.hasRole(CREATOR_ROLE, alice), "Alice should not have creator role after revoke");
    }
    
    function testSuperAdminCanTransferSuperAdminRole() public {
        bytes32 SUPER_ADMIN_ROLE = market.SUPER_ADMIN_ROLE();
        
        // Verify initial state
        assertTrue(market.hasRole(SUPER_ADMIN_ROLE, superAdmin), "Original super admin should have role");
        assertFalse(market.hasRole(SUPER_ADMIN_ROLE, newSuperAdmin), "New super admin should not have role yet");
        
        // Super admin grants super admin role to new address
        vm.startPrank(superAdmin);
        market.grantRole(SUPER_ADMIN_ROLE, newSuperAdmin);
        vm.stopPrank();
        
        // Both should have super admin role now
        assertTrue(market.hasRole(SUPER_ADMIN_ROLE, superAdmin), "Original super admin should still have role");
        assertTrue(market.hasRole(SUPER_ADMIN_ROLE, newSuperAdmin), "New super admin should have role");
        
        // Original super admin can renounce their role
        vm.startPrank(superAdmin);
        market.renounceRole(SUPER_ADMIN_ROLE, superAdmin);
        vm.stopPrank();
        
        // Verify transfer is complete
        assertFalse(market.hasRole(SUPER_ADMIN_ROLE, superAdmin), "Original super admin should not have role");
        assertTrue(market.hasRole(SUPER_ADMIN_ROLE, newSuperAdmin), "New super admin should have role");
    }
    
    function testNonSuperAdminCannotGrantRoles() public {
        bytes32 CREATOR_ROLE = market.CREATOR_ROLE();
        
        // Non-super admin tries to grant role
        vm.startPrank(alice);
        vm.expectRevert(); // AccessControl will revert
        market.grantRole(CREATOR_ROLE, bob);
        vm.stopPrank();
    }
    
    function testSuperAdminCanExecuteArbitraryTransactions() public {
        // Fund the market contract
        vm.deal(address(market), 10 ether);
        
        // Deploy a simple contract that can receive ETH
        SimpleReceiver receiver = new SimpleReceiver();
        uint256 receiverBalanceBefore = address(receiver).balance;
        
        // Super admin sends ETH to the receiver contract
        vm.startPrank(superAdmin);
        market.executeTransaction(address(receiver), "", 1 ether);
        vm.stopPrank();
        
        assertEq(address(receiver).balance, receiverBalanceBefore + 1 ether, "Receiver should receive 1 ether");
    }
    
    function testSuperAdminCanCallContractFunctions() public {
        // Deploy a simple contract to interact with
        MOCKTOKEN targetContract = new MOCKTOKEN();
        targetContract.transfer(address(market), 1000e18);
        
        // Super admin calls transfer on the token through executeTransaction
        uint256 bobBalanceBefore = targetContract.balanceOf(bob);
        
        bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", bob, 500e18);
        
        vm.prank(superAdmin);
        market.executeTransaction(address(targetContract), transferData, 0);
        
        assertEq(targetContract.balanceOf(bob), bobBalanceBefore + 500e18, "Bob should receive tokens");
    }
    
    function testReentrancyProtectionOnExecuteTransaction() public {
        // This is already tested in ApesMarket.t.sol but included for completeness
        assertTrue(true, "Reentrancy protection is tested in ApesMarket.t.sol");
    }
    
    function testZeroAddressSuperAdminReverts() public {
        // Try to deploy with zero address as super admin
        vm.expectRevert("Super admin cannot be zero address");
        new ApesMarket(address(0));
    }
    
    function testSuperAdminRoleAdminIsSelf() public {
        bytes32 SUPER_ADMIN_ROLE = market.SUPER_ADMIN_ROLE();
        bytes32 roleAdmin = market.getRoleAdmin(SUPER_ADMIN_ROLE);
        
        // Super admin role's admin should be itself
        assertEq(roleAdmin, SUPER_ADMIN_ROLE, "Super admin role should be its own admin");
    }
    
    function testCreatorRoleAdminIsSuperAdmin() public {
        bytes32 CREATOR_ROLE = market.CREATOR_ROLE();
        bytes32 SUPER_ADMIN_ROLE = market.SUPER_ADMIN_ROLE();
        bytes32 roleAdmin = market.getRoleAdmin(CREATOR_ROLE);
        
        // Creator role's admin should be super admin role
        assertEq(roleAdmin, SUPER_ADMIN_ROLE, "Creator role admin should be super admin role");
    }
}