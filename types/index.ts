import { Signer } from "@ethersproject/abstract-signer";

export interface Accounts {
  admin: string;
  tokenDeployer: string;
}

export interface Signers {
  admin: Signer;
  tokenDeployer: Signer;
}
