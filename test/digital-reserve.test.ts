import { testSetStrategy } from "./test-cases/set-strategy";
import { testInitialDeposit } from "./test-cases/initial-deposit";
import { testInitialSupply } from "./test-cases/initial-supply";
import { testSecondDeposit } from "./test-cases/second-deposit";
import { testWithdraw } from "./test-cases/withdraw";

contract("DigitalReserve", (accounts) => {
  describe("Initial supplies", async () => testInitialSupply());

  describe("Set Strategy", async () => testSetStrategy());

  describe("Deposit 1000 DRC", async () => testInitialDeposit(accounts));

  describe("Deposit 2000 DRC", async () => testSecondDeposit(accounts));

  describe("Withdrawal", async () => testWithdraw(accounts));
});
