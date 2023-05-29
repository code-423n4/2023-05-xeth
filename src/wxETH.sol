// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/access/Ownable.sol";
import "solmate/utils/FixedPointMathLib.sol";

contract WrappedXETH is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /* --------------------------------- Events --------------------------------- */
    /// @dev emitted when the dripRatePerBlock is updated
    event UpdateDripRate(uint oldDripRatePerBlock, uint256 newDripRatePerBlock);
    /// @dev emitted when a sucessful accrueDrip is called
    event Drip(uint256 amountDripped, uint256 lockedFunds, uint256 totalFunds);
    /// @dev emitted when a user stakes xETH to receieve wxETH
    event Stake(
        address indexed user,
        uint256 xETHAmount,
        uint256 wxETHReceived
    );
    /// @dev emitted when a user unstakes wxETH to receieve xETH
    event Unstake(
        address indexed user,
        uint256 wxETHAmount,
        uint256 xETHReceived
    );

    /// @dev emitted when the dripping mechanism is started
    event DripStarted();
    /// @dev emitted when the dripping mechanism is stopped
    event DripStopped();

    /// @dev emitted when locked funds are added to the contract by the owner
    event LockedFundsAdded(uint256 amountAdded, uint256 totalLockedFunds);

    /* --------------------------------- Errors --------------------------------- */
    error AddressZeroProvided();
    error AmountZeroProvided();
    error DripAlreadyRunning();
    error DripAlreadyStopped();
    error CantMintZeroShares();

    /* -------------------------- Constants and Storage ------------------------- */

    /// @dev initial exchange rate of wxETH to xETH. Set to 1:1
    uint256 public constant INITIAL_EXCHANGE_RATE = 1E18; // exchange rate at begining is 1:1

    /// @dev Base unit of the xETH token
    uint256 public constant BASE_UNIT = 1E18;

    /// @dev Immutable ERC20 reference to the xETH token
    IERC20 public immutable xETH;

    /// @dev amount of xETH that are locked in the contract
    uint256 public lockedFunds;
    /// @dev amount of xETH that will be dripped per block
    uint256 public dripRatePerBlock;
    /// @dev block number of the last drip
    uint256 public lastReport;
    /// @dev is dripping enabled in the contract?
    bool public dripEnabled;

    /* ------------------------------- Constructor ------------------------------ */
    constructor(address xETHAddress) ERC20("Wrapped xETH", "wxETH") {
        /// @dev if the xETH address is address(0), revert
        if (xETHAddress == address(0)) revert AddressZeroProvided();

        /// @dev set the xETH reference
        xETH = IERC20(xETHAddress);

        /// @dev set the drip lastReport to current block
        lastReport = block.number;
    }

    /* --------------------------- External functions --------------------------- */

    /// @dev Preview the amount of wxETH that would be minted for a given xETH amount.
    /// @param xETHAmount The amount of xETH input.
    /// @return The amount of wxETH that would be minted.
    /// @notice Reverts if xETHAmount is 0.
    function previewStake(uint256 xETHAmount) public view returns (uint256) {
        /// @dev if xETHAmount is 0, revert.
        if (xETHAmount == 0) revert AmountZeroProvided();

        /// @dev calculate the amount of wxETH to mint before transfer
        return (xETHAmount * BASE_UNIT) / exchangeRate();
    }

    /// @dev stake allows for staking xETH in exchange for wxETH
    /// @notice this function can only be called by a user that has approved to spend xETH
    /// @notice this function can only be called if the xETHAmount provided is not 0
    /// @param xETHAmount amount of xETH to be staked
    function stake(uint256 xETHAmount) external drip returns (uint256) {
        /// @dev calculate the amount of wxETH to mint
        uint256 mintAmount = previewStake(xETHAmount);

        if (mintAmount == 0) {
          revert CantMintZeroShares();
        }

        /// @dev transfer xETH from the user to the contract
        xETH.safeTransferFrom(msg.sender, address(this), xETHAmount);

        /// @dev emit event
        emit Stake(msg.sender, xETHAmount, mintAmount);

        /// @dev mint the wxETH to the user
        _mint(msg.sender, mintAmount);

        return mintAmount;
    }

    /// @dev Preview the amount of xETH that would be returned for a given wxETH amount.
    /// @param wxETHAmount The amount of wxETH input.
    /// @return The amount of xETH that would be returned.
    /// @notice Reverts if wxETHAmount is 0.
    function previewUnstake(uint256 wxETHAmount) public view returns (uint256) {
        /// @dev if wxETHAmount is 0, revert.
        if (wxETHAmount == 0) revert AmountZeroProvided();

        /// @dev calculate the amount of xETH to return
        return (wxETHAmount * exchangeRate()) / BASE_UNIT;
    }

    /// @dev unstake allows for unstaking wxETH in exchange for xETH
    /// @notice this function can only be called if the wxETHAmount provided is not 0
    /// @param wxETHAmount amount of wxETH to be unstaked
    function unstake(uint256 wxETHAmount) external drip returns (uint256) {
        /// @dev calculate the amount of xETH to return
        uint256 returnAmount = previewUnstake(wxETHAmount);

        /// @dev emit event
        emit Unstake(msg.sender, wxETHAmount, returnAmount);

        /// @dev burn the wxETH from the user
        _burn(msg.sender, wxETHAmount);

        /// @dev return the xETH back to user
        xETH.safeTransfer(msg.sender, returnAmount);

        /// @dev return the amount of xETH sent to user
        return returnAmount;
    }

    /// @dev addLockedFunds allows for adding locked funds to the contract
    /// @notice this function can only be called by the owner
    /// @notice this function can only be called if the amount provided 
    /// @dev if amount is 0, revert.
    function addLockedFunds(uint256 amount) external onlyOwner drip {
        /// @dev if amount or _dripRatePerBlock is 0, revert.
        if (amount == 0) revert AmountZeroProvided();

        /// @dev transfer xETH from the user to the contract
        xETH.safeTransferFrom(msg.sender, address(this), amount);

        /// @dev add the amount to the locked funds variable
        uint256 cachedLockedFunds = lockedFunds + amount;
        lockedFunds = cachedLockedFunds;

        emit LockedFundsAdded(amount, cachedLockedFunds);
    }

    function setDripRate(uint256 newDripRatePerBlock) external onlyOwner drip {
        if (newDripRatePerBlock == 0) revert AmountZeroProvided();

        emit UpdateDripRate(dripRatePerBlock, newDripRatePerBlock);

        /// @dev set the drip rate per block
        dripRatePerBlock = newDripRatePerBlock;
    }

    /// @dev This function starts (or un-pauses) the drip mechanism
    /// @notice can be only called by the owner
    function startDrip() external onlyOwner {
        /// @dev if the drip is already running, revert
        if (dripEnabled) revert DripAlreadyRunning();

        dripEnabled = true;

        /// @dev set the drip lastReport to current block
        lastReport = block.number;

        emit DripStarted();
    }

    /// @dev This function stops (or pauses) the drip mechanism
    /// @notice can be only called by the owner
    function stopDrip() external onlyOwner drip {
        /// @dev if the drip is already stopped, revert
        if (!dripEnabled) revert DripAlreadyStopped();

        dripEnabled = false;

        /// @dev set the drip lastReport to current block
        lastReport = block.number;

        emit DripStopped();
    }

    /// @dev accrueDrip allows for manually triggering a drip
    // solhint-disable-next-line no-empty-blocks
    function accrueDrip() external drip {}

    /* ---------------------------- Public functions ---------------------------- */
    /// @dev exchangeRate returns the current exchange rate of wxETH to xETH
    function exchangeRate() public view returns (uint256) {
        /// @dev if there are no tokens minted, return the initial exchange rate
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            return INITIAL_EXCHANGE_RATE;
        }

        /// @dev calculate the cash on hand by removing locked funds from the total xETH balance
        /// @notice this balanceOf call will include any lockedFunds,
        /// @notice as the locked funds are also in xETH
        uint256 cashMinusLocked = xETH.balanceOf(address(this)) - lockedFunds;

        /// @dev return the exchange rate by dividing the cash on hand by the total supply
        return (cashMinusLocked * BASE_UNIT) / _totalSupply;
    }

    /* -------------------- Intenral functions and Modifiers -------------------- */

    /// @dev _accrueDrip calculates the amount of xETH to drip and updates
    /// @dev the lockedFunds and lastReport variables
    function _accrueDrip() private {
        /// @dev if drip is disabled, no need to accrue
        if (!dripEnabled) return;

        /// @dev blockDelta is the difference between now and last accrual
        uint256 blockDelta = block.number - lastReport;

        if (blockDelta != 0) {
            /// @dev calculate dripAmount using blockDelta and dripRatePerBlock
            uint256 dripAmount = blockDelta * dripRatePerBlock;

            /// @dev We can only drip what we have
            /// @notice if the dripAmount is greater than the lockedFunds
            /// @notice then we set the dripAmount to the lockedFunds
            uint256 cachedLockedFunds = lockedFunds;
            if (dripAmount > cachedLockedFunds) dripAmount = cachedLockedFunds;

            /// @dev unlock the dripAmount from the lockedFunds
            /// @notice so that it reflects the amount of xETH that is available
            /// @notice and the exchange rate shows that
            unchecked {
              /// @notice since cachedLockedFunds >= dripAmount, the subtraction can be 
              /// done in unchecked block
              cachedLockedFunds -= dripAmount;
            }

            /// @dev set the lastReport to the current block
            lastReport = block.number;

            /// @notice if there are no remaining locked funds
            /// @notice the drip must be stopped.
            if (cachedLockedFunds == 0) {
                dripEnabled = false;
                emit DripStopped();
            }

            lockedFunds = cachedLockedFunds;

            /// @dev emit succesful drip event with dripAmount, lockedFunds and xETH balance
            emit Drip(dripAmount, cachedLockedFunds, xETH.balanceOf(address(this)));
        }
    }

    /// @dev modifier drip calls accrueDrip before executing the function
    modifier drip() {
        _accrueDrip();
        _;
    }
}
