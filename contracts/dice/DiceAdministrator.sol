// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title DiceAdministrator
 */
contract DiceAdministrator is Ownable, Pausable, ReentrancyGuard {

    address private admin;
    uint256 public treasuryFee;
    uint256 public constant MAX_TREASURY_FEE = 3; // 3%
    uint256 public minBetAmount; // minimum betting amount (denominated in wei)
    uint256 public minVRFBetAmount; // minimum betting amount when VRF selected(denominated in wei)
    uint256 public maxBetAmount; // maximum betting amount (denominated in wei)
    uint256 public treasuryAmount; // funds in treasury collected from fee
    uint256 public claimableTreasuryPercent = 80; //80%

    event NewMinBetAmount(uint256 minBetAmount);
    event NewMinVRFBetAmount(uint256 minBetAmount);
    event NewMaxBetAmount(uint256 minBetAmount);
    event NewTreasuryFee(uint256 treasuryFee);
    event NewAdmin(address indexed admin);
    event NewClaimableTreasuryPercent(uint256 claimableTreasuryPercent);
    event TreasuryClaim(address indexed admin, uint256 amount);

    constructor(address _adminAddress, uint256 _minBetAmount, uint256 _maxBetAmount, uint256 _minVRFBetAmount, uint256 _treasuryFee) {
        require(_minBetAmount > 0, "Invalid Min bet amount");
        require(_treasuryFee < MAX_TREASURY_FEE, "Treasury fee is too high");
        require(_adminAddress != address(0), "Invalid admin address");
        require(_maxBetAmount > _minBetAmount, "max bet amount less than min amount");
        admin = _adminAddress;
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
        minVRFBetAmount = _minVRFBetAmount;
        treasuryFee = _treasuryFee;
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
     * @notice Set minBetAmount
     * @dev Callable by admin
     * @param _minVRFBetAmount: minimum bet amount to be set
     */
    function setMinVRFBetAmount(uint256 _minVRFBetAmount) external whenPaused onlyAdmin {
        require(_minVRFBetAmount != 0, "Must be superior to 0");
        minVRFBetAmount = _minVRFBetAmount;
 
        emit NewMinVRFBetAmount(_minVRFBetAmount);
    }

    /**
     * @notice Set minBetAmount
     * @dev Callable by admin
     * @param _minBetAmount: minimum bet amount to be set
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount != 0, "Must be superior to 0");
        minBetAmount = _minBetAmount;
 
        emit NewMinBetAmount(_minBetAmount);
    }

    /**
     * @notice Set maxBetAmount
     * @dev Callable by admin
     * @param _maxBetAmount: maximum bet amount to be set
     */
    function setMaxBetAmount(uint256 _maxBetAmount) external whenPaused onlyAdmin {
        require(_maxBetAmount > minBetAmount, "Must be superior to 0");
        maxBetAmount = _maxBetAmount;

        emit NewMaxBetAmount(_maxBetAmount);
    }

    /**
     * @notice Set Treasury Fee
     * @dev Callable by admin
     * @param _treasuryFee: new treasury fee
     */
    function setTreasuryFee(uint256 _treasuryFee) external whenPaused onlyAdmin {
        require(_treasuryFee < MAX_TREASURY_FEE, "Treasury fee is too high");
        treasuryFee = _treasuryFee;

        emit NewTreasuryFee(_treasuryFee);
    }

    /**
     * @notice Set admin
     * @dev callable by Owner of the contract
     * @param _admin: new admin address
     */
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Cannot be zero address");
        admin = _admin;

        emit NewAdmin(_admin);
    }
    
    /**
    * @notice Add funds
    */
    receive() external payable {
    }

    /**
    * @notice Set Claimabble Treasury Percent
    * @dev callable by Admin
    * @param _claimableTreasuryPercent: claimable percent
    */
    function setClaimableTreasuryPercent(uint256 _claimableTreasuryPercent)  external onlyAdmin {
        require(_claimableTreasuryPercent > 0, "Amount cannot be zero or less");
        claimableTreasuryPercent = _claimableTreasuryPercent;

        emit NewClaimableTreasuryPercent(claimableTreasuryPercent);
    }

    /**
     * @notice Claim 80% of treasury fund - collected as fee
     * @dev Callable by admin
     */
    function claimTreasury() external nonReentrant onlyAdmin notContract {
        uint256 claimableTreasuryAmount = ((treasuryAmount * claimableTreasuryPercent) / 100);
        treasuryAmount -= claimableTreasuryAmount;
        (bool success, ) = admin.call{value: claimableTreasuryAmount}("");
        require(success, "TransferHelper: TRANSFER_FAILED");

        emit TreasuryClaim(admin, claimableTreasuryAmount);
    }

    /**
    * @notice get admin address
    * @return admin address
    */
    function getAdmin() public view returns(address) {
        return admin;
    }
}
