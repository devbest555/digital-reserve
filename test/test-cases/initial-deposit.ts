import { Contract } from "web3-eth-contract";
import { AbiItem } from "web3-utils";
import { DigitalReserveInstance } from "../../types/truffle-contracts";
import { assertRevert } from "../test-helpers/assertions";
import { getUnixTimeAfterMins } from "../../utils/timestamp";
import IERC20 from "../../build/contracts/IERC20.json";
import IUniswapV2Router02 from "../../build/contracts/IUniswapV2Router02.json";
import { Network, getContractAddress } from "../../utils/contract-by-network";
import {
  Deposit,
  Transfer,
} from "../../types/truffle-contracts/DigitalReserve";
import { getTokensWorth } from "../test-helpers/get-tokens-worth";

const DigitalReserve = artifacts.require("DigitalReserve");

export const testInitialDeposit = async (accounts: Truffle.Accounts) => {
  let instance: DigitalReserveInstance;

  let drcContract: Contract;
  let uniRouter: Contract;
  let newtworkType: Network;

  before(async () => {
    instance = await DigitalReserve.deployed();

    newtworkType = (await web3.eth.net.getNetworkType()) as Network;

    drcContract = new web3.eth.Contract(
      IERC20.abi as AbiItem[],
      getContractAddress("drc", newtworkType)
    );
    uniRouter = new web3.eth.Contract(
      IUniswapV2Router02.abi as AbiItem[],
      getContractAddress("uniswap", newtworkType)
    );
  });

  // it("Should not able to deposit before deposit is enabled", async () => {
  //   await assertRevert(
  //     instance.depositDrc(1000, getUnixTimeAfterMins(10)),
  //     "Deposit is disabled.",
  //     "Can't deposit DRC before deposit is enabled"
  //   );
  // });

  it("Should get Proof of Deposit Price before converitn DRC", async () => {
    const POD = await instance.getProofOfDepositPrice();
    console.log("POD price", Number(web3.utils.fromWei(POD)));
    assert.equal(Number(web3.utils.fromWei(POD)), 0);
  });

  it("Should be able to deposit 1000 DRC and mint 1 DR-POD", async () => {
    await instance.changeDepositStatus(true);

    const userBalance = await drcContract.methods.balanceOf(accounts[0]).call();
    console.log("user DRC Balance", userBalance, accounts[0]);

    await drcContract.methods
      .approve(instance.address, 1000)
      .send({ from: accounts[0] });

    const allowance = Number(
      await drcContract.methods.allowance(accounts[0], instance.address).call()
    );

    console.log("DRC allowance", allowance);

    assert.equal(allowance, 1000);

    const deposit1000Result = await instance.depositDrc(
      1000,
      getUnixTimeAfterMins(10)
    );

    const transferLog = deposit1000Result.logs.find(
      (log) => log.event === "Transfer"
    ) as Transfer | undefined;

    assert.exists(transferLog);

    const depositLog = deposit1000Result.logs.find(
      (log) => log.event === "Deposit"
    ) as Deposit | undefined;

    assert.exists(depositLog);

    if (depositLog) {
      assert.equal(depositLog.args.amount.toNumber(), 1000);
      assert.equal(Number(web3.utils.fromWei(depositLog.args.podMinted)), 1);
      assert.equal(
        Number(web3.utils.fromWei(depositLog.args.podTotalSupply)),
        1
      );
      assert.equal(depositLog.args.user, accounts[0]);
    }
  });

  it("Should have correct token balances", async () => {
    const totalSupply = await instance.totalSupply();
    assert.equal(Number(web3.utils.fromWei(totalSupply)), 1);

    const userBalance = await instance.balanceOf(accounts[0]);
    assert.equal(Number(web3.utils.fromWei(userBalance)), 1);
  });

  it("Should have correct DRC value", async () => {
    const valueInDrc = await instance.getUserVaultInDrc(accounts[0]);
    assert.isAtLeast(valueInDrc[0].toNumber(), 992);
    assert.equal(valueInDrc[1].toNumber(), 978);
  });

  it("Should match designed percentage", async () => {
    const { tokenPercentage } = await getTokensWorth(
      instance,
      uniRouter,
      newtworkType
    );

    assert.equal(tokenPercentage, 100);
  });

  it("Should have proof of deposit price above 0", async () => {
    const drPodPrice = (await instance.getProofOfDepositPrice()).toNumber();
    assert.isAbove(drPodPrice, 0);
  });
};
