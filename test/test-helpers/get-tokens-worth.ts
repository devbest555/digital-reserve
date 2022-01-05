import { Contract } from "web3-eth-contract";
import { DigitalReserveInstance } from "../../types/truffle-contracts";
import { getContractAddress, Network } from "../../utils/contract-by-network";

export const getTokensWorth = async (
  instance: DigitalReserveInstance,
  uniRouter: Contract,
  newtworkType: Network
) => {
  const tokens = await instance.totalTokenStored();

  const wethAddress = await uniRouter.methods.WETH().call();
  let total = 0;
  let percentage1 = 100;
  let tokenWorth1 = 0;
  
  if(tokens.toNumber() > 0) {
    const amount1 = await uniRouter.methods
    .getAmountsIn(tokens.toString(), [
      wethAddress,
      getContractAddress("usdc", newtworkType),
    ])
    .call();

    tokenWorth1 = Number(web3.utils.fromWei(amount1[0]));
    total = tokenWorth1;

    percentage1 = Math.round((tokenWorth1 / total) * 100);
  }

  return {
    tokenWorth: tokenWorth1,
    tokenPercentage: percentage1,
  };
};
