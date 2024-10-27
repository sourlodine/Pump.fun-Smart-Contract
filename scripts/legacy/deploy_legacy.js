const { deployContract, sendTxn, sleep, writeTmpAddresses } = require("../shared/helpers")

async function main() {
    const [deployer] = await ethers.getSigners()
    const weth = { address: "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a" }

    const factory = await deployContract("Factory", [
        deployer.address
    ], "Factory")

    const router = await deployContract("Router", [
        factory.address,
        weth.address,
        1
    ], "Router")

    const pump_fun = await deployContract("PumpFun", [
        factory.address, // Factory 
        router.address, // Router 
        deployer.address, // fee_to 
        1
    ], "Router")
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })