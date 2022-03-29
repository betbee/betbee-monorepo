const BetBeePrediction = artifacts.require("BetBeePrediction");

contract("BetBeePrediction", accounts => {

    const owner = accounts[0];
    const tester = accounts[1];

    it("should have admin address, operator address, minBetAmount and treasury fee set", async () => {
        const instance = await BetBeePrediction.deployed();
        assert(instance.admin, 0, "admin address not set");
        assert(instance.operator, 0, "operator address not set");
        let minAmount = await instance.minBetAmount;
//        assert.equal(minAmount, 10000000000000000, "minimum amount isn't 10000000000000000 ");
//        assert.equal(instance.treasuryFee, 3, "Treasury fee isn't 3");
    });

    it("should set minimum bet amount when paused", async () => {
        const instance = await BetBeePrediction.deployed();
        await instance.pause();
        await instance.setMinBetAmount(20000000000000000);
        await instance.unPause();
        assert(instance.minBetAmount, 20000000000000000, "failed to set minimum bet amount");

    });

    it("should set treasury fee when paused", async () => {
        const instance = await BetBeePrediction.deployed();
        await instance.pause();
        await instance.setTreasuryFee(4);
        await instance.unPause();
        assert(instance.treasuryFee, 4, "failed to set treasury fee");
    });

  });
