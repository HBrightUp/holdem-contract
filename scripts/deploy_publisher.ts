import { deployContract, verify } from "./helper";


async function main() {
    const deployAddress = await deployContract("Publisher")

    await verify(deployAddress, [])
}

main()

