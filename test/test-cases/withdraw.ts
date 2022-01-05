import { DigitalReserveInstance } from "../../types/truffle-contracts";
import { getUnixTimeAfterMins } from "../../utils/timestamp";
import { Network } from "../../utils/contract-by-network";
import { Withdraw } from "../../types/truffle-contracts/DigitalReserve";

const DigitalReserve = artifacts.require("DigitalReserve");

export const testWithdraw = async (accounts: Truffle.Accounts) => {
  let instance: DigitalReserveInstance;

  let newtworkType: Network;
  let prevDrcUserCanWithdraw: number;
  let prevUserPod: number;

  before(async () => {
    instance = await DigitalReserve.deployed();

    newtworkType = (await web3.eth.net.getNetworkType()) as Network;

    const valueInDrc = await instance.getUserVaultInDrc(accounts[0]);
    prevDrcUserCanWithdraw = valueInDrc[1].toNumber();
    const userPod = await instance.balanceOf(accounts[0]);
    prevUserPod = Number(web3.utils.fromWei(userPod));
  });

  it("Should be able to withdraw 10000 DRC and burn DR-POD", async () => {
    const withdrawResult = await instance.withdrawDrc(
      10000,
      getUnixTimeAfterMins(10)
    );

    console.log("prevUserPod===>", prevUserPod, prevDrcUserCanWithdraw);

    const withdrawLog = withdrawResult.logs.find(
      (log) => log.event === "Withdraw"
    ) as Withdraw | undefined;

    assert.exists(withdrawLog);

    if (withdrawLog) {
      assert.isAtLeast(withdrawLog.args.amount.toNumber(), 10000);
      assert.isAbove(Number(web3.utils.fromWei(withdrawLog.args.podBurned)), 0);
      assert.equal(
        Number(web3.utils.fromWei(withdrawLog.args.podTotalSupply)).toFixed(2),
        (
          prevUserPod - Number(web3.utils.fromWei(withdrawLog.args.podBurned))
        ).toFixed(2)
      );
      assert.equal(withdrawLog.args.user, accounts[0]);

      const valueInDrc = await instance.getUserVaultInDrc(accounts[0]);
      const currentDrcUserCanWithdraw = valueInDrc[1].toNumber();

      assert.equal(
        Math.round(
          (currentDrcUserCanWithdraw /
            (prevDrcUserCanWithdraw - withdrawLog.args.amount.toNumber())) *
            100
        ),
        100
      ); // The withdrawal has positive price impact, which made the price go up, then less DRC can be withdrawn
    }
  });

  it("Should be able to withdraw 100% DRC and burn DR-POD", async () => {
    const valueInDrc = await instance.getUserVaultInDrc(accounts[0]);
    const currentDrcUserCanWithdraw = valueInDrc[1].toNumber();

    const withdrawResult = await instance.withdrawPercentage(
      100,
      getUnixTimeAfterMins(10)
    );

    const withdrawLog = withdrawResult.logs.find(
      (log) => log.event === "Withdraw"
    ) as Withdraw | undefined;

    assert.exists(withdrawLog);

    if (withdrawLog) {
      assert.equal(
        withdrawLog.args.amount.toNumber(),
        currentDrcUserCanWithdraw
      );
      assert.isAbove(Number(web3.utils.fromWei(withdrawLog.args.podBurned)), 0);
      assert.equal(
        Number(web3.utils.fromWei(withdrawLog.args.podTotalSupply)),
        0
      );
      assert.equal(withdrawLog.args.user, accounts[0]);
    }
  });

  it("Should have 0 left over supply", async () => {
    const totalSupply = (await instance.totalSupply()).toNumber();
    assert.equal(totalSupply, 0);
  });

  it("Should have proof of deposit price as 0", async () => {
    const drPodPrice = (await instance.getProofOfDepositPrice()).toNumber();
    assert.equal(drPodPrice, 0);
  });
};
