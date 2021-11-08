// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./DiceAdministrator.sol";

/**
 * @title BetBeeDice
 */
contract BetBeeDice is DiceAdministrator {

    enum BetType {UNKNOWN, TWOTOSIX, SEVEN, EIGHTTOTWELVE}
    enum BetStatus {UNKNOWN, ROLLED, DISPERSED}
    uint256 currentBetId=0;

    struct BetInfo {
        uint256 betId;
        address user;
        uint256 betAmount;
        BetType betType;
        BetType winType;
        uint256 disperesedAmount;
        BetStatus status;
    }

    mapping(uint256 => BetInfo) public bets;
    mapping(address => uint256[]) public userBets;

    event Paused(uint256 timestamp);
    event UnPaused(uint256 timestamp);

    event Bet(address indexed sender, BetType betType, uint256 _amount);
    event DiceRolled(address indexed sender, BetType userBetType, BetType winType);
    event Disperesed(address indexed sender, uint256 amount);

    /**
     * @notice Constructor
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _maxBetAmount: maximum bet amounts (in wei)
     * @param _minVRFBetAmount: minimum bet VRF amounts (in wei)
     * @param _treasuryFee: treasury fee 3 (3%)
     */
    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _minVRFBetAmount, uint256 _treasuryFee) 
    DiceAdministrator(_adminAddress, _minBetAmount, _maxBetAmount, _minVRFBetAmount, _treasuryFee) {

    }

    /**
     * @notice Pause the contract
     * @dev Callable by admin
     */
    function pause() external whenNotPaused onlyAdmin {
        _pause();

        emit Paused(block.timestamp);
    }

    /**
     * @notice Unpuase the contract
     * @dev Callable by admin
     */
    function unPause() external whenPaused onlyAdmin {
        _unpause();

        emit Paused(block.timestamp);
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

    function _getRandomNumber(bool useVRF) internal pure returns(uint8) {
        uint8 random;
        return random;
    }

    function _disperseUser(uint256 betId) internal {
        require(bets[betId].status == BetStatus.ROLLED, "yet to roll");
        require(bets[betId].status != BetStatus.DISPERSED, "Already dispersed");
        require(bets[betId].betType == bets[betId].winType, "No win");
        uint256 reward = 0;
        uint256 finalAmount=0;
        uint256 userTreasuryAmount = (bets[betId].betAmount * treasuryFee)/100;
        treasuryAmount += userTreasuryAmount;
        uint256 amount = bets[betId].betAmount - userTreasuryAmount;
        
        //1.5x for 2TO6 and 8TO12 win
        if(bets[betId].winType == BetType.TWOTOSIX || bets[betId].winType == BetType.EIGHTTOTWELVE) {
            reward = 150;
        }
        //2x for 7 wins
        else if(bets[betId].winType == BetType.SEVEN) {
            reward = 200;
        }

        finalAmount = (amount * reward)/100;
        bets[betId].disperesedAmount = finalAmount;
        bets[betId].status = BetStatus.DISPERSED;
        _safeTransfer(bets[betId].user, finalAmount);

        emit Disperesed(bets[betId].user, finalAmount);
    }

    function betAndRoll(uint256 betNumber, bool useVRF) external payable whenNotPaused nonReentrant notContract {
        if(useVRF) {
            require(msg.value >= minVRFBetAmount, "Bet amount must be greater than minVRFBetAmount");
        }
        else {
            require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        }
        require(msg.value <= maxBetAmount, "Bet amount must be lesser than maxBetAmount");
        // 2 means 2 to 6, 7 means 7, 8 means 8 to 12
        require(betNumber == 2 || betNumber == 7 || betNumber == 8, "Invalid bet type");

        BetInfo storage bet = bets[currentBetId];

        bet.betId = currentBetId;
        bet.user = msg.sender;
        bet.betAmount = msg.value;
        userBets[msg.sender].push(currentBetId);

        if(betNumber == 2) {
            bet.betType = BetType.TWOTOSIX;
        }
        else if(betNumber == 7) {
            bet.betType = BetType.SEVEN;
        } 
        else {
            bet.betType = BetType.EIGHTTOTWELVE;
        }

        emit Bet(msg.sender, bet.betType, msg.value);

        //roll the dice
        _rollDice(currentBetId, useVRF);

        //disperse user
        _disperseUser(currentBetId);

        //increase currentBetId
        currentBetId = currentBetId + 1;
    }

    function _rollDice(uint256 betId, bool useVRF) internal {
        require(bets[betId].betAmount > 0, "Bet first, roll the dice next");
        require(bets[betId].status == BetStatus.UNKNOWN, "Already rolled");
        
        uint256 random = _getRandomNumber(useVRF);
        require(random >= 2 && random <= 12, "Incorrect random number");

        if(random >= 2 && random <= 6) {
            bets[betId].winType = BetType.TWOTOSIX;
        }
        else if(random >= 8 && random <= 12) {
            bets[betId].winType = BetType.EIGHTTOTWELVE;
        }
        else {
            bets[betId].winType = BetType.SEVEN;
        }

        bets[betId].status = BetStatus.ROLLED;

        emit DiceRolled(bets[betId].user, bets[betId].betType, bets[betId].winType);
    }
}
