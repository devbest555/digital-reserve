// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/Uniswap/IUniswapV2Factory.sol";
import "./interfaces/Uniswap/IUniswapV2Pair.sol";
import "./interfaces/Uniswap/IUniswapV2Router02.sol";

import "./interfaces/AAVE/ILendingPoolAddressesProvider.sol";
import "./interfaces/AAVE/ILendingPool.sol";
import "./interfaces/AAVE/IProtocolDataProvider.sol";

import "./interfaces/IDigitalReserve.sol";

/**
 * @dev Implementation of Digital Reserve contract.
 * Digital Reserve contract converts user's DRC into a set of SoV assets using the Uniswap router,
 * and hold these assets for it's users.
 * When users initiate a withdrawal action, the contract converts a share of the vault,
 * that the user is requesting, to DRC and sends it back to their wallet.
 */
contract DigitalReserve is IDigitalReserve, ERC20, Ownable {
    using SafeMath for uint256;

    /**
     * @dev Set Uniswap router address, DRC token address, DR name.
     * @param _router Uniswap V2 router address.
     * @param _lendingPoolProvider AAVE Lenging Pool Provider address.
     * @param _protocolAddress AAVE Protocol Contract address.
     * @param _drcAddress DRC token address,
     * @param _name DR POD token name
     * @param _symbol DR POD token symbol
     */
    constructor(
        address _router,
        address _lendingPoolProvider,
        address _protocolAddress,
        address _drcAddress,
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        drcAddress = _drcAddress;
        uniswapRouter = IUniswapV2Router02(_router);
        lendingPoolProvider = ILendingPoolAddressesProvider(_lendingPoolProvider);
        protocolAddress = IProtocolDataProvider(_protocolAddress);
    }

    uint8 private _feeFraction = 1;
    uint8 private _feeBase = 100;
    uint8 private constant _priceDecimals = 18;
    uint256 private _tokenPercentage = 100;

    address private drcAddress;
    address private _strategyReserve;
    address private _strategyToken;

    bool private depositEnabled = false;

    IUniswapV2Router02 private immutable uniswapRouter;
    ILendingPoolAddressesProvider private immutable lendingPoolProvider;
    IProtocolDataProvider private immutable protocolAddress;

    /**
     * @dev See {IDigitalReserve-withdrawalFee}.
     */
    function withdrawalFee() external view override returns (uint8, uint8) {
        return (_feeFraction, _feeBase);
    }

    /**
     * @dev See {IDigitalReserve-priceDecimals}.
     */
    function priceDecimals() external view override returns (uint8) {
        return _priceDecimals;
    }

    /**
     * @dev See {IDigitalReserve-totalTokenStored}.
     */
    function totalTokenStored() public view override returns (uint256) {
        require(_strategyReserve != address(0x00), "strategy reserve address must be set.");
        uint256 amounts = 0;
        amounts = IERC20(_strategyReserve).balanceOf(address(this));
        return amounts;
    }

    /**
     * @dev See {IDigitalReserve-getUserVaultInDrc}.
     */
    function getUserVaultInDrc(
        address user
    ) public view override returns (uint256, uint256, uint256) {
        uint256 userStrategyTokens = _getStrategyTokensByPodAmount(balanceOf(user));
        uint256 userVaultWorthInEth = _getEthAmountByTokenAmount(userStrategyTokens, _strategyToken, true);
        uint256 userVaultWorthInEthAfterSwap = _getEthAmountByTokenAmount(userStrategyTokens, _strategyToken, false);

        uint256 drcAmountBeforeFees = _getTokenAmountByEthAmount(userVaultWorthInEth, drcAddress, true);

        uint256 fees = userVaultWorthInEthAfterSwap.mul(_feeFraction).div(_feeBase + _feeFraction);
        uint256 drcAmountAfterFees = _getTokenAmountByEthAmount(userVaultWorthInEthAfterSwap.sub(fees), drcAddress, false);

        return (drcAmountBeforeFees, drcAmountAfterFees, fees);
    }

    /**
     * @dev See {IDigitalReserve-getProofOfDepositPrice}.
     */
    function getProofOfDepositPrice() public view override returns (uint256) {
        uint256 proofOfDepositPrice = 0;
        if (totalSupply() > 0) {
            ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());
            (uint256 vaultTotalInEth, , , , , ) = lendingPool.getUserAccountData(address(this));

            proofOfDepositPrice = vaultTotalInEth.mul(1e18).div(totalSupply());
        }
        return proofOfDepositPrice;
    }

    /**
     * @dev See {IDigitalReserve-depositDrc}.
     */
    function depositDrc(uint256 drcAmount, uint32 deadline) external override {
        require(depositEnabled, "Deposit is disabled now.");
        require(IERC20(drcAddress).allowance(msg.sender, address(this)) >= drcAmount, "Contract is not allowed to spend user's DRC.");
        require(IERC20(drcAddress).balanceOf(msg.sender) >= drcAmount, "Attempted to deposit more than balance.");

        /** For the production mode, it is better **/
        // SafeERC20.safeTransferFrom(IERC20(drcAddress), msg.sender, address(this), drcAmount);

        /** For the test mode, it is better to test and debug */
        IERC20(drcAddress).transferFrom(msg.sender, address(this), drcAmount);
        // Get current unit price before adding tokens to vault
        uint256 currentPodUnitPrice = getProofOfDepositPrice();

        uint256 ethConverted = _convertTokenToEth(drcAmount, drcAddress, deadline);
        _convertEthToStrategyTokens(ethConverted, deadline);

        uint256 podToMint = 0;
        if (totalSupply() == 0) {
            podToMint = drcAmount.mul(1e15);
        } else {
            ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());
            (uint256 vaultTotalInEth, , , , , ) = lendingPool.getUserAccountData(address(this));
            uint256 newPodTotal = vaultTotalInEth.mul(1e18).div(currentPodUnitPrice);
            podToMint = newPodTotal.sub(totalSupply());
        }

        _mint(msg.sender, podToMint);

        emit Deposit(msg.sender, drcAmount, podToMint, totalSupply(), totalTokenStored());
    }

    /**
     * @dev See {IDigitalReserve-withdrawDrc}.
     */
    function withdrawDrc(uint256 drcAmount, uint32 deadline) external override {
        require(balanceOf(msg.sender) > 0, "Vault balance is 0");
        
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = drcAddress;

        uint256 ethNeeded = uniswapRouter.getAmountsIn(drcAmount, path)[0];
        uint256 ethNeededPlusFee = ethNeeded.mul(_feeBase + _feeFraction).div(_feeBase);

        uint256 userStrategyTokens = _getStrategyTokensByPodAmount(balanceOf(msg.sender));

        uint256 userVaultWorth = _getEthAmountByTokenAmount(userStrategyTokens, _strategyToken, false);

        require(userVaultWorth >= ethNeededPlusFee, "Attempt to withdraw more than user's holding.");

        uint256 amountFraction = ethNeededPlusFee.mul(1e10).div(userVaultWorth);
        uint256 podToBurn = balanceOf(msg.sender).mul(amountFraction).div(1e10);

        _withdrawProofOfDeposit(podToBurn, deadline);
    }

    /**
     * @dev See {IDigitalReserve-withdrawPercentage}.
     */
    function withdrawPercentage(uint8 percentage, uint32 deadline) external override {
        require(balanceOf(msg.sender) > 0, "Vault balance is 0");
        require(percentage <= 100, "Attempt to withdraw more than 100% of the asset");

        uint256 podToBurn = balanceOf(msg.sender).mul(percentage).div(100);
        _withdrawProofOfDeposit(podToBurn, deadline);
    }

    /**
     * @dev Enable or disable deposit.
     * @param status Deposit allowed or not
     * Disable deposit if it is to protect users' fund if there's any security issue or assist DR upgrade.
     */
    function changeDepositStatus(bool status) external onlyOwner {
        depositEnabled = status;
    }

    /**
     * @dev Change withdrawal fee percentage.
     * If 1%, then input (1,100)
     * If 0.5%, then input (5,1000)
     * @param withdrawalFeeFraction_ Fraction of withdrawal fee based on withdrawalFeeBase_
     * @param withdrawalFeeBase_ Fraction of withdrawal fee base
     */
    function changeFee(uint8 withdrawalFeeFraction_, uint8 withdrawalFeeBase_) external onlyOwner {
        require(withdrawalFeeFraction_ <= withdrawalFeeBase_, "Fee fraction exceeded base.");
        uint8 percentage = (withdrawalFeeFraction_ * 100) / withdrawalFeeBase_;
        require(percentage <= 2, "Attempt to set percentage higher than 2%."); // Requested by community

        _feeFraction = withdrawalFeeFraction_;
        _feeBase = withdrawalFeeBase_;
    }

    /**
     * @dev Set or change DR strategy tokens and allocations.
     * @param strategyToken_ strategy token address.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function setTokenAddress(
        address strategyToken_,
        uint32 deadline
    ) external onlyOwner {
        require(strategyToken_ != address(0x00), "Strategy token address must be set.");

        address oldStrategyTokens = address(0x00);
        address oldStrategyReserve = address(0x00);
        uint256 ethConverted = 0;

        if(_strategyToken != address(0x00) && _strategyReserve != address(0x00)){
            oldStrategyTokens = _strategyToken;
            oldStrategyReserve = _strategyReserve;
            // Before mutate strategyTokens, convert current strategy tokens to ETH
            ethConverted = _convertStrategyTokensToEth(totalTokenStored(), deadline);
        }

        _strategyToken = strategyToken_;
        (address strategyReserve, , ) = protocolAddress.getReserveTokensAddresses(strategyToken_);

        _strategyReserve = strategyReserve;
        
        if(ethConverted != 0){
            _convertEthToStrategyTokens(ethConverted, deadline);
        }

        // if(_strategyReserve != address(0x00)){
            emit SetToken(oldStrategyTokens, oldStrategyReserve, _strategyToken, _strategyReserve, totalTokenStored());
        // }
    }

    /**
     * @dev Withdraw DRC by DR-POD amount to burn.
     * @param podToBurn Amount of DR-POD to burn in exchange for DRC.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _withdrawProofOfDeposit(uint256 podToBurn, uint32 deadline) private {
        uint256 strategyTokensToWithdraw = _getStrategyTokensByPodAmount(podToBurn);

        _burn(msg.sender, podToBurn);

        uint256 ethConverted = _convertStrategyTokensToEth(strategyTokensToWithdraw, deadline);
        uint256 fees = ethConverted.mul(_feeFraction).div(_feeBase + _feeFraction);

        uint256 drcAmount = _convertEthToToken(ethConverted.sub(fees), drcAddress, deadline);

        /** For the production mode, it is better */
        // SafeERC20.safeTransfer(IERC20(drcAddress), msg.sender, drcAmount);
        // SafeERC20.safeTransfer(IERC20(uniswapRouter.WETH()), owner(), fees);

        /** For the test mode, it is better to test and debug. */
        IERC20(drcAddress).transfer(msg.sender, drcAmount);
        IERC20(uniswapRouter.WETH()).transfer(owner(), fees);

        emit Withdraw(msg.sender, drcAmount, fees, podToBurn, totalSupply(), totalTokenStored());
    }

    /**
     * @dev Get ETH worth of a certain amount of a token.
     * @param _amount Amount of token to convert.
     * @param _fromAddress Address of token to convert from.
     * @param _toAddress Address of token to convert to.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getAAmountByBAmount(
        uint256 _amount,
        address _fromAddress,
        address _toAddress,
        bool excludeFees
    ) private view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = _fromAddress;
        path[1] = _toAddress;

        if (path[0] == path[1] || _amount == 0) {
            return _amount;
        }

        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];

        if (excludeFees) {
            return amountOut.mul(1000).div(997);
        } else {
            return amountOut;
        }
    }

    /**
     * @dev Get the worth in a token of a certain amount of ETH.
     * @param _amount Amount of ETH to convert.
     * @param _tokenAddress Address of the token to convert to.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getTokenAmountByEthAmount(
        uint256 _amount,
        address _tokenAddress,
        bool excludeFees
    ) private view returns (uint256) {
        return _getAAmountByBAmount(_amount, uniswapRouter.WETH(), _tokenAddress, excludeFees);
    }

    /**
     * @dev Get ETH worth of a certain amount of a token.
     * @param _amount Amount of token to convert.
     * @param _tokenAddress Address of token to convert from.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getEthAmountByTokenAmount(
        uint256 _amount,
        address _tokenAddress,
        bool excludeFees
    ) private view returns (uint256) {
        return _getAAmountByBAmount(_amount, _tokenAddress, uniswapRouter.WETH(), excludeFees);
    }

    /**
     * @dev Get DR-POD worth in an array of strategy tokens.
     * @param _amount Amount of DR-POD to convert.
     */
    function _getStrategyTokensByPodAmount(uint256 _amount) private view returns (uint256) {
        uint256 strategyTokenAmount = 0;

        uint256 podFraction = 0;
        if(totalSupply() > 0){
            podFraction = _amount.mul(1e10).div(totalSupply());
        }
        strategyTokenAmount = IERC20(_strategyReserve).balanceOf(address(this)).mul(podFraction).div(1e10);
        return strategyTokenAmount;
    }

    /**
     * @dev Convert a token to WETH via the Uniswap router.
     * @param _amount Amount of tokens to swap.
     * @param _tokenAddress Address of token to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertTokenToEth(
        uint256 _amount,
        address _tokenAddress,
        uint32 deadline
    ) private returns (uint256) {
        if (_tokenAddress == uniswapRouter.WETH() || _amount == 0) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = uniswapRouter.WETH();

        /** For the production mode, it is better */
        // SafeERC20.safeApprove(IERC20(path[0]), address(uniswapRouter), _amount);

        /** For the test mode, it is better to test and debug */
        IERC20(path[0]).approve(address(uniswapRouter), _amount);

        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];
        uint256 amountOutWithFeeTolerance = amountOut.mul(999).div(1000);
        uint256 ethBeforeSwap = IERC20(path[1]).balanceOf(address(this));
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, amountOutWithFeeTolerance, path, address(this), deadline);
        uint256 ethAfterSwap = IERC20(path[1]).balanceOf(address(this));
        return ethAfterSwap - ethBeforeSwap;
    }

    /**
     * @dev Convert ETH to another token via the Uniswap router.
     * @param _amount Amount of WETH to swap.
     * @param _tokenAddress Address of token to swap to.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertEthToToken(
        uint256 _amount,
        address _tokenAddress,
        uint32 deadline
    ) private returns (uint256) {
        if (_tokenAddress == uniswapRouter.WETH() || _amount == 0) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = _tokenAddress;

        /** For the production mode, it is better */
        // SafeERC20.safeApprove(IERC20(path[0]), address(uniswapRouter), _amount);

        /** For the test mode, it is better to test and debug */
        IERC20(path[0]).approve(address(uniswapRouter), _amount);

        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];
        uniswapRouter.swapExactTokensForTokens(_amount, amountOut, path, address(this), deadline);
        return amountOut;
    }

    /**
     * @dev Convert ETH to strategy tokens of DR in their allocation percentage.
     * @param amount Amount of WETH to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertEthToStrategyTokens(
        uint256 amount, 
        uint32 deadline
    ) private returns (uint256) {
        uint256 EthToTokenAmount = _convertEthToToken(amount, _strategyToken, deadline);

        uint16 referralCode = 0;
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());

        /** For the production mode, it is better */
        // SafeERC20.safeApprove(IERC20(_strategyToken), address(lendingPoolProvider), amount);

        /** For the test mode, it is better to test and debug */
        IERC20(_strategyToken).approve(address(lendingPool), EthToTokenAmount);

        lendingPool.deposit(_strategyToken, EthToTokenAmount, address(this), referralCode);
    }

    /**
     * @dev Convert strategy tokens to WETH.
     * @param amountToConvert Array of the amounts of strategy tokens to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertStrategyTokensToEth(
        uint256 amountToConvert, 
        uint32 deadline
    ) private returns (uint256) {
        uint256 ethConverted = 0;

        uint256 getStrategyToken = 0;
        ILendingPool lendingPool = ILendingPool(lendingPoolProvider.getLendingPool());
        getStrategyToken = lendingPool.withdraw(_strategyToken, amountToConvert, address(this));

        ethConverted = _convertTokenToEth(getStrategyToken, _strategyToken, deadline);
        return ethConverted;
    }
}
