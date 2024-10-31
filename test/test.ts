import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Test Pump Fun", function () {
  let hardhatTokenFactory: any;
  let hardhatPumpFun: any;
  let testToken: any;
  let addr1: any;
  let Erc20Token: any;
  const config = {
    name: "Test Token",
    symbol: "TST",
    decimals: 18,
    feeRecipient: "0x044421aAbF1c584CD594F9C10B0BbC98546CF8bc",
    feeAmount: 1000000000000000n,
    feeBasisPoint: 100n,
    initialVirtualTokenReserves: 1000000000000000000000000000n,
    initialVirtualEthReserves: 3000000000000000000000n,
    tokenTotalSupply: 1000000000000000000000000000n,
    mcapLimit: 100000000000000000000000n,
    initComplete: false,
  };

  describe("Token Create", function () {
    it("Token Factory Deployment", async function () {
      const [owner] = await hre.ethers.getSigners();

      hardhatTokenFactory = await hre.ethers.deployContract("TokenFactory");
      hardhatPumpFun = await hre.ethers.deployContract("PumpFun", [
        config.feeRecipient,
        config.feeAmount,
        config.feeBasisPoint,
      ]);

      console.log(
        "Deployed TokenFactory Address :: ",
        await hardhatTokenFactory.getAddress()
      );
      console.log(
        "Deployed PumpFun Contract Address :: ",
        await hardhatPumpFun.getAddress()
      );

      await hardhatTokenFactory.waitForDeployment();
    });

    it("Init Token Factory Variables", async function () {
      const pumpFunAddress = await hardhatPumpFun.getAddress();
      await hardhatTokenFactory.setPoolAddress(pumpFunAddress);

      expect(pumpFunAddress).to.equal(
        await hardhatTokenFactory.contractAddress()
      );
    });
    it("Token Creating on Token Factory Contract", async function () {
      await hardhatTokenFactory.deployERC20Token(config.name, config.symbol, {
        value: config.feeAmount,
      });
      testToken = await hardhatTokenFactory.tokens(0);

      const tokenBondingCurve = await hardhatPumpFun.getBondingCurve(
        testToken[0]
      );

      expect(tokenBondingCurve[0]).to.equal(testToken[0]);
      expect(tokenBondingCurve[1]).to.equal(config.initialVirtualTokenReserves);
      expect(tokenBondingCurve[2]).to.equal(config.initialVirtualEthReserves);
      expect(tokenBondingCurve[3]).to.equal(config.initialVirtualTokenReserves);
      expect(tokenBondingCurve[4]).to.equal(0n);
      expect(tokenBondingCurve[5]).to.equal(config.tokenTotalSupply);
      expect(tokenBondingCurve[6]).to.equal(config.mcapLimit);
      expect(tokenBondingCurve[7]).to.equal(config.initComplete);
    });
  });

  describe("Buy/Sell Function Check", function () {
    it("Buy Function", async function () {
      [addr1] = await hre.ethers.getSigners();

      Erc20Token = await hre.ethers.getContractAt("IERC20", testToken[0]);
      const tokenBalance = await Erc20Token.balanceOf(addr1);
      const slippage = 20n;
      const amount = 1000000000000000000n;
      const tokenBondingCurve = await hardhatPumpFun.getBondingCurve(
        testToken[0]
      );

      const tokenReceivedWithLiquidity = exchangeRate(
        amount,
        tokenBondingCurve
      );
      const ethAmount = 1000000000000000000n;
      const maxEthAmount = (ethAmount * (100n + slippage)) / 100n;

      const before = await hre.ethers.provider.getBalance(config.feeRecipient);

      const buyTx = await hardhatPumpFun
        .connect(addr1)
        .buy(testToken[0], tokenReceivedWithLiquidity, maxEthAmount, {
          value: ethAmount,
        });
      const receipt = await buyTx.wait();

      console.log(
        "------------------Fee Wallet ETH Balance Change Show--------------------------"
      );

      const after = await hre.ethers.provider.getBalance(config.feeRecipient);
      console.log(
        "Before Buy: ",
        before,
        "     After Buy: ",
        after,
        "\n >>>====== Change Balance ",
        after - before,
        "\n >>>====== Buy ETH Balance",
        10 ** 18,
        "\n>>>>>>========= Percentage: ",
        Number(((after - before) * 100n) / ethAmount)
      );
      console.log(
        "------------------------------------------------------------------------------\n"
      );

      const afterTokenBalance = await Erc20Token.balanceOf(addr1);
      console.log(
        "--------------------------Token Balance Change Show---------------------------"
      );

      console.log(
        "Before Token Balance: ",
        tokenBalance,
        "After Buy Token Balance: ",
        afterTokenBalance,
        "\n Change Balance: ",
        afterTokenBalance - tokenBalance,
        "\n Bought Amount:  "
      );
      console.log(
        "------------------------------------------------------------------------------\n"
      );
    });
    it("Sell Function", async function () {
      const tokenBalance = await Erc20Token.balanceOf(addr1);
      const slippage = 20n;
      const amount = tokenBalance;

      const tokenBondingCurve = await hardhatPumpFun.getBondingCurve(
        testToken[0]
      );
      const ethAmount = exchangeSellRate(amount, tokenBondingCurve);
      const minEthAmount = (ethAmount * (100n - slippage)) / 100n;

      const before = await hre.ethers.provider.getBalance(config.feeRecipient);

      await Erc20Token.connect(addr1).approve(
        await hardhatPumpFun.getAddress(),
        amount
      );
      const sellTx = await hardhatPumpFun
        .connect(addr1)
        .sell(testToken[0], amount, minEthAmount);
      const receipt = await sellTx.wait();

      console.log(
        "------------------Fee Wallet ETH Balance Change Show--------------------------"
      );

      const after = await hre.ethers.provider.getBalance(config.feeRecipient);
      console.log("<==== Sell Token Amount", amount, "\n");
      console.log(
        "------------------Fee Wallet ETH Balance Change Show--------------------------"
      );
      console.log(
        "Before Sell: ",
        before,
        "     After Sell: ",
        after,
        "\n >>>====== Change Balance  ",
        after - before,
        "\n >>>====== Sell ETH Balance",
        ethAmount,
        "\n>>>>>>========= Percentage: ",
        ((after - before) * 100n) / ethAmount
      );
      console.log(
        "------------------------------------------------------------------------------\n"
      );
    });
  });
});

const exchangeRate = (purchaseAmount: BigInt, liquidityPool: any) => {
  let tokensSold = 0n;
  const totalLiquidity = liquidityPool[2] * liquidityPool[1];
  const newEthReserve = liquidityPool[2] + purchaseAmount;

  const pricePerToken = totalLiquidity / newEthReserve;

  tokensSold = BigInt(liquidityPool[1] - pricePerToken);
  // console.log(Number(tokensSold));
  tokensSold = tokensSold > liquidityPool[1] ? liquidityPool[1] : tokensSold;
  if (tokensSold < 0n) {
    tokensSold = 0n;
  }

  return tokensSold;
};

const exchangeSellRate = (amount: BigInt, liquidityPool: any) => {
  let ethSold = 0n;
  const totalLiquidity = liquidityPool[2] * liquidityPool[1];
  const newTokenReserve = liquidityPool[1] + amount;

  const pricePerToken = totalLiquidity / newTokenReserve;

  ethSold = BigInt(liquidityPool[2] - pricePerToken);

  ethSold = ethSold > liquidityPool[2] ? liquidityPool[2] : ethSold;
  if (ethSold < 0n) {
    ethSold = 0n;
  }

  return ethSold;
};
