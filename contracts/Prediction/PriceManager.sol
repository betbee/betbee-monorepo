// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceManager {

    AggregatorV3Interface public oracle;
    uint256 oracleUpdateAllowance = 300;
    string public assetPair; // BTCUSDT or ETHUSDT or BNBUSDT
    uint256 public oracleLatestRoundId;

    constructor(address _oracleAddress, string memory _assetPair) {
        require(_oracleAddress != address(0), "Invalid oracle address");
        oracle = AggregatorV3Interface(_oracleAddress);
        assetPair = _assetPair;
    }

    function _getLatestPrice() internal view returns(uint256, int256) { 
        uint256 leastAllowedTimestamp = block.timestamp + oracleUpdateAllowance;
        (uint80 roundId, int256 price, , uint256 timestamp, ) = oracle.latestRoundData();
        require(timestamp <= leastAllowedTimestamp, "Oracle update exceeded max timestamp allowance");
        require(uint256(roundId) > oracleLatestRoundId, "Oracle roundId must be larger than oracleLatestRoundId");
        return (roundId, price);
    }
}
