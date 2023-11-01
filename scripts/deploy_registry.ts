import { deployContract, verify } from "./helper";
import { contractAddress } from "./config";
import { network } from "hardhat";

async function main() {


  const deployAddress = await deployContract("Registry", contractAddress.get(network.name)?.Race, { gasLimit: 1500000 })

  await verify(deployAddress, [contractAddress.get(network.name)?.Race!])
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
