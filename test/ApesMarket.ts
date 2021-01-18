import { Signer } from "@ethersproject/abstract-signer";
import { ethers, waffle } from "hardhat";
import Web3 from "web3";

import ApesMarketArtifact from "../artifacts/contracts/ApesMarket.sol/ApesMarket.json";
import GreeterArtifact from "../artifacts/contracts/Greeter.sol/Greeter.json";
import MockTokenArtifact from "../artifacts/contracts/mocks/MockToken.sol/MOCKTOKEN.json";

import { Accounts, Signers } from "../types";
import { ApesMarket } from "../typechain/ApesMarket";
import { MOCKTOKEN } from "../typechain/MOCKTOKEN";
import { expect } from "chai";
import { utils } from "ethers";

import { shouldExecuteFunctionCalls} from "./Behavior/Execution.behavior";

const { deployContract } = waffle;

describe("Unit tests", function () {
  before(async function () {
    this.accounts = {} as Accounts;
    this.signers = {} as Signers;

    const signers: Signer[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.tokenDeployer = signers[1];
    this.signers.user1 = signers[2];
    this.signers.dummyAccount = signers[3];


    this.accounts.admin = await signers[0].getAddress();
    this.accounts.tokenDeployer = await signers[1].getAddress();
    this.accounts.user1 = await signers[2].getAddress();
    this.accounts.dummyAccount = await signers[3].getAddress();

    this.proposers = [this.accounts.user1];
    this.executors = [this.accounts.user1];
    this.minDelay = 1;

    // Deploy a ERC20 Token
    this.mockToken = (await deployContract(this.signers.tokenDeployer, MockTokenArtifact, [])) as MOCKTOKEN;
    this.apeToken = (await deployContract(this.signers.tokenDeployer, MockTokenArtifact, [])) as MOCKTOKEN;

    // setup web3
    this.web3 = new Web3();

  });

  describe("Apes Market", function () {
    it("should deploy apes market", async function () {
      this.market = (await deployContract(this.signers.admin, ApesMarketArtifact, [this.minDelay, this.proposers, this.executors])) as ApesMarket;

      expect(ethers.utils.isAddress(this.market.address)).to.be.true;

      // Send all the ApeTokens to the market
      const apeTotalSupply = await this.apeToken.totalSupply();

      await expect(this.apeToken.transfer(this.market.address, apeTotalSupply))
        .to.emit(this.apeToken, "Transfer")
        .withArgs(this.accounts.tokenDeployer, this.market.address, apeTotalSupply);

      // Setup the Market
      await expect(this.market.setupMarket(this.apeToken.address)).to.emit(
        this.market,
        "MarketSetup"
      ).withArgs(true, this.apeToken.address);


    });

    it("should compute correct create2 address", async function () {
      // Get a Market
      const market = this.market as ApesMarket;

      // Get bytecode
      const bytecode = GreeterArtifact.bytecode;

      // Encode constructor params
      const encodedParams = this.web3.eth.abi.encodeParameters(["string"], ["ApeGreeter"]).slice(2);

      // Get salt
      const salt = "ApesMarketSalt";
      const saltHex = this.web3.utils.soliditySha3(salt) as string;

      // Hash the bytecode
      const constructorByteCode = `${bytecode}${encodedParams}`;

      //Then we need to call the contract to compute the address
      const onChainComputedAddress = await market.computeAddress(
        saltHex,
        this.web3.utils.keccak256(constructorByteCode),
      );

      // COMPUTE HASH OFF CHAIN
      const offChainComputedAddress = computeCreate2Address(saltHex, constructorByteCode, market.address);

      expect(utils.isAddress(onChainComputedAddress)).to.be.true;
      expect(utils.isAddress(offChainComputedAddress)).to.be.true;
      expect(onChainComputedAddress).to.be.equal(offChainComputedAddress);
    });

    it("should create a new ape", async function () {
      // Get bytecode
      const bytecode = GreeterArtifact.bytecode;

      // Encode constructor params
      const encodedParams = this.web3.eth.abi.encodeParameters(["string"], ["ApeGreeter"]).slice(2);

      // Get salt
      const saltHex = this.web3.utils.soliditySha3("ApesMarketSalt") as string;

      // Hash the bytecode
      const constructorByteCode = `${bytecode}${encodedParams}`;

      // Compute the address
      const targetAddress = await this.market.computeAddress(saltHex, this.web3.utils.keccak256(constructorByteCode));

      // Other Parameters
      const value = 0;
      const metaDataLocation = "Some IPFS Hash";

      // Get current Ape Count
      const beforeApeCount = await this.market.apeIndex();

      await expect(
        this.market.makeApe(
          targetAddress,
          saltHex,
          value,
          metaDataLocation,
          this.mockToken.address,
          100,
          this.accounts.tokenDeployer,
        ),
      ).to.emit(this.market, "NewDeploymentRequested");

      const afterApeCount = await this.market.apeIndex();
      expect(afterApeCount).to.equal(beforeApeCount + 1);

      // TODO: Still need to check the events emited on the ape created
    });

    it("should deploy a pending ape", async function () {
      const market = this.market as ApesMarket;
      // Get bytecode
      const bytecode = GreeterArtifact.bytecode;

      // Encode constructor params
      const encodedParams = this.web3.eth.abi.encodeParameters(["string"], ["ApeGreeter"]).slice(2);

      // Hash the bytecode
      const constructorByteCode = `${bytecode}${encodedParams}`;

      // ape ID
      const apeId = 0;

      // Deployers token Balance before
      const apeTokenBalanceBefore = await this.apeToken.balanceOf(this.accounts.user1);
      const mockTokenBalanceBefore = await this.mockToken.balanceOf(this.accounts.user1);

      // Expect to fail because we haven't permitted the token
      await expect(market.connect(this.signers.user1).apeDeploy(apeId, constructorByteCode)).to.be.reverted;

      // Permit the market to take it's payment
      await this.mockToken.approve(this.market.address, 101);

      const marketBalanceBefore = await this.mockToken.balanceOf(this.market.address);
      const userBalanceBefore = await this.mockToken.balanceOf(this.accounts.user1);

      // Deploy contract
      await expect(market.connect(this.signers.user1).apeDeploy(apeId, constructorByteCode)).to.emit(
        this.market,
        "NewDeploymentCompleted",
      );

      const marketBalanceAfter = await this.mockToken.balanceOf(this.market.address);
      const adminBalanceAfter = await this.mockToken.balanceOf(this.accounts.user1);

      // The payment is split 50/50
      expect(marketBalanceAfter).to.equal(adminBalanceAfter);

      // Payment actually took place
      expect(marketBalanceBefore).to.be.lt(marketBalanceAfter);
      expect(userBalanceBefore).to.be.lt(adminBalanceAfter);

      // Check deployer got paid in Ape and MockToken
      expect(await this.apeToken.balanceOf(this.accounts.user1)).to.be.gt(apeTokenBalanceBefore);
      expect(await this.mockToken.balanceOf(this.accounts.user1)).to.be.gt(mockTokenBalanceBefore);
    });

    shouldExecuteFunctionCalls();

  });

  // describe("Ape Market Governance", function () {
  // });

});

function computeCreate2Address(saltHex: string, bytecode: string, deployer: string): string {
  const web3 = new Web3();
  // COMPUTE HASH OFF CHAIN
  const result: string = ["ff", deployer, saltHex, web3.utils.soliditySha3(bytecode)]
    .map(x => {
      if (x) {
        return x.replace(/0x/, "");
      }
    })
    .join("");

  const hashResult: string = web3.utils.sha3(`0x${result}`) as string;
  return web3.utils.toChecksumAddress(`0x${hashResult.slice(-40)}`);
}
