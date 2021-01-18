import { Signer } from "@ethersproject/abstract-signer";

export interface Accounts {
  admin: string;
  tokenDeployer: string;
  user1: string;
  dummyAccount: string;
}

export interface Signers {
  admin: Signer;
  tokenDeployer: Signer;
  user1: Signer;
  dummyAccount: Signer;
}
