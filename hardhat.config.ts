import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import "hardhat-contract-sizer"

import * as dotenv from "dotenv";


dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.9",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1,
            },
        },
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: true,
    },
    defaultNetwork: "mumbai",
    networks: {
        mumbai: {
            url: process.env.MUMBAI_RPC_URL,
            accounts: [process.env.MUMBAI_PRIVATE_KEY || ""],
        }
    },
    etherscan: {
        apiKey: {
            polygonMumbai: process.env.MUMBAI_API_KEY || "",
        },
    },
};

export default config;
