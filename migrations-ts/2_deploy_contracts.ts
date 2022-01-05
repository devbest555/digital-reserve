const DigitalReserve = artifacts.require("DigitalReserve");

type Network = "development" | "ropsten" | "kovan" | "main";

module.exports = async (
  deployer: Truffle.Deployer,
  network: Network
  // accounts: string[]
) => {
  console.log(network);

  const aaveRouter =
    network === "kovan"
      ? "0x88757f2f99175387ab4c6a4b3067c77a695b0349"
      : "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5";
  const aaveProtocol =
    network === "kovan"
      ? "0x3c73A5E5785cAC854D468F727c606C07488a29D6"
      : "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d";
  const drcAddress =
    network === "kovan"
      ? "0x9883Efbe554380cA68b0270f0571995ED0bad46c"
      : "0xa150Db9b1Fa65b44799d4dD949D922c0a33Ee606";

  await deployer.deploy(
    DigitalReserve,
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    aaveRouter,
    aaveProtocol,
    drcAddress,
    "Digital Reserve",
    "DR-POD-S3"
  );

  const digitalReserve = await DigitalReserve.deployed();
  console.log(
    `DigitalReserve deployed at ${digitalReserve.address} in network: ${network}.`
  );
};

// because of https://stackoverflow.com/questions/40900791/cannot-redeclare-block-scoped-variable-in-unrelated-files
export {};
