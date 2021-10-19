// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./PredictionAdministrator.sol";
import "./PriceManager.sol";

/**
 * @title BetBeePrediction
 */
contract BetBeePrediction is PredictionAdministrator, PriceManager {

    address public oracleAddress;
    uint256 public currentRoundId;
    uint256 public roundTime = 300; //5 mintues of round
    uint256 public genesisStartTimestamp;

    bool public genesisStartOnce = false;
    bool public genesisCreateOnce = false;

    enum RoundState {UNKNOWN, CREATED, STARTED, ENDED, DISPERSED}

    struct Round 
    {
        uint256 roundId;
        RoundState roundState;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 totalAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        int256 startPrice;
        int256 endPrice;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    struct BetInfo {
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 amountDispersed;
    }

    mapping(uint256 => Round) rounds;
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(address => uint256[]) public userRounds;
    mapping(uint256 => address[]) public usersInRounds;

    event NewOracle(address oracleAddress);
    event Paused(uint256 currentRoundId);
    event UnPaused(uint256 currentRoundId);

    event CreateRound(uint256 indexed roundId);
    event StartRound(uint256 indexed roundId);
    event EndRound(uint256 indexed roundId);
    event DisperseRound(uint256 indexed roundId, address indexed recipient, uint256 amountDispersed, uint256 timestamp);
    event BetBull(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetBear(address indexed sender, uint256 indexed roundId, uint256 amount);
    event RewardsCalculated(uint256 indexed roundId, uint256 rewardBaseCalAmount, uint256 rewardAmount, uint256 treasuryAmount);
    event Refund(uint256 indexed roundId, address indexed recipient, uint256 refundDispersed, uint256 timestamp);

    /**
     * @notice Constructor
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _treasuryFee: treasury fee (1000 = 10%)
     * @param _oracleAddress: oracle address
     * @param _assetPair: asset pair
     */
    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _treasuryFee, address _oracleAddress, string memory _assetPair) 
    PredictionAdministrator(_adminAddress, _minBetAmount, _treasuryFee)
    PriceManager(_oracleAddress, _assetPair) {
    }

    /**
     * @notice Pause the contract
     * @dev Callable by admin
     */
    function pause() external whenNotPaused onlyAdmin {
        _pause();

        emit Paused(currentRoundId);
    }

    /**
     * @notice Unpuase the contract
     * @dev Callable by admin
     */
    function unPause() external whenPaused onlyAdmin {
        genesisCreateOnce = false;
        genesisStartOnce = false;
        _unpause();

        emit Paused(currentRoundId);
    }

    /**
    * @notice Set oracle address
    * @dev callable by admin
    * @param _oracleAddress: new oracle address
    */
    function setOracleAddress(address _oracleAddress) external onlyAdmin {
        require(_oracleAddress != address(0), "Invalid Oracle address");
        oracleAddress = _oracleAddress;

        emit NewOracle(_oracleAddress);
    }

    /**
    * @notice Create Round
    * @param roundId: round Id 
    */
    function _createRound(uint256 roundId) internal {
        require(rounds[roundId].roundId == 0, "Round already exists");
        Round storage round = rounds[roundId];
        round.roundId = roundId;
        round.startTimestamp = (genesisStartTimestamp + (roundTime * roundId));
        round.endTimestamp = round.startTimestamp + roundTime;
        round.roundState = RoundState.CREATED;

        emit CreateRound(roundId);
    }

    /**
    * @notice Start Round
    * @param roundId: round Id 
    */
   function _startRound(uint256 roundId, int256 price) internal {
       require(rounds[roundId].roundState == RoundState.CREATED, "Round should be created");
       require(rounds[roundId].startTimestamp >= block.timestamp, "Too late to start the round");
       Round storage round = rounds[roundId];
       round.startPrice = price;
       round.roundState = RoundState.STARTED;

       emit StartRound(roundId);
    }

    /**
    * @notice End Round
    * @param roundId: round Id 
    */
    function _endRound(uint256 roundId, int256 price) internal {
        require(rounds[roundId].roundState == RoundState.STARTED, "Round is not started or ended already");
        require(rounds[roundId].endTimestamp <= block.timestamp, "Too early to end the round");
        Round storage round = rounds[roundId];
        round.endPrice = price;
        round.roundState = RoundState.ENDED;

        emit EndRound(roundId);
    }

    /**
    * @notice Calculate Rewards for the round
    * @param roundId: round Id 
    */
    function _calculateRewards(uint256 roundId) internal {
        require(rounds[roundId].roundState == RoundState.ENDED, "Round is not ended or already dispersed");
        Round storage round = rounds[roundId];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        treasuryAmt = (round.totalAmount * treasuryFee) / 100;

        // Bull wins
        if (round.endPrice > round.startPrice) {
            rewardBaseCalAmount = round.bullAmount;
            rewardAmount = round.totalAmount - treasuryAmt;
            treasuryAmount += treasuryAmt;
        }
        // Bear wins
        else if (round.endPrice < round.startPrice) {
            rewardBaseCalAmount = round.bearAmount;
            rewardAmount = round.totalAmount - treasuryAmt;
            treasuryAmount += treasuryAmt;
        }
        // draw or tie
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmount += treasuryAmt;
        }
        
        round.rewardAmount = rewardAmount;
        round.rewardBaseCalAmount = rewardBaseCalAmount;

        emit RewardsCalculated(roundId, rewardBaseCalAmount, rewardAmount, treasuryAmount);
    }

    /**
    * @notice Transfer 
    * @param to: recipient address
    * @param value: value 
    */
    function _safeTransfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: TRANSFER_FAILED");
    }

    /**
    * @notice Check whether the round is refundable
    * @param roundId: round Id 
    */
    function _refundable(uint256 roundId) internal view returns(bool) {
        return rounds[roundId].rewardBaseCalAmount == 0 &&
               rounds[roundId].rewardAmount == 0 &&
               rounds[roundId].startPrice == rounds[roundId].endPrice;
    }

    /**
    * @notice Disperse Rewards for the round
    * @param roundId: round Id 
    */
    function _disperse(uint256 roundId) internal whenNotPaused {
        require(rounds[roundId].roundState == RoundState.ENDED, "Round is not ended or already dispersed");
        require(rounds[roundId].totalAmount > 0, "No bets in the round");
        
        //calculate rewards before disperse
        _calculateRewards(roundId);

        address[] storage usersInRound = usersInRounds[roundId];
        Round storage round = rounds[roundId];
        uint256 reward = 0;

        round.roundState = RoundState.DISPERSED;

        //bull disperse
        if(round.rewardBaseCalAmount == round.bullAmount) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[roundId][usersInRound[i]].bullAmount > 0) {
                    reward = (ledger[roundId][usersInRound[i]].bullAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[roundId][usersInRound[i]].amountDispersed = reward;
                    _safeTransfer(usersInRound[i], reward);

                    emit DisperseRound(roundId, usersInRound[i], reward, block.timestamp);
                }
            }
        }

        //bear disperse
        else if(round.rewardBaseCalAmount == round.bearAmount) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[roundId][usersInRound[i]].bearAmount > 0) {
                    reward = (ledger[roundId][usersInRound[i]].bearAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[roundId][usersInRound[i]].amountDispersed = reward;
                    _safeTransfer(usersInRound[i], reward);

                    emit DisperseRound(roundId, usersInRound[i], reward, block.timestamp);
                }
            }
        }

        //refund if tied round
        else {
            require(_refundable(roundId), "The round is not refundable");
            uint256 userTotalBetAmount = 0;
            uint256 userTotalRefund = 0;
            for (uint256 i =0; i < usersInRound.length; i++) {
                userTotalBetAmount = ledger[roundId][usersInRound[i]].bullAmount + ledger[roundId][usersInRound[i]].bearAmount;

                if(userTotalBetAmount > 0) {
                    userTotalRefund = userTotalBetAmount - ((userTotalBetAmount * treasuryFee) / 100);
                    ledger[roundId][usersInRound[i]].amountDispersed = userTotalRefund;
                    _safeTransfer(usersInRound[i], userTotalRefund);

                    emit Refund(roundId, usersInRound[i], userTotalRefund, block.timestamp);
                }
            }
        }
    }

    /**
    * @notice Bet Bull position
    * @param roundId: Round Id 
    */
    function betBull(uint256 roundId) external payable whenNotPaused nonReentrant notContract {
        require(rounds[roundId].roundState == RoundState.CREATED, "Bet is too early/late");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        BetInfo storage betInfo = ledger[roundId][msg.sender];

        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        if(ledger[roundId][msg.sender].bullAmount == 0 && ledger[roundId][msg.sender].bearAmount == 0) {
            userRounds[msg.sender].push(roundId);
            usersInRounds[roundId].push(msg.sender);
        }

        betInfo.bullAmount = betInfo.bullAmount + amount;

        emit BetBull(msg.sender, roundId, msg.value);
    }

    /**
    * @notice Bet Bear position
    * @param roundId: Round Id 
    */
    function betBear(uint256 roundId) external payable whenNotPaused nonReentrant notContract {
        require(rounds[roundId].roundState == RoundState.CREATED, "Bet is too early/late");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[roundId][msg.sender];
        if(ledger[roundId][msg.sender].bullAmount == 0 && ledger[roundId][msg.sender].bearAmount == 0) {
            userRounds[msg.sender].push(roundId);
            usersInRounds[roundId].push(msg.sender);
        }

        betInfo.bearAmount = betInfo.bearAmount + amount;

        emit BetBear(msg.sender, roundId, msg.value);
    }

    /**
    * @notice Create Genesis round
    * @dev callable by Operator
    * @param _genesisStartTimestamp: genesis round start timestamp
    */
    function genesisCreateRound(uint256 _genesisStartTimestamp) external whenNotPaused onlyOperator notContract {
        require(!genesisCreateOnce, "Can only run genesisCreateRound once");
        currentRoundId = 0;
        genesisStartTimestamp = _genesisStartTimestamp;
        _createRound(currentRoundId);
        genesisCreateOnce = true;
    }

    /**
    * @notice Start Genesis round
    * @dev callable by Operator
    */
    function genesisStartRound() external whenNotPaused onlyOperator notContract {
        require(genesisCreateOnce, "Can only run after genesisCreateRound is triggered");
        require(!genesisStartOnce, "Can only run genesisStartRound once");
        int256 price = _getPriceByTimestamp(genesisStartTimestamp);
        _startRound(currentRoundId, price);

        //create next 3 rounds to be able to bet by users
        _createRound(currentRoundId+1);
        _createRound(currentRoundId+2);
        _createRound(currentRoundId+3);

        genesisStartOnce = true;
    }

    /**
    * @notice Execute round
    * @dev Callable by Operator
    */
    function executeRound() external whenNotPaused onlyOperator notContract {
        require(genesisCreateOnce && genesisStartOnce, "Can only run after genesisStartRound and genesisLockRound is triggered");

        // currentRoundId refers to current round n
        // fetch price to end current round and start new round
        int256 price = _getPriceByTimestamp(rounds[currentRoundId].endTimestamp);

        // Start next round
        _startRound(currentRoundId+1, price);
        
        // End and Disperse current round
        _endRound(currentRoundId, price);
        _disperse(currentRoundId);

        // Create a new round n+4
        _createRound(currentRoundId+4);

        // Point currentRoundId to next round
        currentRoundId = currentRoundId + 1;
    }
}
