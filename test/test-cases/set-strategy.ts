import { Contract } from "web3-eth-contract";
import { AbiItem } from "web3-utils";
import { DigitalReserveInstance } from "../../types/truffle-contracts";
import IUniswapV2Router02 from "../../build/contracts/IUniswapV2Router02.json";
import { SetToken } from "../../types/truffle-contracts/DigitalReserve";
import { Network, getContractAddress } from "../../utils/contract-by-network";
import { getUnixTimeAfterMins } from "../../utils/timestamp";
import { getTokensWorth } from "../test-helpers/get-tokens-worth";

const DigitalReserve = artifacts.require("DigitalReserve");

export const testSetStrategy = async () => {
  let instance: DigitalReserveInstance;

  let uniRouter: Contract;
  let newtworkType: Network;

  before(async () => {
    instance = await DigitalReserve.deployed();
    newtworkType = (await web3.eth.net.getNetworkType()) as Network;

    uniRouter = new web3.eth.Contract(
      IUniswapV2Router02.abi as AbiItem[],
      getContractAddress("uniswap", newtworkType)
    );
  });

  it("Should change strategy and emit event with old and new settings", async () => {
    const changeStrategyResult = await instance.setTokenAddress(
      getContractAddress("usdc", newtworkType),
      getUnixTimeAfterMins(20)
    );

    const changeStrategyLog = changeStrategyResult.logs.find(
      (log) => log.event === "SetToken"
    ) as SetToken | undefined;

    assert.exists(changeStrategyLog);

    if (changeStrategyLog) {
      assert.equal(
        changeStrategyLog.args.newTokenA,
        getContractAddress("usdc", newtworkType)
      );
      assert.equal(
        changeStrategyLog.args.newTokenB,
        getContractAddress("ausdc", newtworkType)
      );
    }
  });

  it("Should check wrapped ETH address correctly", async () => {
    const wethAddress = await uniRouter.methods.WETH().call();
    assert.equal(wethAddress,
      getContractAddress("weth", newtworkType));
  });

  it("Should be token stored is 0 at first", async () => {
    const tokens = await instance.totalTokenStored();
    assert.equal(tokens.toNumber(), 0);
  });

  it("Should have the right token worth", async () => {
    const { tokenPercentage } = await getTokensWorth(
      instance,
      uniRouter,
      newtworkType
    );
    console.log("tokenPercentage===>", tokenPercentage);
    assert.equal(tokenPercentage, 100);
  });
};
