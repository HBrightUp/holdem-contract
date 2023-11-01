import { ethers, run } from "hardhat";


export async function verify(contractAddress: string | undefined, args: string[]) {

    try {
        /**About "verify:verify":
         *  The first verify is a name in the type of string
         *  The second verify is the task of verify */
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e) {
        console.log(e)
    }
}

export async function deployContract(name: string, ...args: any): Promise<string> {
    const factory = await ethers.getContractFactory(name)
    const contract = await factory.deploy(...args)

    console.log(`${name} deploy to ${contract.address}......`)
    console.log("Pending......")
    await contract.deployed()
    console.log(`${name} Deployed`)
    return contract.address
}


export async function upgradeContract(name: string) {
    // TODO:
}