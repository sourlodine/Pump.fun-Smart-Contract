const { ADDRESS_ZERO } = require("@uniswap/v3-sdk")
const { deployContract, sendTxn, contractAt, sleep } = require("./shared/helpers")
const { expandDecimals } = require("./shared/utilities")

async function createToken(tokenFactory, name, symbol) {
    // creating new Token
    const tx = await tokenFactory.createToken(name, symbol, 'https://harmony.one');
    const receipt = await tx.wait()
    console.log('tokenFactory.createToken: ', receipt.transactionHash);

    const addedTokenAddress = receipt.events.find(e => e.event === 'TokenCreated')?.args.token;

    console.log(`${symbol} tokenAddress: `, addedTokenAddress);

    return addedTokenAddress;
}

async function getTokenBalances(tokenAddress) {
    const [deployer] = await ethers.getSigners()
    const token = await contractAt("Token", tokenAddress);

    const symbol = await token.symbol();

    // check token balance
    console.log(`${symbol} balance: `, Number(await token.balanceOf(deployer.address)));

    console.log(`${symbol} totalSupply: `, Number(await token.totalSupply()));
}

async function deployTokenFactory() {
    // const [deployer] = await ethers.getSigners()
    // const weth = { address: "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a" }

    const tokenImplementation = await deployContract("Token", [], "Token")

    const bondingCurve = await deployContract("BondingCurve", [16319324419, 1000000000], "BondingCurve")

    const tokenFactory = await deployContract("TokenFactory", [
        tokenImplementation.address, // _tokenImplementation,
        ADDRESS_ZERO, // _uniswapV2Router,
        ADDRESS_ZERO, // _uniswapV2Factory,
        bondingCurve.address, //_bondingCurve,
        100, // _feePercent
    ], "TokenFactory")

    return tokenFactory;
}

async function test({ maxFundingRateInterval }) {
    console.log(`----test ${maxFundingRateInterval} --------------`);
    const tokenFactory = await deployTokenFactory();

    await sendTxn(
        tokenFactory.setMaxFundingRateInterval(maxFundingRateInterval),
        "tokenFactory.setMaxFundingRateInterval"
    )
    console.log('maxFundingRateInterval: ', Number(await tokenFactory.maxFundingRateInterval()))

    await sleep(2000);

    const tokenA = await createToken(tokenFactory, "MyFirstToken1", "AAA");
    const tokenB = await createToken(tokenFactory, "MyFirstToken2", "BBB");

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    // buy token for ONE
    await sendTxn(
        tokenFactory.buy(tokenA, { value: expandDecimals(1, 14) }),
        "tokenFactory.buy"
    )

    await sendTxn(
        tokenFactory.buy(tokenB, { value: expandDecimals(1, 13) }),
        "tokenFactory.buy"
    )

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    // buy token for ONE
    await sendTxn(
        tokenFactory.sell(tokenA, expandDecimals(1, 21)),
        "tokenFactory.sell"
    )

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    await sendTxn(
        tokenFactory.setWinner(),
        "tokenFactory.setWinner"
    )

    await sendTxn(
        tokenFactory.burnTokenAndMintWinner(tokenB),
        "tokenFactory.burnTokenAndMintWinner"
    );

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);
};

async function main() {
    try {
        await test({ maxFundingRateInterval: 86400 });
    } catch (e) {
        console.log(e)
    }

    try {
        await test({ maxFundingRateInterval: 1 });
    } catch (e) {
        console.log(e)
    }

    try {
        await test({ maxFundingRateInterval: 10 });
    } catch (e) {
        console.log(e)
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })