// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PredictionAdministrator.sol";
import "./PriceManager.sol";

/**
 * @title BetBeePrediction
 */
contract BetBeePrediction is PredictionAdministrator {

    using SafeERC20 for IERC20;

    AggregatorV3Interface public oracle;
    uint256 public currentEpoch;
    uint256 public intervalSeconds = 300;
    uint256 public bufferSeconds = 30;

    bool public genesisLockOnce = false;
    bool public genesisStartOnce = false;

    struct BetInfo {
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 amountDispersed;
    }

    struct Round 
    {
        uint256 epoch;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 totalAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        int256 lockPrice;
        int256 closePrice;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 closeTimestamp;
        uint256 lockPriceTimestamp;
        uint256 closePriceTimestamp;
        bool closed;
        bool dispersed;
    }

    mapping(uint256 => Round) rounds;
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(address => uint256[]) public userRounds;
    mapping(uint256 => address[]) public usersInRounds;

    /**
     * @notice Constructor
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _treasuryFee: treasury fee (1000 = 10%)
     * @param _oracleAddress: oracle address
     */
    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _treasuryFee, address _oracleAddress) 
    PredictionAdministrator(_adminAddress, _minBetAmount, _treasuryFee) {
        oracle = AggregatorV3Interface(_oracleAddress);
    }

    /**
     * @notice Set buffer and interval (in seconds)
     * @dev Callable by admin
     * @param _bufferSeconds: Buffer in seconds
     * @param _intervalSeconds: Interval between rounds in seconds
     */
    function setBufferAndIntervalSeconds(uint256 _bufferSeconds, uint256 _intervalSeconds) external whenPaused onlyAdmin {
        require(_bufferSeconds < _intervalSeconds, "bufferSeconds must be less than intervalSeconds");
        bufferSeconds = _bufferSeconds;
        intervalSeconds = _intervalSeconds;
    }

    /**
     * @notice Determine if a round is valid for receiving bets
     * Round must have started and locked
     * Current timestamp must be within startTimestamp and closeTimestamp
     * @param epoch: epoch
     */
    function _bettable(uint256 epoch) internal view returns (bool) {
        return
            rounds[epoch].startTimestamp != 0 &&
            rounds[epoch].lockTimestamp != 0 &&
            block.timestamp > rounds[epoch].startTimestamp &&
            block.timestamp < rounds[epoch].closeTimestamp;
    }

   function _startRound(uint256 epoch) internal {
        Round storage round = rounds[epoch];
        round.startTimestamp = block.timestamp;
        round.lockTimestamp = block.timestamp + intervalSeconds;
        round.closeTimestamp = block.timestamp + (2 * intervalSeconds);
        round.epoch = epoch;
        round.totalAmount = 0;
    }

    function _safeStartRound(uint256 epoch) internal {
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
        require(rounds[epoch - 2].closeTimestamp != 0, "Can only start round after round n-2 has ended");
        require(block.timestamp >= rounds[epoch - 2].closeTimestamp, "Can only start new round after round n-2 closeTimestamp");
        _startRound(epoch);
    }
    
    function _safeLockRound(uint256 epoch, uint256 roundId, int256 price) internal {
        require(rounds[epoch].startTimestamp != 0, "Can only lock round after round has started");
        require(block.timestamp >= rounds[epoch].lockTimestamp, "Can only lock round after lockTimestamp");
        require(block.timestamp <= rounds[epoch].lockTimestamp + bufferSeconds, "Can only lock round within bufferSeconds");
        Round storage round = rounds[epoch];
        round.closeTimestamp = block.timestamp + intervalSeconds;
        round.lockPrice = price;
        //round.lockOracleId = roundId;
    }

    function _safeEndRound(uint256 epoch, uint256 roundId, int256 price) internal {
        require(rounds[epoch].lockTimestamp != 0, "Can only end round after round has locked");
        require(block.timestamp >= rounds[epoch].closeTimestamp, "Can only end round after closeTimestamp");
        require(block.timestamp <= rounds[epoch].closeTimestamp + bufferSeconds, "Can only end round within bufferSeconds");
        Round storage round = rounds[epoch];
        round.closePrice = price;
        //round.closeOracleId = roundId;
        //round.oracleCalled = true;
    }

    function _calculateRewards(uint256 epoch) internal {
        require(rounds[epoch].rewardBaseCalAmount == 0 && rounds[epoch].rewardAmount == 0, "Rewards already calculated");

        Round storage round = rounds[epoch];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        treasuryAmt = (round.totalAmount * treasuryFee) / 100;

        // Bull wins
        if (round.closePrice > round.lockPrice) {
            rewardBaseCalAmount = round.bullAmount;
            rewardAmount = round.totalAmount - treasuryAmt;
            treasuryAmount += treasuryAmt;
        }
        // Bear wins
        else if (round.closePrice < round.lockPrice) {
            rewardBaseCalAmount = round.bearAmount;
            rewardAmount = round.totalAmount - treasuryAmt;
            treasuryAmount += treasuryAmt;
        }
        // draw or tie
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
        }
        
        round.rewardAmount = rewardAmount;
        round.rewardBaseCalAmount = rewardBaseCalAmount;
    }

    function genesisStartRound() external whenNotPaused onlyOperator {
        require(!genesisStartOnce, "Can only run genesisStartRound once");
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisStartOnce = true;
    }

    // function genesisLockRound() external whenNotPaused onlyOperator {
    //     require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
    //     require(!genesisLockOnce, "Can only run genesisLockRound once");

    //     (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

    //     oracleLatestRoundId = uint256(currentRoundId);

    //     _safeLockRound(currentEpoch, currentRoundId, currentPrice);

    //     currentEpoch = currentEpoch + 1;
    //     _startRound(currentEpoch);
    //     genesisLockOnce = true;
    // }

    // function executeRound() external whenNotPaused onlyOperator {
    //     require(genesisStartOnce && genesisLockOnce, "Can only run after genesisStartRound and genesisLockRound is triggered");

    //     (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

    //     oracleLatestRoundId = uint256(currentRoundId);

    //     // CurrentEpoch refers to previous round (n-1)
    //     _safeLockRound(currentEpoch, currentRoundId, currentPrice);
    //     _safeEndRound(currentEpoch - 1, currentRoundId, currentPrice);
    //     _calculateRewards(currentEpoch - 1);

    //     // Increment currentEpoch to current round (n)
    //     currentEpoch = currentEpoch + 1;
    //     _safeStartRound(currentEpoch);
    // }

    function _safeTransfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: TRANSFER_FAILED");
    }

    function _refundable(uint256 epoch) internal view returns(bool) {
        return rounds[epoch].rewardBaseCalAmount == 0 &&
               rounds[epoch].rewardAmount == 0 &&
               rounds[epoch].lockPrice == rounds[epoch].closePrice;
    }

    function _disperse(uint256 epoch) internal whenNotPaused {
        require(rounds[epoch].startTimestamp != 0, "Round has not started");
        require(block.timestamp > rounds[epoch].closeTimestamp, "Round has not ended");
        require(rounds[epoch].totalAmount > 0, "No bets in the round");
        require(rounds[epoch].dispersed == false, "Already dispersed");
        
        //calculate rewards before disperse
        _calculateRewards(epoch);

        address[] memory usersInRound = usersInRounds[epoch];
        Round memory round = rounds[epoch];
        uint256 reward = 0;

        //bull disperse
        if(round.rewardBaseCalAmount == round.bullAmount) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[epoch][usersInRound[i]].bullAmount > 0) {
                    reward = (ledger[epoch][usersInRound[i]].bullAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[epoch][usersInRound[i]].amountDispersed = reward;

                    _safeTransfer(usersInRound[i], reward);
                }
            }
        }

        //bear disperse
        else if(round.rewardBaseCalAmount == round.bearAmount) {
            for (uint256 i =0; i < usersInRound.length; i++) {
                if(ledger[epoch][usersInRound[i]].bearAmount > 0) {
                    reward = (ledger[epoch][usersInRound[i]].bearAmount * round.rewardAmount) / round.rewardBaseCalAmount;
                    ledger[epoch][usersInRound[i]].amountDispersed = reward;
                    _safeTransfer(usersInRound[i], reward);
                }
            }
        }

        //refund if tied round
        else if(_refundable(epoch)) {
            uint256 userTotalBetAmount = 0;
            uint256 userTotalRefund = 0;
            for (uint256 i =0; i < usersInRound.length; i++) {
                userTotalBetAmount = ledger[epoch][usersInRound[i]].bullAmount + ledger[epoch][usersInRound[i]].bearAmount;

                if(userTotalBetAmount > 0) {
                    userTotalRefund = userTotalBetAmount - ((userTotalBetAmount * treasuryFee) / 100);
                    ledger[epoch][usersInRound[i]].amountDispersed = userTotalRefund;
                    _safeTransfer(usersInRound[i], userTotalRefund);
                }
            }
        }
        
    }

    function betBull(uint256 epoch) external payable whenNotPaused nonReentrant notContract {
        require(epoch == currentEpoch, "Bet is too early/late");
        require(_bettable(epoch), "Round not bettable");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[epoch][msg.sender];
        betInfo.bullAmount = betInfo.bullAmount + amount;

        if(ledger[epoch][msg.sender].bullAmount == 0 && ledger[epoch][msg.sender].bearAmount == 0) {
        userRounds[msg.sender].push(epoch);
        usersInRounds[epoch].push(msg.sender);
        }
    }

    function betBear(uint256 epoch) external payable whenNotPaused nonReentrant notContract {
        require(epoch == currentEpoch, "Bet is too early/late");
        require(_bettable(epoch), "Round not bettable");
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        BetInfo storage betInfo = ledger[epoch][msg.sender];
        betInfo.bearAmount = betInfo.bearAmount + amount;
        
        if(ledger[epoch][msg.sender].bullAmount == 0 && ledger[epoch][msg.sender].bearAmount == 0) {
        userRounds[msg.sender].push(epoch);
        usersInRounds[epoch].push(msg.sender);
        }
    }

}
