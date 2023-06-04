// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/access/Ownable.sol";
import "./interfaces/ICurvePool.sol";
import "./interfaces/ICVXBooster.sol";
import "./interfaces/IBaseRewardPool.sol";

contract CVXStaker is Ownable {
    using SafeERC20 for IERC20;

    address public operator;
    // @notice CLP tokens for curve pool
    IERC20 public immutable clpToken;
    CvxPoolInfo public cvxPoolInfo;
    // @notice Cvx booster
    ICVXBooster public immutable booster;

    address public rewardsRecipient;
    address[] public rewardTokens;

    struct CvxPoolInfo {
        address token;
        address rewards;
        uint32 pId;
    }

    struct Position {
        uint256 staked;
        uint256 earned;
    }

    error NotOperator();
    error NotOperatorOrOwner();

    event SetCvxPoolInfo(uint32 indexed pId, address token, address rewards);
    event SetOperator(address operator);
    event RecoveredToken(address token, address to, uint256 amount);
    event SetRewardsRecipient(address recipient);

    constructor(
        address _operator,
        IERC20 _clpToken,
        ICVXBooster _booster,
        address[] memory _rewardTokens
    ) {
        operator = _operator;
        clpToken = _clpToken;
        booster = _booster;
        rewardTokens = _rewardTokens;
    }

    /**
     * @dev Sets the CVX pool information.
     * @param _pId The pool ID of the CVX pool.
     * @param _token The address of the CLP token.
     * @param _rewards The address of the CVX reward pool.
     * Only the contract owner can call this function.
     */
    function setCvxPoolInfo(
        uint32 _pId,
        address _token,
        address _rewards
    ) external onlyOwner {
        cvxPoolInfo.pId = _pId;
        cvxPoolInfo.token = _token;
        cvxPoolInfo.rewards = _rewards;

        emit SetCvxPoolInfo(_pId, _token, _rewards);
    }

    /**
     * @notice Set operator
     * @param _operator New operator
     */
    function setOperator(address _operator) external onlyOwner {
        operator = _operator;

        emit SetOperator(_operator);
    }

    /**
     * @dev Sets the address of the rewards recipient.
     * @param _recipeint The address of the rewards recipient.
     * Only the contract owner can call this function.
     */
    function setRewardsRecipient(address _recipeint) external onlyOwner {
        rewardsRecipient = _recipeint;

        emit SetRewardsRecipient(_recipeint);
    }

    /**
     * @notice Recover any token from cvxStaker 
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);

        emit RecoveredToken(token, to, amount);
    }

    /**
     * @dev Checks whether the CVX pool is currently shutdown.
     * @return A boolean indicating whether the CVX pool is currently shutdown.
     */
    function isCvxShutdown() public view returns (bool) {
        // It's not necessary to check that the booster itself is shutdown, as that can only
        // be shutdown once all the pools are shutdown - see Cvx BoosterOwner.shutdownSystem()
        return booster.poolInfo(cvxPoolInfo.pId).shutdown;
    }

    /**
     * @dev Deposits a specified amount of CLP tokens into the booster and stakes them in the reward pool.
     * @param amount The amount of CLP tokens to deposit and stake.
     * Only the operator can call this function.
     */
    function depositAndStake(uint256 amount) external onlyOperator {
        // Only deposit if the aura pool is open. Otherwise leave the CLP Token in this contract.
        if (!isCvxShutdown()) {
            clpToken.safeIncreaseAllowance(address(booster), amount);
            booster.deposit(cvxPoolInfo.pId, amount, true);
        }
    }

    /**
     * @dev Withdraws a specified amount of staked tokens from the reward pool and unwraps them to the original tokens.
     * @param amount The amount of tokens to withdraw and unwrap.
     * @param claim A boolean indicating whether to claim rewards before withdrawing.
     * @param to The address to receive the unwrapped tokens.
     * If set to 0x0, the tokens will remain in the contract.
     * Only the contract owner or operator can call this function.
     */
    function withdrawAndUnwrap(
        uint256 amount,
        bool claim,
        address to
    ) external onlyOperatorOrOwner {
        // Optimistically use CLP balance in this contract, and then try and unstake any remaining
        uint256 clpBalance = clpToken.balanceOf(address(this));
        uint256 toUnstake = (amount < clpBalance) ? 0 : amount - clpBalance;
        if (toUnstake > 0) {
            IBaseRewardPool(cvxPoolInfo.rewards).withdrawAndUnwrap(
                toUnstake,
                claim
            );
        }

        if (to != address(0)) {
            // unwrapped amount is 1 to 1
            clpToken.safeTransfer(to, amount);
        }
    }

    /**
     * @dev Withdraws all staked tokens from the reward pool and unwraps them to the original tokens.
     * @param claim A boolean indicating whether to claim rewards before withdrawing.
     * @param sendToOwner A boolean indicating whether to send the unwrapped tokens to the owner.
     * If false, the tokens will remain in the contract.
     * Only the contract owner can call this function.
     */
    function withdrawAllAndUnwrap(
        bool claim,
        bool sendToOwner
    ) external onlyOwner {
        IBaseRewardPool(cvxPoolInfo.rewards).withdrawAllAndUnwrap(claim);
        if (sendToOwner) {
            uint256 totalBalance = clpToken.balanceOf(address(this));
            /// @dev msg.sender is the owner, due to onlyOwner modifier
            clpToken.safeTransfer(msg.sender, totalBalance);
        }
    }

    /**
     * @dev Claims the rewards and transfers them to the rewards recipient, if specified.
     * @param claimExtras A boolean indicating whether to claim extra rewards.
     */
    function getReward(bool claimExtras) external {
        IBaseRewardPool(cvxPoolInfo.rewards).getReward(
            address(this),
            claimExtras
        );
        if (rewardsRecipient != address(0)) {
            for (uint i = 0; i < rewardTokens.length; i++) {
                uint256 balance = IERC20(rewardTokens[i]).balanceOf(
                    address(this)
                );
                IERC20(rewardTokens[i]).safeTransfer(rewardsRecipient, balance);
            }
        }
    }

    /**
     * @dev Returns the current staked balance of the contract.
     * @return balance The current staked balance.
     */
    function stakedBalance() public view returns (uint256 balance) {
        balance = IBaseRewardPool(cvxPoolInfo.rewards).balanceOf(address(this));
    }

    /**
     * @dev Returns the amount of earned rewards by the contract.
     * @return earnedRewards The amount of earned rewards.
     */
    function earned() public view returns (uint256 earnedRewards) {
        earnedRewards = IBaseRewardPool(cvxPoolInfo.rewards).earned(
            address(this)
        );
    }

    /**
     * @notice show staked position and earned rewards
     */
    function showPositions() external view returns (Position memory position) {
        position.staked = stakedBalance();
        position.earned = earned();
    }

    /// @dev Modifier to restrict function execution to only the contract operator.
    /// @notice Throws a custom exception `NotOperator` if the caller is not the operator.
    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NotOperator();
        }
        _;
    }

    /// @dev Modifier to restrict function execution to only the contract operator or owner.
    /// @notice Throws a custom exception `NotOperatorOrOwner` if the caller is neither the operator nor the owner.
    modifier onlyOperatorOrOwner() {
        if (msg.sender != operator && msg.sender != owner()) {
            revert NotOperatorOrOwner();
        }
        _;
    }
}
