import { DigitalReserveInstance } from "../../types/truffle-contracts";

const DigitalReserve = artifacts.require("DigitalReserve");

export const testInitialSupply = async () => {
  let instance: DigitalReserveInstance;

  before(async () => {
    instance = await DigitalReserve.deployed();
  });

  it("Should have 0 initial supply", async () => {
    const totalSupply = (await instance.totalSupply()).toNumber();
    assert.equal(totalSupply, 0);
  });

  it("Should have proof of deposit price as 0", async () => {
    const drPodPrice = (await instance.getProofOfDepositPrice()).toNumber();
    assert.equal(drPodPrice, 0);
  });
};
