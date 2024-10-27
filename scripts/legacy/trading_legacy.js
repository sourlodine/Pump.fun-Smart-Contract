const { deployContract, sendTxn, sleep, contractAt } = require("../shared/helpers")
const { expandDecimals } = require("./shared/utilities")

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

    const pumpFun = await deployContract("PumpFun", [
        factory.address, // Factory 
        router.address, // Router 
        deployer.address, // fee_to 
        1 // fee
    ], "Router")

    // creating new Token
    await sendTxn(
        pumpFun.launch(
            'HMY_1',// _name
            'HMY_1_T',// _ticker
            'HMY_1_D',// desc
            'https://s2.coinmarketcap.com/static/img/coins/64x64/3945.png',// img
            ['https://google.com', 'https://google.com', 'https://google.com', 'https://google.com'],// urls string 4[]
            expandDecimals(100000000, 18), // _supply
            4,// maxTx
            { value: expandDecimals(1, 18) }
        ),
        "pumpFun.launch"
    )

    // check user tokens
    const userTokens = (await pumpFun.getUserTokens())[0];
    console.log('pumpFun.getUserTokens: ', userTokens);

    const addedTokenAddress = userTokens.data.token;

    // check token balance
    console.log('Checking token: ', addedTokenAddress);

    const token = await contractAt("ERC20", addedTokenAddress);

    // check token balance
    console.log('User balance before: ', Number(await token.balanceOf(deployer.address)));

    console.log('totalSupply: ', Number(await token.totalSupply()));

    // buy token for ONE
    await sendTxn(
        pumpFun.swapETHForTokens(
            addedTokenAddress,
            deployer.address,
            deployer.address,
            { value: expandDecimals(1, 14) }
        ),
        "pumpFun.swapETHForTokens"
    )

    console.log('User balance after: ', Number(await token.balanceOf(deployer.address)));
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })