import { deployContract, verify } from "./helper";

async function main() {

  const deployAddress = await deployContract("PlayerProfile")

  await verify(deployAddress,[])
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
