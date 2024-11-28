const { ADDRESS_ZERO } = require("@uniswap/v3-sdk")
const { deployContract, sendTxn, contractAt, sleep } = require("./shared/helpers")
const { expandDecimals } = require("./shared/utilities")

const {ContractFactory, utils} = require("ethers");
const { abi, bytecode } = require('@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json');

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

    const balance = Number(await token.balanceOf(deployer.address));
    // check token balance
    console.log(`${symbol} balance: `, balance);

    const totalSupply = Number(await token.totalSupply());
    console.log(`${symbol} totalSupply: `, totalSupply);

    return { balance, totalSupply };
}

async function deployTokenFactory() {
    const [deployer] = await ethers.getSigners()
    const weth = { address: "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a" }

    const tokenImplementation = await deployContract("Token", [], "Token")

    const bondingCurve = await deployContract("BancorBondingCurve", [1000000, 1000000], "BondingCurve")

    // const uniswapV3Factory = "0x12d21f5d0ab768c312e19653bf3f89917866b8e8";
    const Factory = new ContractFactory(abi, bytecode, deployer);
    const factory = await Factory.deploy();
    const uniswapV3Factory = factory.address;

    const tokenFactory = await deployContract("TokenFactory", [
        tokenImplementation.address, // _tokenImplementation,
        uniswapV3Factory, // _uniswapV3Factory,
        bondingCurve.address, //_bondingCurve,
        weth.address,
        100, // _feePercent
    ], "TokenFactory")

    return { tokenFactory, bondingCurve };
}

async function test() {
    const { bondingCurve, tokenFactory } = await deployTokenFactory();

    await sendTxn(
        tokenFactory.startNewCompetition(),
        "tokenFactory.startNewCompetition"
    )

    console.log('startNewCompetition: ', Number(await tokenFactory.currentCompetitionId()))

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

    const { totalSupply: totalSupplyA } = await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    // console.log(
    //     Number(await tokenFactory.collateral(tokenA)),
    //     totalSupplyA,
    //     totalSupplyA - 100
    // )

    // console.log('computeRefundForBurning: ', await bondingCurve.computeRefundForBurning(
    //     await tokenFactory.collateral(tokenA),
    //     totalSupplyA,
    //     totalSupplyA - 100 // expandDecimals(1, 21)
    // ));

    // buy token for ONE
    await sendTxn(
        tokenFactory.sell(tokenA, totalSupplyA - 100),
        "tokenFactory.sell"
    )

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    const prevCompetitionId = await tokenFactory.currentCompetitionId();

    await sendTxn(
        tokenFactory.startNewCompetition(),
        "tokenFactory.startNewCompetition"
    )
    
    console.log('startNewCompetition: ', Number(await tokenFactory.currentCompetitionId()))

    await sendTxn(
        tokenFactory.setWinnerByCompetitionId(prevCompetitionId),
        "tokenFactory.setWinnerByCompetitionId"
    )

    await sendTxn(
        tokenFactory.burnTokenAndMintWinner(tokenA),
        "tokenFactory.burnTokenAndMintWinner for NOT Winner"
    );

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    await sendTxn(
        tokenFactory.burnTokenAndMintWinner(tokenB),
        "tokenFactory.burnTokenAndMintWinner for Winner"
    );    

    await getTokenBalances(tokenA);
    await getTokenBalances(tokenB);

    console.log('winner: ', await tokenFactory.getWinnerByCompetitionId(prevCompetitionId));
};

async function main() {
    try {
        await test();
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