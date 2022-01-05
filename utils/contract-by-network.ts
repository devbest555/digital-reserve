type ContractName =
  | "uniswap"
  | "aave"
  | "aaveProtocol"
  | "drc"
  | "weth"
  | "usdc"
  | "ausdc";
type NetworkType = "test" | "main";
export type Network = "development" | "ropsten" | "kovan" | "main";

type ContractAddresses = Record<ContractName, Record<NetworkType, string>>;

const contractAddresses: ContractAddresses = {
  uniswap: {
    test: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    main: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  },
  aave: {
    test: "0x88757f2f99175387ab4c6a4b3067c77a695b0349",
    main: "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5",
  },
  aaveProtocol: {
    test: "0x3c73A5E5785cAC854D468F727c606C07488a29D6",
    main: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
  },
  drc: {
    test: "0x9883Efbe554380cA68b0270f0571995ED0bad46c", // 0x6D38D09eb9705A5Fb1b8922eA80ea89d438159C7
    main: "0xa150Db9b1Fa65b44799d4dD949D922c0a33Ee606",
  },
  weth: {
    test: "0xd0A1E359811322d97991E03f863a0C30C2cF029C", // "0xc778417E063141139Fce010982780140Aa0cD5Ab",
    main: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  },
  usdc: {
    test: "0xe22da380ee6B445bb8273C81944ADEB6E8450422", //"0x87c00648150d89651FB6C5C5993338DCfcA3Ff7B"
    main: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  },
  ausdc: {
    test: "0xe12AFeC5aa12Cf614678f9bFeeB98cA9Bb95b5B0",
    main: "0xBcca60bB61934080951369a648Fb03DF4F96263C",
  },
};

export const getContractAddress = (
  name: ContractName,
  network: Network
): string => {
  const networkType: NetworkType =
    network !== "ropsten" && network !== "kovan" ? "main" : "test"; // TODO: switch back to mainnet to be safe
  return contractAddresses[name][networkType];
};
