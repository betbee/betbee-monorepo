// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./PredictionAdministrator.sol";

/**
 * @title BetBeePrediction
 */
contract BetBeePrediction is PredictionAdministrator {

    uint256 public currentRoundId;
    uint256 public roundTime = 300000; //5 minutes of round in milliseconds
    uint256 public genesisStartTimestamp;

    bool public genesisStartOnce = false;
    bool public genesisCreateOnce = false;

    enum RoundState {UNKNOWN, CREATED, STARTED, ENDED, DISBURSED, CANCELLED}

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
        uint256 amountDisbursed;
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(address => uint256[]) public userRounds;
    mapping(uint256 => address[]) public usersInRounds;

    event BetbeePaused(uint256 currentRoundId);
    event BetbeeUnPaused(uint256 currentRoundId);

    event CreateRound(uint256 indexed roundId);
    event StartRound(uint256 indexed roundId, int256 startPrice);
    event EndRound(uint256 indexed roundId, int256 endPrice);
    event CancelRound(uint256 indexed roundId);
    event DisburseUser(uint256 indexed roundId, address indexed recipient, uint256 amountDisbursed, uint256 timestamp);
    event Disburse(uint256 indexed roundId);
    event BetBull(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetBear(address indexed sender, uint256 indexed roundId, uint256 amount);
    event RewardsCalculated(uint256 indexed roundId, uint256 rewardBaseCalAmount, uint256 rewardAmount, uint256 treasuryAmount);
    event Refund(uint256 indexed roundId, address indexed recipient, uint256 refundDisbursed, uint256 timestamp);

    /**
     * @notice Pause the contract
     * @dev Callable by admin
     */
    function pause() external whenNotPaused onlyAdmin {
        if (rounds[currentRoundId].roundState != RoundState.CANCELLED) {
            cancelAndRefundRound(currentRoundId);
        }

        _pause();

        emit BetbeePaused(currentRoundId);
    }

    /**
     * @notice Unpause the contract
     * @dev Callable by admin
     */
    function unPause() external whenPaused onlyAdmin {
        _unpause();

        emit BetbeeUnPaused(currentRoundId);
    } 

    /**
    * @notice Create Round
    * @param roundId: round Id 
    */
    function _createRound(uint256 roundId) internal {
        require(rounds[roundId].roundId == 0, "Round already exists");
        rounds[roundId].roundId = roundId;
        rounds[roundId].startTimestamp = (genesisStartTimestamp + (roundTime * roundId));
        rounds[roundId].endTimestamp = rounds[roundId].startTimestamp + roundTime;
        rounds[roundId].roundState = RoundState.CREATED;

        emit CreateRound(roundId);
    }

    /**
    * @notice Start Round
    * @param roundId: round Id 
    * @param startPrice: startPrice
    */
   function _startRound(uint256 roundId, int256 startPrice) internal {
       require(rounds[roundId].roundState == RoundState.CREATED, "Round should be created");
       require(rounds[roundId].startTimestamp <= (block.timestamp * 1000), "Too early to start the round");
       rounds[roundId].startPrice = startPrice;
       rounds[roundId].roundState = RoundState.STARTED;

       emit StartRound(roundId, startPrice);
    }

    /**
    * @notice End Round
    * @param roundId: round Id 
    * @param endPrice: endPrice
    */
    function _endRound(uint256 roundId, int256 endPrice) internal {
        require(rounds[roundId].roundState == RoundState.STARTED, "Round is not started or ended already");
        require(rounds[roundId].endTimestamp <= (block.timestamp * 1000), "Too early to end the round");
        rounds[roundId].endPrice = endPrice;
        rounds[roundId].roundState = RoundState.ENDED;

        emit EndRound(roundId, endPrice);
    }

    /**
    * @notice Cancel and Refund Round
    * @param _roundId: round Id
    */
    function cancelAndRefundRound(uint256 _roundId) public onlyOperator notContract {
        require(rounds[_roundId].roundState == RoundState.STARTED, "Round is ended/cancelled already");
        rounds[_roundId].startPrice = 0;
        rounds[_roundId].endPrice = 0;
        rounds[_roundId].rewardBaseCalAmount = 0;
        rounds[_roundId].rewardAmount = 0;
        rounds[_roundId].roundState = RoundState.CANCELLED;

        if(rounds[_roundId].totalAmount > 0) {
            _refund(_roundId);
        }
        

        emit CancelRound(_roundId);
    }

    /**
    * @notice Calculate Rewards for the round
    * @param roundId: round Id 
    */
    function _calculateRewards(uint256 roundId) internal {
        require(rounds[roundId].roundState == RoundState.ENDED, "Round is not ended or already disbursed");
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
    * @notice Refund the round
    * @param roundId: round Id
    */
    function _refund(uint256 roundId) internal {
            uint256 userTotalBetAmount = 0;
            uint256 userTotalRefund = 0;
            address[] storage usersInRound = usersInRounds[roundId];
            for (uint256 i =0; i < usersInRound.length; i++) {
                userTotalBetAmount = ledger[roundId][usersInRound[i]].bullAmount + ledger[roundId][usersInRound[i]].bearAmount;

                if(userTotalBetAmount > 0) {
                    userTotalRefund = userTotalBetAmount - ((userTotalBetAmount * treasuryFee) / 100);
                    ledger[roundId][usersInRound[i]].amountDisbursed = userTotalRefund;
                    _safeTransfer(usersInRound[i], userTotalRefund);
                    emit Refund(roundId, usersInRound[i], userTotalRefund, (block.timestamp * 1000));
                }
            }
    }

    /**
    * @notice Disburse Rewards for the round
    * @param roundId: round Id 
    */
    function _disburse(uint256 roundId) internal whenNotPaused {
        require(rounds[roundId].roundState == RoundState.ENDED, "Round is not ended or already disbursed");
        
        //calculate rewards before disburse
        _calculateRewards(roundId);

        address[] storage usersInRound = usersInRounds[roundId];
        Round storage round = rounds[roundId];
        uint256 reward = 0;

        round.roundState = RoundState.DISBURSED;

        //bull disburse
        if(round.rewardBaseCalAmount == round.bullAmount && round.rewardBaseCalAmount > 0) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[roundId][usersInRound[i]].bullAmount > 0) {
                    reward = (ledger[roundId][usersInRound[i]].bullAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[roundId][usersInRound[i]].amountDisbursed = reward;
                    _safeTransfer(usersInRound[i], reward);

                    emit DisburseUser(roundId, usersInRound[i], reward, (block.timestamp * 1000));
                }
            }
        }

        //bear disburse
        else if(round.rewardBaseCalAmount == round.bearAmount && round.rewardBaseCalAmount > 0) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[roundId][usersInRound[i]].bearAmount > 0) {
                    reward = (ledger[roundId][usersInRound[i]].bearAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[roundId][usersInRound[i]].amountDisbursed = reward;
                    _safeTransfer(usersInRound[i], reward);

                    emit DisburseUser(roundId, usersInRound[i], reward, (block.timestamp * 1000));
                }
            }
        }

        //refund if tied round
        else if(_refundable(roundId)) {
            _refund(roundId);
        }

        //house wins
        else {
            treasuryAmount += round.rewardAmount;
        }

        emit Disburse(roundId);
    }

    /**
    * @notice Bet Bull position
    * @param _roundId: Round Id 
    */
    function betBull(uint256 _roundId) external payable whenNotPaused nonReentrant notContract {
        require(rounds[_roundId].roundState == RoundState.CREATED, "Bet is too early/late");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[_roundId];
        BetInfo storage betInfo = ledger[_roundId][msg.sender];

        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        if(ledger[_roundId][msg.sender].bullAmount == 0 && ledger[_roundId][msg.sender].bearAmount == 0) {
            userRounds[msg.sender].push(_roundId);
            usersInRounds[_roundId].push(msg.sender);
        }

        betInfo.bullAmount = betInfo.bullAmount + amount;

        emit BetBull(msg.sender, _roundId, msg.value);
    }

    /**
    * @notice Bet Bear position
    * @param _roundId: Round Id 
    */
    function betBear(uint256 _roundId) external payable whenNotPaused nonReentrant notContract {
        require(rounds[_roundId].roundState == RoundState.CREATED, "Bet is too early/late");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[_roundId];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[_roundId][msg.sender];
        if(ledger[_roundId][msg.sender].bullAmount == 0 && ledger[_roundId][msg.sender].bearAmount == 0) {
            userRounds[msg.sender].push(_roundId);
            usersInRounds[_roundId].push(msg.sender);
        }

        betInfo.bearAmount = betInfo.bearAmount + amount;

        emit BetBear(msg.sender, _roundId, msg.value);
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
    function genesisStartRound(int256 _price) external whenNotPaused onlyOperator notContract {
        require(genesisCreateOnce, "Can only run after genesisCreateRound is triggered");
        require(!genesisStartOnce, "Can only run genesisStartRound once");
        _startRound(currentRoundId, _price);

        //create next 2 rounds to be able to bet by users
        _createRound(currentRoundId+1);
        _createRound(currentRoundId+2);

        genesisStartOnce = true;
    }

    /**
    * @notice Execute round
    * @dev Callable by Operator
    * @param _price: price
    */
    function executeRound(int256 _price) external whenNotPaused onlyOperator notContract {
        require(genesisCreateOnce && genesisStartOnce, "Can only run after genesisStartRound and genesisLockRound is triggered");

        // Start next round
        _startRound(currentRoundId+1, _price);

        // End and Disburse current round
        if(rounds[currentRoundId].roundState != RoundState.CANCELLED) {
            _endRound(currentRoundId, _price);
            if(rounds[currentRoundId].totalAmount > 0) {
                _disburse(currentRoundId);
            }
        }

        // Create a new round n+3
        _createRound(currentRoundId+3);

        // Point currentRoundId to next round
        currentRoundId = currentRoundId + 1;
    }

    /**
    * @notice returns endTime of currentRoundId 
    */
    function getCurrentRoundEndTimestamp() external view returns(uint256) {
        return rounds[currentRoundId].endTimestamp;
    }
}
