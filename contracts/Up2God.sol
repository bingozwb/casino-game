pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract Up2God {
    using SafeMath for uint;

    uint constant BET_AMOUNT_MIN = 0.01 ether;
    uint constant BET_AMOUNT_MAX = 1000 ether;
    uint constant SUPPORT_AMOUNT_PERCENT = 1;
    uint constant SUPPORT_AMOUNT_MIN = 0.0003 ether;
    uint constant JACKPOT_BET_MIN = 0.1 ether;
    uint constant JACKPOT_FEE = 0.001 ether;
    uint constant JACKPOT_MODULO = 1000;

    uint constant MAX_MODULO = 100;
    uint constant MAX_MASKABLE_MODULO = 40;
    uint constant MAX_BET_MASK = 2 ** MAX_MASKABLE_MODULO;
    uint constant EXPIRED_BLOCKS = 250;

    uint constant COUNTER_MULT = 0x0000000000002000000000100000000008000000000400000000020000000001;
    uint constant COUNTER_MASK = 0x0001041041041041041041041041041041041041041041041041041041041041;
    uint constant COUNTER_MODULO = 0x3F;

    uint public bankFund;
    uint public jackpotFund;
    uint public maxProfit;
    address public secretSigner;
    address public owner;
    address private newOwner;

    struct Bet {
        address player;
        uint placeBlockNumber;
        uint amount;
        uint rewardAmount;
        uint8 modulo;
        uint8 populationCount;
        uint40 mask;
    }

    mapping(uint => Bet) bets;

    event LogBetReward(address indexed addr, uint amount);
    event LogJackpotReward(address indexed addr, uint amount);
    event LogWithdrawFund(address indexed addr, uint amount);
    event LogRefund(address indexed addr, uint amount);

    constructor() payable public {
        // make sure every bet(large than BET_AMOUNT_MIN) can cover the fee
        uint min = BET_AMOUNT_MIN > JACKPOT_BET_MIN ? BET_AMOUNT_MIN : JACKPOT_BET_MIN;
        require(SUPPORT_AMOUNT_PERCENT < 100, "SUPPORT_AMOUNT_PERCENT out of range[0,100)");
        require((min.mul(SUPPORT_AMOUNT_PERCENT) / 100).add(JACKPOT_FEE) < min, "bet setting is not rational");

        owner = msg.sender;
        secretSigner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "only the owner can call this method");
        _;
    }

    function approveNewOwner(address _newOwner) onlyOwner external {
        require(_newOwner != owner, "newOwner is the same as the old");
        newOwner = _newOwner;
    }

    function acceptNewOwner() external {
        require(msg.sender == newOwner, "only the newOwner can accept");
        owner = newOwner;
    }

    function() payable public {

    }

    function setSecretSigner(address _secretSigner) onlyOwner external {
        require(_secretSigner != address(0), "address invalid");
        secretSigner = _secretSigner;
    }

    // max bet reward, set to zero means disable betting
    function setMaxProfit(uint _maxProfit) onlyOwner external {
        maxProfit = _maxProfit;
    }

    function increaseJackpotFund(uint _increase) onlyOwner external {
        require(_increase.add(bankFund).add(jackpotFund) <= address(this).balance, "funds not enough");
        jackpotFund = jackpotFund.add(_increase);
    }

    function withdrawFund(address _to, uint _amount) onlyOwner external {
        require(_amount.add(bankFund).add(jackpotFund) <= address(this).balance, "funds not enough");
        _to.transfer(_amount);

        emit LogWithdrawFund(_to, _amount);
    }

    function destroy() onlyOwner external {
        require(bankFund == 0, "all of bets should be done before destroy");
        selfdestruct(owner);
    }

    function placeBet(uint _betMask, uint _modulo, uint _expiredBlockNumber, uint _commit, uint8 _v, bytes32 _r, bytes32 _s) payable external {
        Bet storage bet = bets[_commit];
        uint amount = msg.value;
        uint populationCount;
        uint rewardAmount;
        uint jackpotFee;

        // validate args
        require(bet.player == address(0), "this bet is already exist");
        require(_betMask > 0 && _betMask < MAX_BET_MASK, "bet mask out of range");
        require(_modulo > 1 && _modulo < MAX_MODULO, "modulo out of range");
        require(block.number < _expiredBlockNumber, "this bet has expired");
        require(amount > BET_AMOUNT_MIN && amount < BET_AMOUNT_MAX, "bet amount out of range");
        bytes32 msgHash = keccak256(abi.encodePacked(_expiredBlockNumber, _commit));
        require(ecrecover(msgHash, _v, _r, _s) == secretSigner, "incorrect signer");

        (rewardAmount, jackpotFee, populationCount) = rewardHelper(amount, _betMask, _modulo);
        bankFund = bankFund.add(rewardAmount);
        jackpotFund = jackpotFund.add(jackpotFee);

        require(rewardAmount <= amount.add(maxProfit), "profit exceeds maxProfit limit");
        require(bankFund.add(jackpotFund) <= address(this).balance, "fund can not afford this bet");

        bet.player = msg.sender;
        bet.placeBlockNumber = block.number;
        bet.amount = amount;
        bet.rewardAmount = rewardAmount;
        bet.modulo = uint8(_modulo);
        bet.populationCount = uint8(populationCount);
        bet.mask = uint40(_betMask);
    }

    function settleBet(uint _reveal) external {
        // validate (commit/reveal) pair
        uint commit = uint(keccak256(abi.encodePacked(_reveal)));
        Bet storage bet = bets[commit];
        uint rewardAmount = 0;
        uint jackpotAmount = 0;
        uint placeBlockNumber = bet.placeBlockNumber;
        uint amount = bet.amount;
        uint modulo = bet.modulo;
        uint betMask = bet.mask;
        address player = bet.player;

        require(amount != 0, "bet status is not 'active'");
        require(block.number > placeBlockNumber, "settleBet should be invoked after placeBet");
        require(block.number <= placeBlockNumber + EXPIRED_BLOCKS, "bet expired");

        // set bet status to 'finish'
        bet.amount = 0;

        // RNG
        bytes32 entropy = keccak256(abi.encodePacked(_reveal, blockhash(placeBlockNumber)));
        // choose a winning choice within modulo
        uint winChoice = uint(entropy) % modulo;
        // if player's betMask match this winChoice
        if (modulo <= MAX_MASKABLE_MODULO) {
            if (2 ** winChoice & betMask != 0) {
                rewardAmount = bet.rewardAmount;
            }
        } else {
            if (winChoice <= betMask) {
                rewardAmount = bet.rewardAmount;
            }
        }
        bankFund = bankFund.sub(bet.rewardAmount);

        // calculate jackpot reward
        if (amount >= JACKPOT_BET_MIN && jackpotFund > 0) {
            if (uint(entropy) % JACKPOT_MODULO == 0) {
                jackpotAmount = jackpotFund;
                jackpotFund = 0;

                emit LogJackpotReward(player, jackpotAmount);
            }
        }

        // reward player
        uint totalAmount = rewardAmount.add(jackpotAmount) > 0 ? rewardAmount.add(jackpotAmount) : 1 wei;
        player.transfer(totalAmount);

        emit LogBetReward(player, rewardAmount);
    }

    function rewardHelper(uint _amount, uint _betMask, uint _modulo) pure private returns (uint rewardAmount, uint jackpotFee, uint populationCount) {
        if (_modulo < MAX_MASKABLE_MODULO) {
            populationCount = (_betMask * COUNTER_MULT & COUNTER_MASK) % COUNTER_MODULO;
        } else {
            require(_betMask < _modulo, "bet mask large than modulo");
            populationCount = _betMask;
        }

        require(populationCount > 0 && populationCount < _modulo, "winning rate out of range");

        uint supportAmount = _amount.mul(SUPPORT_AMOUNT_PERCENT) / 100;
        if (supportAmount < SUPPORT_AMOUNT_MIN) {
            supportAmount = SUPPORT_AMOUNT_MIN;
        }
        jackpotFee = _amount >= JACKPOT_BET_MIN ? JACKPOT_FEE : 0;
        rewardAmount = _amount.sub(supportAmount).sub(jackpotFee).mul(_modulo) / populationCount;
    }

    function refundBet(uint _commit) external {
        Bet storage bet = bets[_commit];
        uint amount = bet.amount;
        uint rewardAmount = bet.rewardAmount;
        uint placeBlockNumber = bet.placeBlockNumber;
        address player = bet.player;

        require(amount != 0, "bet status is not 'active'");
        require(block.number > placeBlockNumber + EXPIRED_BLOCKS, "this bet hasn't expired");

        // set bet status to 'finish'
        bet.amount = 0;

        // rollback bankFund and jackpotFund
        bankFund = bankFund.sub(rewardAmount);
        if (amount >= JACKPOT_BET_MIN) {
            jackpotFund = jackpotFund.sub(JACKPOT_FEE);
        }

        player.transfer(amount);

        emit LogRefund(player, amount);
    }

    function cleanBet(uint _commit) private {
        Bet storage bet = bets[_commit];

        require(bet.amount == 0 && block.number > bet.placeBlockNumber + EXPIRED_BLOCKS, "this bet status is not 'finish'");

        bet.player = address(0);
        bet.placeBlockNumber = 0;
        bet.rewardAmount = 0;
        bet.modulo = 0;
        bet.populationCount = 0;
        bet.mask = 0;
    }

    function cleanBets(uint[] _commits) public {
        for(uint i = 0; i < _commits.length; i++) {
            cleanBet(_commits[i]);
        }
    }

}
