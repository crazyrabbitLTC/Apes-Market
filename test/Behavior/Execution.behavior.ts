import { expect } from "chai";
import { ethers, waffle } from "hardhat";
// import { ApesMarket } from "../../typechain/ApesMarket";
import { MockTimelock } from "../../typechain/MockTimelock";
import { CallReceiverMock } from "../../typechain/CallReceiverMock";
import mockCallContract from "../../artifacts/contracts/mocks/CallReceiverMock.sol/CallReceiverMock.json";
import timelockArtifact from "../../artifacts/contracts/mocks/MockTimelock.sol/MockTimelock.json";
import ApesMarketArtifact from "../../artifacts/contracts/ApesMarket.sol/ApesMarket.json";

const constants = {
  ZERO_ADDRESS: "0x0000000000000000000000000000000000000000",
  ZERO_BYTES32: "0x0000000000000000000000000000000000000000000000000000000000000000",
  MAX_UINT256: ethers.BigNumber.from("2").pow(ethers.BigNumber.from("256")).sub(ethers.BigNumber.from("1")),
  MAX_INT256: ethers.BigNumber.from("2").pow(ethers.BigNumber.from("255")).sub(ethers.BigNumber.from("1")),
  MIN_INT256: ethers.BigNumber.from("2").pow(ethers.BigNumber.from("255")).mul(ethers.BigNumber.from("-1")),
};

export function shouldExecuteFunctionCalls(): void {
  it("should execute function calls", async function () {
    // Get tools
    const { deployContract } = waffle;
    const { utils } = ethers;

    const lotsOfValue = utils.parseEther("50");

    // Fund the Market contract with ether
    await expect(
      this.signers.admin.sendTransaction({
        to: this.market.address,
        value: lotsOfValue,
      }),
    ).to.be.not.reverted;

    // Deploy mock call target and get address
    const mockInstance = (await deployContract(this.signers.admin, mockCallContract)) as CallReceiverMock;

    // Create tx for the Vault to execute
    const mockCallContractInterface = new utils.Interface(mockCallContract.abi);
    const functionCallTarget = mockInstance.address;
    const functionCallData = mockCallContractInterface.encodeFunctionData("mockFunction", []);
    const functionCallValue = utils.parseEther("3.45");

    // Create tx for the timelock to execute in order to call the vault
    const marketInterface = new utils.Interface(ApesMarketArtifact.abi);
    const timelockTarget = this.market.address;
    const timelockData = marketInterface.encodeFunctionData("executeTransaction", [functionCallTarget, functionCallData, functionCallValue]);
    const timelockValue = utils.parseEther("0");
    const salt = utils.keccak256(utils.toUtf8Bytes("hello world"));
    const timelockDelay = 2;
    const predecessor = constants.ZERO_BYTES32;

    // Get Timelock attached to governor signer
    this.timeLockAddress = await this.market.timelock();
    const timelock = new ethers.Contract(
      this.timeLockAddress,
      timelockArtifact.abi,
      this.signers.user1,
    ) as MockTimelock;

    // Get the ID of the operation
    const id = await timelock.hashOperation(timelockTarget, timelockValue, timelockData, predecessor, salt);

    // Schedule a function call with timelock
    await expect(timelock.schedule(timelockTarget, timelockValue, timelockData, predecessor, salt, timelockDelay)).to
      .not.be.reverted;

    // Check if scheduled operation is pending
    await expect(await timelock.isOperationPending(id)).to.be.true;
    await expect(await timelock.isOperationReady(id)).to.be.false;
    await expect(await timelock.isOperationDone(id)).to.be.false;

    // Execute prematurely
    await expect(timelock.execute(timelockTarget, timelockValue, timelockData, predecessor, salt)).to.be.reverted;

    // Prompt the "instamine" of ganache to move blocktime forward
    await this.signers.admin.sendTransaction({
      to: this.accounts.dummyAccount,
      value: utils.parseEther("0.001"),
    });
    await this.signers.admin.sendTransaction({
      to: this.accounts.dummyAccount,
      value: utils.parseEther("0.001"),
    });

    // Check if scheduled operation is ready
    await expect(await timelock.isOperationReady(id)).to.be.true;

    // Get balance of vault before
    const marketEthBalance = await this.market.balance();

    // Execute
    await expect(timelock.execute(timelockTarget, timelockValue, timelockData, predecessor, salt))
      .to.emit(this.market, "ExecuteTransaction")
      .withArgs(functionCallTarget, functionCallValue, functionCallData);

    // Get balance of vault after
    const vaultbalanceAfter = await this.market.balance();
    expect(marketEthBalance.sub(vaultbalanceAfter)).to.equal(functionCallValue);

    // Check if scheduled operation is done
    await expect(await timelock.isOperationDone(id)).to.be.true;

    // Scheduled operation should not be repeatable
    await expect(timelock.execute(timelockTarget, timelockValue, timelockData, predecessor, salt)).to.be.reverted;
  });
}
