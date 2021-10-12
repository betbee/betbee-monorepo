// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PredictionAdministrator
 */
contract PredictionAdministrator is Ownable, Pausable, ReentrancyGuard {

    address private admin;
    uint256 public treasuryFee;
    uint256 public constant MAX_TREASURY_FEE = 500; // 5%
    uint256 public minBetAmount; // minimum betting amount (denominated in wei)
    uint256 public treasuryAmount; // funds in treasury collected from fee

    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _treasuryFee) {
        require(_minBetAmount > 0, "Invalid Min bet amount");
        require(_treasuryFee < MAX_TREASURY_FEE, "Treasury fee is too high");
        require(_adminAddress != address(0), "Invalid admin address");
        admin = _adminAddress;
        minBetAmount = _minBetAmount;
        _treasuryFee = _treasuryFee;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @notice called by the admin to pause, triggers stopped state
     * @dev Callable by admin
     */
    function pause() external whenNotPaused onlyAdmin {
        _pause();
    }

    /**
     * @notice called by the admin to unpause, triggers started state
     * @dev Callable by admin
     */
    function unPause() external whenPaused onlyAdmin {
        _unpause();
    }

    /**
     * @notice Set minBetAmount
     * @dev Callable by admin
     * @param _minBetAmount: minimum bet amount to be set
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount != 0, "Must be superior to 0");
        minBetAmount = _minBetAmount;
    }

    /**
     * @notice Set Treasury Fee
     * @dev Callable by admin
     * @param _treasuryFee: new treasury fee
     */
    function setTreasuryFee(uint256 _treasuryFee) external whenPaused onlyAdmin {
        require(_treasuryFee < MAX_TREASURY_FEE, "Treasury fee is too high");
        treasuryFee = _treasuryFee;
    }

    /**
     * @notice Set admin
     * @dev callable by Owner of the contract
     * @param _admin: new admin address
     */
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Cannot be zero address");
        admin = _admin;
    }

    /**
     * @notice Transfer BNB in a safe way
     * @param value: BNB amount to transfer (in wei)
     */
    function _safeTransferBNB(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: BNB_TRANSFER_FAILED");
    }

    /**
     * @notice Claim treasury fund - collected as fee
     * @dev Callable by admin
     */
    function claimTreasury() external nonReentrant onlyAdmin notContract {
        uint256 currentTreasuryAmount = treasuryAmount;
        treasuryAmount = 0;
        _safeTransferBNB(admin, currentTreasuryAmount);
    }

    /**
    * @notice fetch admin address
    * @return admin address 
    */
    function getAdmin() external view returns(address) {
        return admin;
    }
}