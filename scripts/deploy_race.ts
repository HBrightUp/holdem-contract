import { deployContract, verify } from "./helper";


async function main() {
    const deployAddress = await deployContract("Race")

    await verify(deployAddress, [])
}

main()

