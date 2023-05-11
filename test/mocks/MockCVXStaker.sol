// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/access/Ownable.sol";

/// @dev Mock CVX staker contract
contract MockCVXStaker is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public lp;
    address public operator;

    constructor(address _lp) {
        lp = IERC20(_lp);
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function stakedBalance() external view returns (uint256) {
        return lp.balanceOf(address(this));
    }

    function depositAndStake(uint256 lpAmount) external onlyOperator {
        /// @dev no need to do anything
        /// @notice since AMO uses `safeTransfer` to transfer LP tokens to staker
    }

    function withdrawAndUnwrap(
        uint256 amount,
        bool claim,
        address to
    ) external onlyOperator {
        uint256 clpBalance = lp.balanceOf(address(this));

        if (clpBalance < amount) revert("clpBalanace < amount");

        if (to != address(0)) {
            // unwrapped amount is 1 to 1
            lp.safeTransfer(to, amount);
        }
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "onlyOperator");
        _;
    }
}
