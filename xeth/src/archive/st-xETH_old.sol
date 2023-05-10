// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract StakedxETH is ERC20 {
    using SafeERC20 for ERC20;

    error AddressZeroProvided();
    error InitialExchangeRateTooLow();
    error IncreasePerBlockTooLow();
    ERC20 public immutable xETH;
    /// @dev 1 st-xETH = exchangeRate / 1e18 xETH
    uint256 public exchangeRate;
    uint256 public lastAccrualBlock;
    uint256 public increasePerBlock;

    constructor(
        ERC20 xETH_,
        uint256 exchangeRate_,
        uint256 increasePerBlock_
    ) ERC20("Staked xEther", "st-xETH") {
        if (address(xETH_) == address(0)) revert AddressZeroProvided();
        if (1e18 > exchangeRate_) revert InitialExchangeRateTooLow();
        if (increasePerBlock_ == 0) revert IncreasePerBlockTooLow();

        xETH = xETH_;
        lastAccrualBlock = block.number;
        increasePerBlock = increasePerBlock_;
    }

    function _accrue() internal {
        uint256 blockDelta = block.number - lastAccrualBlock;
        uint256 newExchangeRate = exchangeRate +
            (blockDelta * increasePerBlock);

        // @todo emit

        lastAccrualBlock = block.number;
        exchangeRate = newExchangeRate;
    }

    modifier accrue() {
        _accrue();
        _;
    }

    function stake(uint256 amount) external accrue {
        xETH.safeTransferFrom(msg.sender, address(this), amount);
        uint256 amountToMint = (amount * 1e18) / exchangeRate;

        _mint(msg.sender, amountToMint);
    }

    function unstake(uint256 amount) external accrue {
        uint256 amountToSend = (amount * exchangeRate) / 1e18;

        _burn(msg.sender, amount);
        xETH.safeTransfer(msg.sender, amountToSend);
    }
}
