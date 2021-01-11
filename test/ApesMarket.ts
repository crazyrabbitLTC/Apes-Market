import { Signer } from "@ethersproject/abstract-signer";
import { ethers, waffle } from "hardhat";

import ApesMarketArtifact from "../artifacts/contracts/ApesMarket.sol/ApesMarket.json";
import GreeterArtifact from "../artifacts/contracts/Greeter.sol/Greeter.json";

import { Accounts, Signers } from "../types";
import { ApesMarket } from "../typechain/ApesMarket";
import { expect } from "chai";

const { deployContract } = waffle;

describe("Unit tests", function () {
  before(async function () {
    this.accounts = {} as Accounts;
    this.signers = {} as Signers;

    const signers: Signer[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.accounts.admin = await signers[0].getAddress();
  });

  describe("Apes Market", function () {
    it("should deploy apes market", async function () {
      this.market = (await deployContract(this.signers.admin, ApesMarketArtifact, [])) as ApesMarket;
      expect(ethers.utils.isAddress(this.market.address)).to.be.true;
    });

    
  });
});
