const BetBeePrediction = artifacts.require("BetBeePrediction");
const PredictionAdministrator = artifacts.require("PredictionAdministrator");

module.exports = function (deployer) {
  deployer.deploy(BetBeePrediction());
  deployer.deploy(PredictionAdministrator());
};
