const Prediction = artifacts.require("BetBeePrediction");

module.exports = function (deployer) {
  deployer.deploy(Prediction);
};
