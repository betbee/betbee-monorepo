const BetBeePrediction = artifacts.require("BetBeePrediction");
const PredictionAdministrator = artifacts.require("PredictionAdministrator");
const PriceManager = artifacts.require("PriceManager");

module.exports = function (deployer) {
  deployer.deploy(BetBeePrediction());
  deployer.deploy(PredictionAdministrator());
  deployer.deploy(PriceManager());
};
