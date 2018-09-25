pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract Test {
    using SafeMath for uint;

    bytes32 public str;
    uint public num = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe;

    constructor() public {
        str = "str";
        verifyCode[0x243d416DEF4fA6eF0842837d5F72D51d7AF36791] = "vc";
        verifyCode[0x108A6a4a614d1a1BA44ba7720135097a6ffeF8b0] = "108A6a4a";
        for (uint i = 0; i < 9; i++) {
            verifyCodes.push(bytes32(i));
        }
    }

    function testExternal() external returns (bytes32 s) {
        str = "hello word";
        return str;
    }

    function testRevert(uint one, uint two) public {
        testRevertInter(two);
        require(one > 0, "revert one");
        str = "one";
    }

    function testRevertInter(uint two) public {
        require(two > 0, "revert two");
        str = "two";
    }

    uint constant POPCNT_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
    uint constant POPCNT_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
    uint constant POPCNT_MODULO = 0x3F;
    uint public multResult;
    uint public multMaskResult;
    uint public rollUnder;

    function getRollUnder(uint betMask) public returns (uint r) {
        rollUnder = ((betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
        return rollUnder;
    }

    function getMMM(uint betMask) public returns (uint m, uint mm, uint mmm) {
        multResult = betMask * POPCNT_MULT;
        multMaskResult = (betMask * POPCNT_MULT) & POPCNT_MASK;
        rollUnder = ((betMask * POPCNT_MULT) & POPCNT_MASK) % POPCNT_MODULO;
        return (multResult, multMaskResult, rollUnder);
    }

    bytes public encodePack;
    bytes32 public entropy;
    uint public dice;

    function getResult(uint reveal, bytes32 blockHash, uint modulo) public returns (bytes32 bh, bytes ep, bytes32 e, uint d) {
        encodePack = abi.encodePacked(reveal, blockHash);
        entropy = keccak256(encodePack);
        dice = uint(entropy) % modulo;
        return (blockHash, encodePack, entropy, dice);
    }

    function getAndAdd() public returns (uint r) {
        return num++;
    }

    function getEcrecover(bytes32 signatureHash, uint8 v, bytes32 r, bytes32 s) pure public returns (address sig) {
        return ecrecover(signatureHash, v, r, s);
    }

    function getHash(bytes32 message) pure public returns (bytes ep, bytes32 msgHash) {
        return (abi.encodePacked(message), keccak256(abi.encodePacked(message)));
    }


    //    uint8 ts = 1;
    function testGasUsed() public {
        str = bytes32(1);
    }

    function testDiv(uint a) public returns (uint result) {
        //        str = bytes32(a.sub(b).sub(c).mul(d) / e / e);
        str = bytes32(a);
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
//        rs.length = 10;
        for (uint i = 0; i < 10; i++) {
            random = uint(keccak256(abi.encodePacked(pk, now, i))) % verifyCodes.length;
            rs[i] = random;
//            bytes32 tempR = verifyCodes[random];
//            bytes32 tempZ = verifyCodes[0];
//            verifyCodes[random] = tempZ;
//            verifyCodes[0] = tempR;
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

    function testUint(uint number) pure public returns (uint8 result) {
        result = uint8(number);
    }

}
