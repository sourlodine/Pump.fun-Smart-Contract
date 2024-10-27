const { ADDRESS_ZERO } = require("@uniswap/v3-sdk")
const { deployContract, sendTxn, contractAt } = require("./shared/helpers")
const { expandDecimals } = require("./shared/utilities")

async function main() {
    const [deployer] = await ethers.getSigners()
    const weth = { address: "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a" }

    const tokenImplementation = await deployContract("Token", [], "Token")

    const bondingCurve = await deployContract("BondingCurve", [16319324419, 1000000000], "BondingCurve")

    const tokenFactory = await deployContract("TokenFactory", [
        tokenImplementation.address, // _tokenImplementation,
        ADDRESS_ZERO, // _uniswapV2Router,
        ADDRESS_ZERO, // _uniswapV2Factory,
        bondingCurve.address, //_bondingCurve,
        100, // _feePercent
    ], "TokenFactory")

    // creating new Token
    const tx = await tokenFactory.createToken("MyFirstToken", "MFT");
    const receipt = await tx.wait()
    console.log('tokenFactory.createToken: ', receipt.transactionHash);

    const addedTokenAddress = receipt.events.find(e => e.event === 'TokenCreated')?.args.token;

    console.log('tokenAddress: ', addedTokenAddress);

    // TRADING

    // check token balance
    console.log('Checking token: ', addedTokenAddress);

    const token = await contractAt("Token", addedTokenAddress);

    // check token balance
    console.log('User balance before: ', Number(await token.balanceOf(deployer.address)));

    console.log('totalSupply: ', Number(await token.totalSupply()));

    // buy token for ONE
    await sendTxn(
        tokenFactory.buy(addedTokenAddress, { value: expandDecimals(1, 14) }),
        "tokenFactory.buy"
    )

    console.log('User balance after BUY: ', Number(await token.balanceOf(deployer.address)));

    // buy token for ONE
    await sendTxn(
        tokenFactory.sell(addedTokenAddress, expandDecimals(1, 21)),
        "tokenFactory.sell"
    )

    console.log('User balance after SELL: ', Number(await token.balanceOf(deployer.address)));

    await sendTxn(
        tokenFactory.burnAllAndReleaseWinner(addedTokenAddress),
        "tokenFactory.burnAllAndReleaseWinner"
    );
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })