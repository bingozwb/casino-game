const {web3, property, sendSignedTx, sendSignedTxSimple, getString, getBytes} = require('./contractUtil.js')

const contractJson = require('../build/contracts/TestUtil.json')
const contractAbi = contractJson.abi
const contractAddr = contractJson.networks[property.networkID].address
const contract = new web3.eth.Contract(contractAbi, contractAddr)

const reveals = ['0','1','2','3','4','5','6','7','8','9']

function getCommit(reveal) {
    return web3.utils.soliditySha3(reveal)
}

async function getResult(reveal, blockHash, modulo) {
    const data = contract.methods.getResult(reveal, blockHash, modulo).call()
        .then(data => {
            console.log('encodePack', data.encodePack)
            console.log('entropy', data.entropy)
            console.log('dice', data.dice)
        })
}

async function test() {
    getResult(reveals[0], '0x37269137f663459bf35394c8c272dd59b5fa424d72a2bd1dfb06b682246cbdc6', 2)
}

test()