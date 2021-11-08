const predictionAdmin = artifacts.require("PredictionAdministrator");

contract("PredictionAdministrator", accounts => {

    it("should have admin address, minBetAmount and treasury fee set", async () => {
        const instance = await PredictionAdministrator.deployed();
        
    }
  });
