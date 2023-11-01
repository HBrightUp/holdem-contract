import { ethers, upgrades } from "hardhat";

async function main() {

  const Token = await ethers.getContractFactory("Token");
  const token = await upgrades.deployProxy(Token, ["Pirate", "Pirate", "1000000000000000000000000"]);
  await token.deployed();

  console.log(
    `Token with deployed to ${token.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
