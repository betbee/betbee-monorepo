# Executes Genesis rounds. update with correct RPC url, operator address, operator private key, contract address
# price symbol and have the abi.json in the same directoy.

import json
from web3 import Web3
import requests
import time


# Initialize values 

# polygon mumbai testnet
url = "https://rpc-mumbai.maticvigil.com"

web3 = Web3(Web3.HTTPProvider(url))
operator_address =  "0xA7Fd4fF4A4AE73631cc313C092862c4793C534A6"
operator_private_key = "******"
contract_address = "0xa11Cb6142210F2505F402547723E74Cb4757e740"
price_url="https://api.binance.com/api/v3/ticker/price"
price_symbol="BTCUSDT"
gas = 100000
gasPrice = web3.toWei('10', 'gwei')
genesisStartTime = 1000


genesisCalled = False
contract_abi = json.loads(open("./abi.json", "r").read())
contract = web3.eth.contract(address=contract_address, abi=contract_abi)



def getNonce():
    nonce = web3.eth.getTransactionCount(operator_address)
    return nonce

def getPrice():
    params = {'symbol':price_symbol}
    r = requests.get(url = price_url, params = params)
    data = r.json();
    price = data['price']
    return price

def executeGenesis():
    genesis_create_tx = contract.functions.genesisCreateRound(genesisStartTime).buildTransaction({
        'nonce': getNonce(),
        'gas': gas,
        'gasPrice': gasPrice,
        'from': operator_address
        })

    signed_tx = web3.eth.account.sign_transaction(genesis_create_tx, operator_private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print("genesis create Tx Hash= " + web3.toHex(tx_hash))
    web3.eth.waitForTransactionReceipt(tx_hash)

    genesis_start_tx = contract.functions.genesisStartRound().buildTransaction({
        'nonce': getNonce(),
        'gas': gas,
        'gasPrice': gasPrice,
        'from': operator_address
        })

    signed_tx = web3.eth.account.sign_transaction(genesis_start_tx, operator_private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print("genesis start Tx Hash= " + web3.toHex(tx_hash))
    web3.eth.waitForTransactionReceipt(tx_hash)

    genesisCalled = True

#call execute round function method
executeGenesis()
