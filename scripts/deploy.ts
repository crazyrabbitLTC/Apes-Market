// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";

import Transport from "@ledgerhq/hw-transport-node-hid";
import Eth from "@ledgerhq/hw-app-eth";




async function main(): Promise<void> {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");

  // We get the contract to deploy
  // const Greeter: ContractFactory = await ethers.getContractFactory("Greeter");
  // const greeter: Contract = await Greeter.deploy("Hello, Buidler!");
  // await greeter.deployed();

  // console.log("Greeter deployed to: ", greeter.address);
  const getETHAddress = async () => {
    console.log("HERE")
    const transport = await Transport.create();
    transport.setDebugMode(true);
    const eth = new Eth(transport)
    console.log("ETH: ", eth);
    eth.getAddress("44'/60'/0'/0/0").then((o: any) => console.log("Address: ", o.address))
  }
  
  getETHAddress();
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
