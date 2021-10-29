// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./DiceAdministrator.sol";

/**
 * @title BetBeeDice
 */
contract BetBeeDice is DiceAdministrator {

    enum BetType {UNKNOWN, TWOTOSIX, SEVEN, EIGHTTOTWELVE}

    struct BetInfo {
        uint256 betAmount;
        BetType betType;
        BetType winType;
        uint256 amountDispersed;
        bool dispersed;
    }

    mapping(address => BetInfo) public ledger;

    event Paused(uint256 timestamp);
    event UnPaused(uint256 timestamp);

    event Bet2To6(address indexed sender, BetType betType, uint256 _amount);
    event Bet8To12(address indexed sender, BetType betType, uint256 _amount);
    event Bet7(address indexed sender, BetType betType, uint256 _amount);
    event DiceRolled(address indexed sender, BetType userBetType, BetType winType);
    event Disperesed(address indexed sender, uint256 amount);

    /**
     * @notice Constructor
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _maxBetAmount: maximum bet amounts (in wei)
     * @param _treasuryFee: treasury fee 3 (3%)
     */
    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _treasuryFee) 
    DiceAdministrator(_adminAddress, _minBetAmount, _maxBetAmount, _treasuryFee) {

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

    function _getRandomNumber() internal pure returns(uint8) {
        uint8 random;
        return random;
    }

    function _disperseUser(address user) internal {
        require(ledger[user].betType == ledger[user].winType, "No win");
        require(!ledger[user].dispersed, "Already dispersed");
        uint256 reward = 0;
        uint256 finalAmount=0;
        uint256 userTreasuryAmount = (ledger[user].betAmount * treasuryFee)/100;
        treasuryAmount += userTreasuryAmount;
        uint256 amount = ledger[user].betAmount - userTreasuryAmount;
        
        //1.5x for 2TO6 and 8TO12 win
        if(ledger[user].winType == BetType.TWOTOSIX || ledger[user].winType == BetType.EIGHTTOTWELVE) {
            reward = 150;
        }
        //2x for 7 wins
        else if(ledger[user].winType == BetType.SEVEN) {
            reward = 200;
        }

        finalAmount = (amount * reward)/100;
        ledger[user].amountDispersed = finalAmount;
        ledger[user].dispersed = true;
        _safeTransfer(user, finalAmount);

        emit Disperesed(user, finalAmount);
    }

    function bet2To6() external payable whenNotPaused nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(msg.value <= maxBetAmount, "Bet amount must be lesser than maxBetAmount");

        ledger[msg.sender].betAmount = msg.value;
        ledger[msg.sender].betType = BetType.TWOTOSIX;
        ledger[msg.sender].dispersed = false;

        emit Bet2To6(msg.sender, BetType.TWOTOSIX, msg.value);
    }

    function bet8To12() external payable whenNotPaused nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(msg.value <= maxBetAmount, "Bet amount must be lesser than maxBetAmount");

        ledger[msg.sender].betAmount = msg.value;
        ledger[msg.sender].betType = BetType.EIGHTTOTWELVE;
        ledger[msg.sender].dispersed = false;

        emit Bet8To12(msg.sender, BetType.EIGHTTOTWELVE, msg.value);
    }

    function bet7() external payable whenNotPaused nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(msg.value <= maxBetAmount, "Bet amount must be lesser than maxBetAmount");

        ledger[msg.sender].betAmount = msg.value;
        ledger[msg.sender].betType = BetType.SEVEN;
        ledger[msg.sender].dispersed = false;

        emit Bet2To6(msg.sender, BetType.SEVEN, msg.value);
    }

    function rollDice() external whenNotPaused notContract {
        require(ledger[msg.sender].betAmount > 0, "Bet first, roll the dice next");
        require(!ledger[msg.sender].dispersed, "Already ended");
        
        uint256 random = _getRandomNumber();
        if(random >= 2 && random <= 6) {
            ledger[msg.sender].winType = BetType.TWOTOSIX;
        }
        else if(random >= 8 && random <= 12) {
            ledger[msg.sender].winType = BetType.EIGHTTOTWELVE;
        }
        else if(random == 7) {
            ledger[msg.sender].winType = BetType.SEVEN;
        }

        //user wins
        if(ledger[msg.sender].betType == ledger[msg.sender].winType) {
            _disperseUser(msg.sender);
        }
        //house wins
        else {
            treasuryAmount += ledger[msg.sender].betAmount;
        }

        emit DiceRolled(msg.sender, ledger[msg.sender].betType, ledger[msg.sender].winType);
    }
}
