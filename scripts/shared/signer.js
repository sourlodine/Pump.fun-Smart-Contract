const hre = require("hardhat");
const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");

function hashData(dataTypes, dataValues) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues);
  const hash = ethers.utils.keccak256(ethers.utils.arrayify(bytes));

  return hash;
}

function hashString(string) {
  return hashData(["string"], [string]);
}

const unsignedTransactionList = [];
const signedTransactions = {};

let app;

// to sign using an external wallet:
// - run `yarn app` in gmx-synthetics repo
// - go to http://localhost:5173/signer
// - connect a wallet and click on the "Sign" button

async function createSigningServer() {
  if (app) {
    return;
  }

  const port = 3030;

  app = express();
  app.use(cors());
  app.use(bodyParser.urlencoded({ extended: false }));
  app.use(bodyParser.json());

  const server = app.listen(port, () => {
    console.log(`server started at port ${port}`);
  });

  app.get("/", (req, res) => {
    res.contentType("text/plain");
    res.send(
      JSON.stringify({
        unsignedTransactionList,
        signedTransactions,
      })
    );
  });

  app.post("/completed", (req, res) => {
    console.log("transaction completed", JSON.stringify(req.body));
    signedTransactions[req.body.transactionKey] = req.body.transactionHash;
    res.send("ok");

    let hasPendingTransaction = false;
    for (const [index, { transactionKey }] of unsignedTransactionList.entries()) {
      if (signedTransactions[transactionKey] === undefined) {
        console.log(`pending transaction at index ${index}`)
        hasPendingTransaction = true;
        break;
      }
    }

    if (!hasPendingTransaction) {
      console.log("no pending transactions left, closing server")
      server.close();
      process.exit(1);
    }
  });
}

async function signExternally(unsignedTransaction) {
  createSigningServer();

  unsignedTransaction.chainId = hre.network.config.chainId;

  const unsignedTransactionStr = JSON.stringify(unsignedTransaction);
  const transactionKey = hashString(unsignedTransactionStr);
  unsignedTransactionList.push({ transactionKey, unsignedTransaction, timestamp: Date.now() });

  console.log("Transaction to be signed: ", unsignedTransactionStr);
}

module.exports = {
  signExternally
}
