// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceManager is ChainlinkClient {

    AggregatorV3Interface public oracle;
    string public assetPair; // BTCUSDT or ETHUSDT or BNBUSDT

    constructor(address _oracleAddress, string memory _assetPair) {
        require(_oracleAddress != address(0), "Invalid oracle address");
        oracle = AggregatorV3Interface(_oracleAddress);
        assetPair = _assetPair;
    }

    function _getCurrentPrice() internal view returns(int256) {
        
    }

    function _getPriceByTimestamp(uint256 timestamp) internal view returns(int256) {

    }
}
