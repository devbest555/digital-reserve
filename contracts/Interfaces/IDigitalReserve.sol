// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.6.12;

/**
* @dev Interface of Digital Reserve contract.
*/
interface IDigitalReserve {
    /**
     * @dev Returns withdrawal withdrawal fee.
     * @return The first value is fraction, the second one is fraction base
     */
    function withdrawalFee() external view returns (uint8, uint8);

    /**
     * @dev Returns Proof of Deposit price decimal.
     * Price should be displayed as `price / (10 ** priceDecimals)`.
     */
    function priceDecimals() external view returns (uint8);

    /**
     * @dev Returns total strategy tokens stored in an array.
     * The output amount sequence is the strategyTokens() array sequence.
     */
    function totalTokenStored() external view returns (uint256);

    /**
     * @dev Returns how much user's vault share in DRC amount.
     * @param user Address of a DR user
     * @return The first output is total worth in DRC, 
     * second one is total DRC could withdraw (exclude fees), 
     * and last output is fees in wei.
     */
    function getUserVaultInDrc(address user) external view returns (uint256, uint256, uint256);

    /**
     * @dev Proof of Deposit net unit worth.
     */
    function getProofOfDepositPrice() external view returns (uint256);

    /**
     * @dev Deposit DRC to DR.
     * @param drcAmount DRC amount user want to deposit.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function depositDrc(uint256 drcAmount, uint32 deadline) external;

    /**
     * @dev Withdraw DRC from DR.
     * @param drcAmount DRC amount user want to withdraw.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function withdrawDrc(uint256 drcAmount, uint32 deadline) external;

    /**
     * @dev Withdraw a percentage of holding from DR.
     * @param percentage Percentage of holding user want to withdraw.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function withdrawPercentage(uint8 percentage, uint32 deadline) external;

    /**
     * @dev Emit when strategy set or change function is called by owner.
     * @param oldTokenA Pervious strategy's tokenA addresses.
     * @param oldTokenB Pervious strategy's tokenA addresses.
     * @param newTokenA New strategy's tokenA(e.x. usdc) addresses.
     * @param newTokenB New strategy's tokenB(e.x. ausdc) addresses.
     * @param tokensStored How much each token is stored.
     */
    event SetToken(
        address oldTokenA, 
        address oldTokenB, 
        address newTokenA, 
        address newTokenB, 
        uint256 tokensStored
    );
    
    /**
     * @dev Emit each time a deposit action happened.
     * @param user Address made the deposit.
     * @param amount DRC amount deposited.
     * @param podMinted New DR-POD minted.
     * @param podTotalSupply New DR-POD total supply.
     * @param tokensStored How much each token is stored.
     */
    event Deposit(
        address indexed user, 
        uint256 amount, 
        uint256 podMinted, 
        uint256 podTotalSupply, 
        uint256 tokensStored
    );
    
    /**
     * @dev Emit each time a withdraw action happened.
     * @param user Address made the withdrawal.
     * @param amount DRC amount withdrawn.
     * @param fees Withdrawal fees charged in wei.
     * @param podBurned DR-POD burned.
     * @param podTotalSupply New DR-POD total supply.
     * @param tokensStored How much each token is stored.
     */
    event Withdraw(
        address indexed user, 
        uint256 amount, 
        uint256 fees, 
        uint256 podBurned, 
        uint256 podTotalSupply, 
        uint256 tokensStored
    );
}
