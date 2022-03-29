const ethers = require("ethers");
const axios = require('axios');

const priceURL = "https://api.binance.com/api/v3/klines";
const symbol = "BTCUSDT";

const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const address = "0xc3721b65927d12db143f1aefe452f740a03909ce";
const abi = [
  {
    "inputs": [],
    "name": "getCurrentRoundEndTimestamp",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs":[
      {
        "internalType":"int256",
        "name":"_price",
        "type":"int256"
      }
    ],
    "name":"executeRound",
    "outputs":[],
    "stateMutability":"nonpayable",
    "type":"function"
  }
];

exports.handler = async function(event) {
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "safeLow" });
  const contract = new ethers.Contract(address, abi, signer);
  
  const currentRoundEndTimestamp = await contract.getCurrentRoundEndTimestamp();
  if((currentRoundEndTimestamp) <= Date.now()){
  	let price = await getPrice(currentRoundEndTimestamp);
  	const tx = await contract.executeRound(price);
  	console.log(`Round Execution Tx:  ${tx.hash} with Price: ${price}`);
  }
}

async function getPrice(currentRoundEndTimestamp) {
  let response = await axios.get(priceURL, {
    params: {
      symbol: symbol,
      interval: '1m',
      limit: '1',
      startTime: currentRoundEndTimestamp.toString(),
      endTime: (currentRoundEndTimestamp + 59999).toString()
    }
  });
  let data = response.data;
  let price = parseInt(data[0][1].replace('.',''));
  return price;
}
