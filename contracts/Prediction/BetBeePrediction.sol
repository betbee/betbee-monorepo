// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PredictionAdministrator.sol";
import "./Price.sol";

/**
 * @title BetBeePrediction
 */
contract BetBeePrediction is PredictionAdministrator {

    using SafeERC20 for IERC20;

    AggregatorV3Interface public oracle;
    uint256 public currentroundId;

    enum BetPosition {Bear, Bull}

    struct BetInfo {
        BetPosition position;
        uint256 amount;
    }

    struct Round {
        uint256 roundId;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 closeTimestamp;
        int256 lockPrice;
        int256 closePrice;
        uint256 lockOracleId;
        uint256 closeOracleId;
        uint256 totalAmount;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        bool oracleCalled;
    }

    mapping(uint256 => Round) rounds;
    mapping(uint256 => mapping(address => BetInfo)) public ledger;

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
     * @notice Determine if a round is valid for receiving bets
     * Round must have started and locked
     * Current timestamp must be within startTimestamp and closeTimestamp
     * @param roundId: round Id
     */
    function _bettable(uint256 roundId) internal view returns (bool) {
        return
            rounds[roundId].startTimestamp != 0 &&
            rounds[roundId].lockTimestamp != 0 &&
            block.timestamp > rounds[roundId].startTimestamp &&
            block.timestamp < rounds[roundId].closeTimestamp;
    }

    /**
     * @notice Disperse reward amount to the users
     * @param bidders[]: array of user address
     */
    function disperse(address[] memory bidders) external nonReentrant notContract {
        require(bidders.length > 0, "No bidders Won");

    }

}