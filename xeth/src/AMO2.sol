// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/access/AccessControl.sol";
import "./interfaces/ICurvePool.sol";
import {xETH as xETH_CONTRACT} from "./xETH.sol";
import {CVXStaker} from "./CVXStaker.sol";

contract xETH_AMO is AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Thrown when the xETH-stETH LP balance of the AMO is too low for the rebalancing operation.
    error LpBalanceTooLow();

    /// @notice Thrown when either the stETH or xETH balance in the pool is zero, which would prevent rebalancing.
    error ZeroBalancePool();

    /// @notice Thrown when a zero address is provided as an input, which is not allowed.
    error ZeroAddressProvided();

    /// @notice Thrown when a function is called with a zero value, which is not allowed.
    error ZeroValueProvided();

    /// @notice Thrown when an invalid slippage value is provided, outside the allowed range.
    error InvalidSlippageBPS();

    /// @notice Thrown when a rebalance attempt is made before the cooldown period has finished.
    error CooldownNotFinished();

    /// @notice Thrown when a rebalance attempt is made, but the current pool ratios do not require rebalancing.
    error RebalanceNotRequired();

    /// @notice Thrown when a rebalanceUp operation is not allowed based on the current pool ratios.
    error RebalanceUpNotAllowed();

    /// @notice Thrown when a rebalanceDown operation is not allowed based on the current pool ratios.
    error RebalanceDownNotAllowed();

    /// @notice Thrown when the requested rebalanceUp operation exceeds the allowed rebalanceUpCap.
    error RebalanceUpCapExceeded();

    /// @notice Thrown when the requested rebalanceDown operation exceeds the allowed rebalanceDownCap.
    error RebalanceDownCapExceeded();

    /// @notice Emitted when a rebalanceUp operation is performed.
    /// @param quote The chosen quote for rebalancing.
    /// @param xETHamountReceived The actual amount of xETH received after burning LP tokens.
    event RebalanceUpFinished(
        RebalanceUpQuote quote,
        uint256 xETHamountReceived
    );

    /// @notice Emitted when a rebalanceDown operation is performed.
    /// @param quote The chosen quote for rebalancing.
    /// @param lpAmountReceived The actual amount of xETH-stETH LP tokens received after minting xETH.
    event RebalanceDownFinished(
        RebalanceDownQuote quote,
        uint256 lpAmountReceived
    );

    /// @notice Emitted when the defender address is updated.
    /// @param oldDefender The previous defender address.
    /// @param newDefender The new defender address.
    event DefenderUpdated(address oldDefender, address newDefender);

    /// @notice Emitted when the maxSlippageBPS is updated.
    /// @param oldMaxSlippageBPS The previous max slippage value.
    /// @param newMaxSlippageBPS The new max slippage value.
    event MaxSlippageBPSUpdated(
        uint256 oldMaxSlippageBPS,
        uint256 newMaxSlippageBPS
    );

    /// @notice Emitted when the rebalanceUpCap is updated.
    /// @param oldRebalanceUpCap The previous rebalanceUpCap value.
    /// @param newRebalanceUpCap The new rebalanceUpCap value.
    event RebalanceUpCapUpdated(
        uint256 oldRebalanceUpCap,
        uint256 newRebalanceUpCap
    );

    /// @notice Emitted when the rebalanceDownCap is updated.
    /// @param oldRebalanceDownCap The previous rebalanceDownCap value.
    /// @param newRebalanceDownCap The new rebalanceDownCap value.
    event RebalanceDownCapUpdated(
        uint256 oldRebalanceDownCap,
        uint256 newRebalanceDownCap
    );

    /// @notice Emitted when the cooldownBlocks is updated.
    /// @param oldCooldownBlocks The previous cooldownBlocks value.
    /// @param newCooldownBlocks The new cooldownBlocks value.
    event CooldownBlocksUpdated(
        uint256 oldCooldownBlocks,
        uint256 newCooldownBlocks
    );

    /// @notice Emitted when the CVXStaker address is updated.
    /// @param oldCVXStaker The previous CVXStaker address.
    /// @param newCVXStaker The new CVXStaker address.
    event CVXStakerUpdated(address oldCVXStaker, address newCVXStaker);

    /// @notice Emitted when the rebalance up threshold is set.
    /// @param oldThreshold The old rebalance up threshold.
    /// @param newThreshold The new rebalance up threshold.
    event SetRebalanceUpThreshold(uint256 oldThreshold, uint256 newThreshold);

    /// @notice Emitted when the rebalance down threshold is set.
    /// @param oldThreshold The old rebalance down threshold.
    /// @param newThreshold The new rebalance down threshold.
    event SetRebalanceDownThreshold(uint256 oldThreshold, uint256 newThreshold);

    /// @dev REBALANCE_DEFENDER_ROLE is the role that allows the defender to call rebalance()
    bytes32 public constant REBALANCE_DEFENDER_ROLE =
        keccak256("REBALANCE_DEFENDER_ROLE");

    /// @dev BASE_UNIT is the base unit used for calculations (1E18)
    uint256 public constant BASE_UNIT = 1E18;

    /// @dev xETHIndex is the index of xETH in the Curve pool
    uint256 public immutable xETHIndex;

    /// @dev stETHIndex is the index of stETH in the Curve pool
    uint256 public immutable stETHIndex;

    /// @dev xETH is the xETH token contract
    xETH_CONTRACT public immutable xETH;

    /// @dev stETH is the stETH token contract
    IERC20 public immutable stETH;

    /// @dev curvePool is the Curve pool contract
    ICurvePool public immutable curvePool;

    /// @dev maxSlippageBPS is the maximum slippage allowed when rebalancing
    /// @notice 1E14 = 1 BPS
    uint256 public maxSlippageBPS = 100 * 1E14;

    /// @dev rebalanceUpCap is the maximum amount of xETH-stETH LP that can be burnt in a single rebalance
    uint256 public rebalanceUpCap;

    /// @dev rebalanceDownCap is the maximum amount of xETH that can be minted in a single rebalance
    uint256 public rebalanceDownCap;

    /// @dev lastRebalanceBlock is the block number of the last rebalance
    uint256 public lastRebalanceBlock;

    /// @dev cooldownBlocks is the number of blocks that must pass between rebalances
    uint256 public cooldownBlocks = 1800; /// (6 * 60 * 60) / 12

    /// @dev REBALANCE_UP_THRESHOLD is the upper threshold for the xETH-stETH LP ratio
    /// @notice if the ratio is above this value, rebalanceUp() will be called
    uint256 public REBALANCE_UP_THRESHOLD = 0.75E18;

    /// @dev REBALANCE_DOWN_THRESHOLD is the lower threshold for the xETH-stETH LP ratio
    /// @notice if the ratio is below this value, rebalanceDown() will be called
    uint256 public REBALANCE_DOWN_THRESHOLD = 0.68E18;

    /// @dev defender is the whitelisted bot that can call rebalance()
    address public defender;

    /// @dev cvxStaker is the CVX staking contract
    CVXStaker public cvxStaker;

    /// @dev afterCooldownPeriod is a modifier that checks if the cooldown period has passed
    modifier afterCooldownPeriod() {
        if (lastRebalanceBlock + cooldownBlocks >= block.number)
            revert CooldownNotFinished();
        _;
        lastRebalanceBlock = block.number;
    }

    constructor(
        address _xETH,
        address _stETH,
        address _curvePool,
        address _cvxStaker,
        bool isXETHToken0
    ) {
        if (
            _xETH == address(0) ||
            _stETH == address(0) ||
            _curvePool == address(0) ||
            _cvxStaker == address(0)
        ) {
            revert ZeroAddressProvided();
        }

        xETH = xETH_CONTRACT(_xETH);
        stETH = IERC20(_stETH);
        curvePool = ICurvePool(_curvePool);
        cvxStaker = CVXStaker(_cvxStaker);

        xETHIndex = isXETHToken0 ? 0 : 1;
        stETHIndex = isXETHToken0 ? 1 : 0;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @dev preRebalanceCheck checks if a rebalance is even allowed based on pool ratios
    function preRebalanceCheck() internal view returns (bool isRebalanceUp) {
        uint256 stETHBal = curvePool.balances(stETHIndex);
        uint256 xETHBal = curvePool.balances(xETHIndex);

        /// @notice if either token balance is 0, the pool shall not be rebalanced
        if (stETHBal == 0 || xETHBal == 0) revert ZeroBalancePool();

        uint256 xEthPct = (xETHBal * BASE_UNIT) / (stETHBal + xETHBal);

        /// @notice if the ratio is above the upper threshold, rebalanceUp() will be called
        if (xEthPct > REBALANCE_UP_THRESHOLD) {
            isRebalanceUp = true;
        }
        /// @notice if the ratio is below the lower threshold, rebalanceDown() will be called
        /// @notice possible gas optimization here.
        else if (xEthPct < REBALANCE_DOWN_THRESHOLD) {
            isRebalanceUp = false;
        }
        /// @notice if the ratio is within the thresholds, the pool shall not be rebalanced
        else {
            revert RebalanceNotRequired();
        }
    }

    struct RebalanceUpQuote {
        uint256 lpBurn;
        uint256 min_xETHReceived;
    }

    /**
     * @dev Executes a rebalance up operation, which burns xETH-stETH LP to receive xETH.
     * @param quote The quote for the rebalance operation provided by the rebalance defender.
     * @return xETHReceived The amount of xETH received from the rebalance operation.
     * @notice Only the rebalance defender can call this function.
     * @notice The rebalance operation can only be performed after the cooldown period has elapsed.
     */
    function rebalanceUp(
        RebalanceUpQuote memory quote
    )
        external
        onlyRole(REBALANCE_DEFENDER_ROLE)
        afterCooldownPeriod
        returns (uint256 xETHReceived)
    {
        if (quote.lpBurn == 0) revert ZeroValueProvided();

        bool isRebalanceUp = preRebalanceCheck();
        if (!isRebalanceUp) revert RebalanceUpNotAllowed();

        if (quote.lpBurn > rebalanceUpCap) revert RebalanceUpCapExceeded();

        quote = bestRebalanceUpQuote(quote);

        uint256 amoLpBal = cvxStaker.stakedBalance();

        // if (amoLpBal == 0 || quote.lpBurn > amoLpBal) revert LpBalanceTooLow();
        if (quote.lpBurn > amoLpBal) revert LpBalanceTooLow();

        cvxStaker.withdrawAndUnwrap(quote.lpBurn, false, address(this));

        xETHReceived = curvePool.remove_liquidity_one_coin(
            quote.lpBurn,
            int128(int(xETHIndex)),
            quote.min_xETHReceived
        );

        xETH.burnShares(xETHReceived);

        emit RebalanceUpFinished(quote, xETHReceived);
    }

    struct RebalanceDownQuote {
        uint256 xETHAmount;
        uint256 minLpReceived;
    }

    /**
     * @dev Executes a rebalance down operation, which mints xETH and deposits into the Curve pool.
     * @param quote The quote for the rebalance operation provided by the rebalance defender.
     * @return lpAmountOut The amount of LP tokens received from the rebalance operation.
     * @notice Only the rebalance defender can call this function.
     * @notice The rebalance operation can only be performed after the cooldown period has elapsed.
     */
    function rebalanceDown(
        RebalanceDownQuote memory quote
    )
        external
        onlyRole(REBALANCE_DEFENDER_ROLE)
        afterCooldownPeriod
        returns (uint256 lpAmountOut)
    {
        if (quote.xETHAmount == 0) revert ZeroValueProvided();

        bool isRebalanceUp = preRebalanceCheck();
        if (isRebalanceUp) revert RebalanceDownNotAllowed();

        if (quote.xETHAmount > rebalanceDownCap)
            revert RebalanceDownCapExceeded();

        quote = bestRebalanceDownQuote(quote);

        xETH.mintShares(quote.xETHAmount);

        uint256[2] memory amounts;
        amounts[xETHIndex] = quote.xETHAmount;

        IERC20(address(xETH)).approve(address(curvePool), quote.xETHAmount);

        lpAmountOut = curvePool.add_liquidity(amounts, quote.minLpReceived);

        IERC20(address(curvePool)).safeTransfer(
            address(cvxStaker),
            lpAmountOut
        );
        cvxStaker.depositAndStake(lpAmountOut);

        emit RebalanceDownFinished(quote, lpAmountOut);
    }

    /// @dev applySlippage applies the maxSlippageBPS to the amount provided
    function applySlippage(uint256 amount) internal view returns (uint256) {
        return (amount * (BASE_UNIT - maxSlippageBPS)) / BASE_UNIT;
    }

    /**
     * @dev Finds the best quote for rebalancing upwards.
     * @param defenderQuote The quote provided by the rebalance defender.
     * @return The best quote for rebalancing upwards.
     * @notice This function is internal and cannot be called outside of the contract.
     * @notice the defenderQuote should ideally be better than the contractQuote
     * @notice if its not, the contractQuote gets executed as a safeguard, reducing the risk of a large sandwich
     */
    function bestRebalanceUpQuote(
        RebalanceUpQuote memory defenderQuote
    ) internal view returns (RebalanceUpQuote memory) {
        RebalanceUpQuote memory bestQuote;
        uint256 vp = curvePool.get_virtual_price();

        /// @dev first lets fill the bestQuote with the contractQuote
        bestQuote.lpBurn = defenderQuote.lpBurn;
        bestQuote.min_xETHReceived = applySlippage(
            (vp * defenderQuote.lpBurn) / BASE_UNIT
        );

        if (defenderQuote.min_xETHReceived > bestQuote.min_xETHReceived)
            bestQuote.min_xETHReceived = defenderQuote.min_xETHReceived;

        return bestQuote;
    }

    /**
     * @dev Finds the best quote for rebalancing downwards.
     * @param defenderQuote The quote provided by the rebalance defender.
     * @return The best quote for rebalancing downwards.
     * @notice the defenderQuote should ideally be better than the contractQuote
     * @notice if its not, the contractQuote gets executed as a safeguard, reducing the risk of a large sandwich
     */
    function bestRebalanceDownQuote(
        RebalanceDownQuote memory defenderQuote
    ) internal view returns (RebalanceDownQuote memory) {
        RebalanceDownQuote memory bestQuote;
        uint256 vp = curvePool.get_virtual_price();

        /// @dev first lets fill the bestQuote with the contractQuote
        bestQuote.xETHAmount = defenderQuote.xETHAmount;
        bestQuote.minLpReceived = applySlippage(
            (BASE_UNIT * defenderQuote.xETHAmount) / vp
        );

        if (defenderQuote.minLpReceived > bestQuote.minLpReceived)
            bestQuote.minLpReceived = defenderQuote.minLpReceived;

        return bestQuote;
    }

    /**
     * @dev Sets the address of the rebalance defender.
     * @param newDefender The new rebalance defender address to be set.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice The new rebalance defender address cannot be set to the zero address.
     * @notice If a previous defender was set, their `REBALANCE_DEFENDER_ROLE` is revoked and transferred to the new defender.
     * @notice Emits a `DefenderUpdated` event.
     */
    function setRebalanceDefender(
        address newDefender
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newDefender == address(0)) revert ZeroAddressProvided();

        if (defender != address(0)) {
            _revokeRole(REBALANCE_DEFENDER_ROLE, defender);
        }

        emit DefenderUpdated(defender, newDefender);

        defender = newDefender;
        _grantRole(REBALANCE_DEFENDER_ROLE, newDefender);
    }

    /**
     * @dev Sets the maximum allowable slippage in basis points for trading.
     * @param newMaxSlippageBPS The new maximum slippage in basis points to be set.
     * @notice 1 BPS = 1E14
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice The new maximum slippage must be between 0.06% and 15% (in basis points).
     * @notice Emits a `MaxSlippageBPSUpdated` event.
     */
    function setMaxSlippageBPS(
        uint256 newMaxSlippageBPS
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        /// @dev the allowed minimum slippage is 0.06% and the maximum slippage is 15%
        if (newMaxSlippageBPS < 6E14 || newMaxSlippageBPS > 1500E14) {
            revert InvalidSlippageBPS();
        }

        emit MaxSlippageBPSUpdated(maxSlippageBPS, newMaxSlippageBPS);

        maxSlippageBPS = newMaxSlippageBPS;
    }

    /**
     * @dev Sets the maximum burning cap (rebalanceUp) in a single transaction.
     * @param newRebalanceUpCap The new rebalance up cap to be set.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice The new rebalance up cap cannot be set to zero.
     * @notice Emits a `RebalanceUpCapUpdated` event.
     */
    function setRebalanceUpCap(
        uint256 newRebalanceUpCap
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRebalanceUpCap == 0) revert ZeroValueProvided();

        emit RebalanceUpCapUpdated(rebalanceUpCap, newRebalanceUpCap);

        rebalanceUpCap = newRebalanceUpCap;
    }

    /**
     * @dev Sets the maximum minting cap (rebalanceDown) in a single transaction.
     * @param newRebalanceDownCap The new rebalance down cap to be set.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice The new rebalance down cap cannot be set to zero.
     * @notice Emits a `RebalanceDownCapUpdated` event.
     */
    function setRebalanceDownCap(
        uint256 newRebalanceDownCap
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRebalanceDownCap == 0) revert ZeroValueProvided();

        emit RebalanceDownCapUpdated(rebalanceDownCap, newRebalanceDownCap);

        rebalanceDownCap = newRebalanceDownCap;
    }

    /**
     * @dev Sets the number of blocks for the unstake cooldown period
     * @param newCooldownBlocks The new number of blocks for the unstake cooldown period
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice Emits a CooldownBlocksUpdated event with the old and new cooldown block values
     */
    function setCooldownBlocks(
        uint256 newCooldownBlocks
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newCooldownBlocks == 0) revert ZeroValueProvided();

        emit CooldownBlocksUpdated(cooldownBlocks, newCooldownBlocks);

        cooldownBlocks = newCooldownBlocks;
    }

    /**
     * @dev Sets the CVX staking contract address
     * @param _cvxStaker The address of the CVX staking contract
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @notice The new CVX staker contract address cannot be set to the zero address.
     * @notice Emits a `CVXStakerUpdated` event.
     */
    function setCvxStaker(
        address _cvxStaker
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_cvxStaker == address(0)) revert ZeroAddressProvided();

        emit CVXStakerUpdated(address(cvxStaker), _cvxStaker);

        cvxStaker = CVXStaker(_cvxStaker);
    }

    /**
     * @dev Sets the threshold for triggering a `rebalanceUp` operation.
     * @param newRebalanceUpThreshold The new threshold to be set.
     * @notice Emits a `SetRebalanceUpThreshold` event with the old and new thresholds.
     * @notice Requires the caller to have the `DEFAULT_ADMIN_ROLE`.
     */
    function setRebalanceUpThreshold(
        uint256 newRebalanceUpThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit SetRebalanceUpThreshold(
            REBALANCE_UP_THRESHOLD,
            newRebalanceUpThreshold
        );

        REBALANCE_UP_THRESHOLD = newRebalanceUpThreshold;
    }

    /**
     * @dev Sets the threshold for triggering a `rebalanceDown` operation.
     * @param newRebalanceDownThreshold The new threshold to be set.
     * @notice Emits a `SetRebalanceDownThreshold` event with the old and new thresholds.
     * @notice Requires the caller to have the `DEFAULT_ADMIN_ROLE`.
     */
    function setRebalanceDownThreshold(
        uint256 newRebalanceDownThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit SetRebalanceDownThreshold(
            REBALANCE_DOWN_THRESHOLD,
            newRebalanceDownThreshold
        );

        REBALANCE_DOWN_THRESHOLD = newRebalanceDownThreshold;
    }

    /**
     * @dev Adds liquidity to the Curve pool using both xETH and stETH and stakes the resulting LP tokens in the CVX staking contract
     * @param stETHAmount The amount of stETH to be deposited
     * @param xETHAmount The amount of xETH to be deposited
     * @param minLpOut The minimum amount of LP tokens to receive from the Curve pool
     * @notice Transfers stETH and xETH from the caller to this contract, adds liquidity to the Curve pool, and stakes the resulting LP tokens in the CVX staking contract.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @return lpOut The amount of LP tokens received from the Curve pool
     */
    function addLiquidity(
        uint256 stETHAmount,
        uint256 xETHAmount,
        uint256 minLpOut
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 lpOut) {
        stETH.safeTransferFrom(msg.sender, address(this), stETHAmount);
        xETH.mintShares(xETHAmount);

        uint256[2] memory amounts;

        amounts[xETHIndex] = xETHAmount;
        amounts[stETHIndex] = stETHAmount;

        IERC20(address(xETH)).safeApprove(address(curvePool), xETHAmount);
        stETH.safeApprove(address(curvePool), stETHAmount);

        lpOut = curvePool.add_liquidity(amounts, minLpOut);

        /// @notice no need for safeApprove, direct transfer + deposit
        IERC20(address(curvePool)).safeTransfer(address(cvxStaker), lpOut);
        cvxStaker.depositAndStake(lpOut);
    }

    /**
     * @notice Adds liquidity only with stETH and stakes the resulting LP tokens in the cvxCRV staking contract.
     * @param stETHAmount The amount of stETH to add as liquidity.
     * @param minLpOut The minimum expected amount of LP tokens to receive.
     * @return lpOut The actual amount of LP tokens received.
     */
    function addLiquidityOnlyStETH(
        uint256 stETHAmount,
        uint256 minLpOut
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 lpOut) {
        stETH.safeTransferFrom(msg.sender, address(this), stETHAmount);

        uint256[2] memory amounts;

        amounts[stETHIndex] = stETHAmount;

        stETH.safeApprove(address(curvePool), stETHAmount);

        lpOut = curvePool.add_liquidity(amounts, minLpOut);

        /// @notice no need for safeApprove, direct transfer + deposit
        IERC20(address(curvePool)).safeTransfer(address(cvxStaker), lpOut);
        cvxStaker.depositAndStake(lpOut);
    }

    /**
     * @dev Removes liquidity from the Curve pool using both xETH and stETH and transfers the resulting tokens to the caller
     * @param lpAmount The amount of LP tokens to be burned
     * @param minStETHOut The minimum amount of stETH to receive from the Curve pool
     * @param minXETHOut The minimum amount of xETH to receive from the Curve pool
     * @notice Checks if the AMO owns enough LP tokens, withdraws and unwraps them, and removes liquidity from the Curve pool.
     *      The resulting xETH and stETH are then transferred to the caller.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     * @return outputs An array containing the resulting amounts of xETH and stETH received from the Curve pool
     */
    function removeLiquidity(
        uint256 lpAmount,
        uint256 minStETHOut,
        uint256 minXETHOut
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256[2] memory outputs)
    {
        /// @dev check if AMO owns enough LP
        uint256 amoBalance = cvxStaker.stakedBalance();

        if (lpAmount > amoBalance) {
            revert LpBalanceTooLow();
        }

        cvxStaker.withdrawAndUnwrap(lpAmount, false, address(this));

        uint256[2] memory minAmounts;

        minAmounts[xETHIndex] = minXETHOut;
        minAmounts[stETHIndex] = minStETHOut;

        outputs = curvePool.remove_liquidity(lpAmount, minAmounts);

        xETH.burnShares(outputs[xETHIndex]);
        stETH.safeTransfer(msg.sender, outputs[stETHIndex]);
    }

    /**
     * @dev Removes liquidity from the Curve pool using only stETH and transfers the resulting stETH to the caller
     * @param lpAmount The amount of LP tokens to be burned
     * @param minStETHOut The minimum amount of stETH to receive from the Curve pool
     * @notice Checks if the AMO owns enough LP tokens, withdraws and unwraps them, and removes liquidity from the Curve pool.
     *      The resulting stETH is then transferred to the caller.
     * @notice Only callable by a user with the DEFAULT_ADMIN_ROLE
     */
    function removeLiquidityOnlyStETH(
        uint256 lpAmount,
        uint256 minStETHOut
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        /// @dev check if AMO owns enough LP
        uint256 amoBalance = cvxStaker.stakedBalance();

        if (lpAmount > amoBalance) {
            revert LpBalanceTooLow();
        }

        cvxStaker.withdrawAndUnwrap(lpAmount, false, address(this));

        uint256[2] memory minAmounts;

        minAmounts[stETHIndex] = minStETHOut;

        uint256 output = curvePool.remove_liquidity_one_coin(
            lpAmount,
            int128(int(stETHIndex)),
            minStETHOut
        );

        stETH.safeTransfer(msg.sender, output);
    }
}
