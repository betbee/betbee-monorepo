// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PredictionAdministrator
 */
contract PredictionAdministrator is Ownable, Pausable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address public admin;
    address public operator;
    uint256 public treasuryFee = 3; //default 3%
    uint256 public constant MAX_TREASURY_FEE = 5; // 5%
    uint256 public minBetAmount = 10000000000000000; // minimum betting default amount 0.01
    uint256 public treasuryAmount; // funds in treasury collected from fee
    uint256 public claimableTreasuryPercent = 80; //80%

    event NewMinBetAmount(uint256 minBetAmount);
    event NewTreasuryFee(uint256 treasuryFee);
    event NewAdmin(address indexed admin);
    event NewOperator(address indexed operator);
    event NewClaimableTreasuryPercent(uint256 claimableTreasuryPercent);
    event TreasuryClaim(address indexed admin, uint256 amount);

    constructor() {
        admin = owner();
        operator = admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
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
     * @param _minBetAmount: minimum bet amount to be set
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount != 0, "Must be superior to 0");
        minBetAmount = _minBetAmount;

        emit NewMinBetAmount(_minBetAmount);
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
     * @notice Set operator
     * @dev callable by Owner of the contract
     * @param _operator: new operator address
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Cannot be zero address");
        operator = _operator;

        emit NewOperator(_operator);
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
        treasuryAmount = treasuryAmount - claimableTreasuryAmount;
        (bool success, ) = admin.call{value: claimableTreasuryAmount}("");
        require(success, "TransferHelper: TRANSFER_FAILED");

        emit TreasuryClaim(admin, claimableTreasuryAmount);
    }

    /**
     * @notice Recover tokens sent by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external nonReentrant onlyAdmin notContract {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);
    }

}
