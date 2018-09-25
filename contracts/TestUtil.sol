pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract TestUtil {
    using SafeMath for uint;

    constructor() public {
    }

    uint constant POPCNT_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
    uint constant POPCNT_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
    uint constant POPCNT_MODULO = 0x3F;

    function getRollUnder(uint betMask) public returns (uint) {
        return ((betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
    }

    function getMMM(uint betMask) public returns (uint m, uint mm, uint mmm) {
        m = betMask * POPCNT_MULT;
        mm = (betMask * POPCNT_MULT) & POPCNT_MASK;
        mmm = ((betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
    }

    function getResult(uint reveal, bytes32 blockHash, uint modulo) public returns (bytes encodePack, bytes32 entropy, uint dice) {
        encodePack = abi.encodePacked(reveal, blockHash);
        entropy = keccak256(encodePack);
        dice = uint(entropy) % modulo;
    }

    function getEcrecover(bytes32 msgHash, uint8 v, bytes32 r, bytes32 s) pure public returns (address) {
        return ecrecover(msgHash, v, r, s);
    }

    function getHash(bytes32 message) pure public returns (bytes, bytes32) {
        return (abi.encodePacked(message), keccak256(abi.encodePacked(message)));
    }



    mapping(address => bytes32) private verifyCode;
    address public sender;

    function getVerifyCode() public returns (address, bytes32) {
        sender = msg.sender;
        require(msg.sender == 0x108A6a4a614d1a1BA44ba7720135097a6ffeF8b0, "only voter allowed");
        return (msg.sender, verifyCode[msg.sender]);
    }

    address[] public voters;
    bytes32[] public verifyCodes;

    function createVerifyCode() external returns (uint[10]) {
        bytes32 pk = blockhash(block.number);
        uint random;
        uint[10] memory rs;
        for (uint i = 0; i < 10; i++) {
            random = uint(keccak256(abi.encodePacked(pk, now, i))) % verifyCodes.length;
            rs[i] = random;
            bytes32 temp = verifyCodes[random];
            verifyCodes[random] = verifyCodes[0];
            verifyCodes[0] = temp;
        }
        rs[0] = gasleft();
        rs[1] = gasleft();
        return rs;
    }

    function getVerifyCodes() view public returns (bytes32[]){
        return verifyCodes;
    }

}
