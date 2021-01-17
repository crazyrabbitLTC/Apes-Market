// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Governance/ApeGovModule.sol";

import "hardhat/console.sol";

contract ApesMarket is ApeGovModule, ReentrancyGuard{
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    struct ApeRequest {
        uint256 id;
        address requestor;
        address targetAddress;
        bytes32 salt;
        uint256 value;
        bool deployed;
        address ape;
        uint256 gasUsed;
        uint256 gasPrice;
        IERC20 paymentToken;
        uint256 paymentAmount;
        address payer;
    }

    // Ape storage
    Counters.Counter public apeIndex;
    mapping(uint256 => ApeRequest) public allApesByIndex;
    mapping(address => uint256) public indexOfApe;
    mapping(address => bool) public apeExists;

    // Events
    event NewDeploymentRequested(
        uint256 id,
        address targetAddress,
        bytes32 salt,
        string metaData,
        uint256 value,
        address requestor,
        address paymentToken,
        uint256 paymentAmount,
        address payer
    );

    event NewDeploymentCompleted(
        uint256 id,
        address targetAddress,
        uint256 gasUsed,
        uint256 gasPrice,
        uint256 value,
        address ape,
        address paymentToken,
        uint256 paymentAmount,
        address payer
    );

    constructor(address[] memory proposersAndExecutors) ApeGovModule(proposersAndExecutors){
    }
    // Input the target address and the location of the metadata for the byteCode
    function makeApe(
        address targetAddress,
        bytes32 salt,
        uint256 value,
        string memory metaDataLocation,
        IERC20 _paymentToken,
        uint256 _paymentAmount,
        address _payer
    ) external returns (uint256) {
        require(!apeExists[targetAddress], "ApesMarket:: Ape Request already exists");

        // Get Ape id
        uint256 id = apeIndex.current();

        // make ape
        ApeRequest memory newApe;
        newApe.id = id;
        newApe.requestor = msg.sender;
        newApe.targetAddress = targetAddress;
        newApe.salt = salt;
        newApe.deployed = false;
        newApe.value = value;
        newApe.ape = address(0x0);
        newApe.gasUsed = 0;
        newApe.gasPrice = 0;
        newApe.paymentToken = _paymentToken;
        newApe.paymentAmount = _paymentAmount;
        newApe.payer = _payer;

        // save ape
        allApesByIndex[id] = newApe;
        indexOfApe[targetAddress] = id;
        apeExists[targetAddress] = true;

        // increment ape ids
        apeIndex.increment();

        // tell everyone
        emit NewDeploymentRequested(
            id,
            targetAddress,
            salt,
            metaDataLocation,
            value,
            msg.sender,
            address(_paymentToken),
            _paymentAmount,
            _payer
        );
        return apeIndex.current();
    }

    // For this to work, the payment token must have given approval
    function apeDeploy(
        uint256 id,
        bytes memory code,
        address paymentRecipient
    ) external nonReentrant payable {
        // Measure Gas
        uint256 startGas = gasleft();

        // Check to see ape exists
        require(apeExists[allApesByIndex[id].targetAddress], "ApesMarket: Ape does not exist");

        // Check ape is not already deployed
        require(!allApesByIndex[id].deployed, "ApesMarket: Ape already deployed");

        // Check that if value is not 0 that caller sent the required eth to deploy
        if (allApesByIndex[id].value > 0) {
            require(msg.value == allApesByIndex[id].value, "ApesMarket: Deployment did not receive required Ether");
        }

        // update Ape
        allApesByIndex[id].deployed = true;
        allApesByIndex[id].ape = msg.sender;
        allApesByIndex[id].gasUsed = startGas.sub(gasleft());
        allApesByIndex[id].gasPrice = tx.gasprice;

        // Avoid stack too deep error
        {
            // Apes Market Gets Paid
            uint256 balanceBefore = allApesByIndex[id].paymentToken.balanceOf(address(this));

            allApesByIndex[id].paymentToken.transferFrom(
                allApesByIndex[id].payer,
                address(this),
                allApesByIndex[id].paymentAmount
            );

            uint256 balanceAfter = allApesByIndex[id].paymentToken.balanceOf(address(this));

            require(
                balanceAfter.sub(balanceBefore) == allApesByIndex[id].paymentAmount,
                "ApesMarket: Where is our money? Ape payment failed."
            );
        }

        // Check to see deployed address matches the expected address
        address deployed = Create2.deploy(allApesByIndex[id].value, allApesByIndex[id].salt, code);
        require(
            allApesByIndex[id].targetAddress == deployed,
            "ApesMarket: Deployed contract does not match expected address"
        );

        // Split half the tokens with msg.sender
        allApesByIndex[id].paymentToken.transfer(paymentRecipient, (allApesByIndex[id].paymentAmount).div(2));

        // tell everyone
        emit NewDeploymentCompleted(
            id,
            deployed,
            allApesByIndex[id].gasUsed,
            tx.gasprice,
            allApesByIndex[id].value,
            msg.sender,
            address(allApesByIndex[id].paymentToken),
            allApesByIndex[id].value,
            allApesByIndex[id].payer
        );
    }

    // Function for contract to call to check if the ape is the deployer
    function getApe(address deployedAddress) external view returns (address) {
        return allApesByIndex[indexOfApe[deployedAddress]].ape;
    }

    function computeAddress(bytes32 salt, bytes32 bytecodeHash) public view returns (address) {
        return Create2.computeAddress(salt, bytecodeHash);
    }
}
