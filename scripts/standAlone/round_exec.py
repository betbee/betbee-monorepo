# Executes rounds and house bet for bull and bear.

import json
from web3 import Web3
import requests
import time
import datetime


# Mumbai
url = "https://rpc-mumbai.maticvigil.com"

web3 = Web3(Web3.HTTPProvider(url))
operator_address =  "0xA7Fd4fF4A4AE73631cc313C092862c4793C534A6"
operator_private_key = "****"
contract_address = "0x5fD735492E5eB7f023EFfB885b2c6344B3D0402A"
price_url="https://api.binance.com/api/v3/ticker/price"
price_symbol="BTCUSDT"
gas = 500000
gasPrice = web3.toWei('50', 'gwei')

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
    return int(price.replace('.',''))

def executeRound():
    execute_round_tx = contract.functions.executeRound(getPrice()).buildTransaction({
        'nonce': getNonce(),
        'gas': gas,
        'gasPrice': gasPrice,
        'from': operator_address
        })

    signed_tx = web3.eth.account.sign_transaction(execute_round_tx, operator_private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print(str(datetime.datetime.now()) + " | Execute Round Tx Hash = " + web3.toHex(tx_hash))
    web3.eth.waitForTransactionReceipt(tx_hash)

#betbull
def house_betbull(roundId):
    house_betbull_tx = contract.functions.betBull(roundId).buildTransaction({
        'nonce' : getNonce(),
        'gas' : gas,
        'gasPrice' : gasPrice,
        'from' : operator_address,
        'value' : 10000000000000000
        })

    signed_tx = web3.eth.account.sign_transaction(house_betbull_tx, operator_private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print(str(datetime.datetime.now()) + " | House BetBull Tx Hash = " + web3.toHex(tx_hash))
    web3.eth.waitForTransactionReceipt(tx_hash)

#betbear
def house_betbear(roundId):
    house_betbear_tx = contract.functions.betBear(roundId).buildTransaction({
        'nonce' : getNonce(),
        'gas' : gas,
        'gasPrice' : gasPrice,
        'from' : operator_address,
        'value' : 10000000000000000
        })

    signed_tx = web3.eth.account.sign_transaction(house_betbear_tx, operator_private_key)
    tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print(str(datetime.datetime.now()) + " | House BetBear Tx Hash = " + web3.toHex(tx_hash))
    web3.eth.waitForTransactionReceipt(tx_hash)


#Execution sequel
executeRound()
time.sleep(10)
currentRoundId = contract.functions.currentRoundId().call()
house_betbull(currentRoundId+1)
house_betbear(currentRoundId+1)