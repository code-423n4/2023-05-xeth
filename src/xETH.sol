// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/security/Pausable.sol";
import "@openzeppelin-contracts/access/AccessControl.sol";

contract xETH is ERC20, Pausable, AccessControl {
    /* --------------------------------- Errors --------------------------------- */
    error AddressZeroProvided();
    error AmountZeroProvided();

    /* -------------------------- Constants and Storage ------------------------- */
    /// @dev authentication role for pausing and unpausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev authentication role for minting and burning tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev address of the AMO contract that controls the supply of xETH
    address public curveAMO;

    /* ------------------------------- Constructor ------------------------------ */
    constructor() ERC20("xEther", "xETH") {
        /// @dev grant the DEFAULT_ADMIN_ROLE to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        /// @dev grant the PAUSER_ROLE to the contract deployer
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /* --------------------------- External functions --------------------------- */

    /// @dev setAMO allows for initialising the AMO address and granting it the MINTER_ROLE
    /// @notice this function can also be used to update the AMO address
    /// @notice this function can only be called by the DEFAULT_ADMIN_ROLE
    /// @param newAMO address of the new curveAMO contract
    function setAMO(address newAMO) external onlyRole(DEFAULT_ADMIN_ROLE) {
        /// @dev if the new AMO is address(0), revert
        if (newAMO == address(0)) {
            revert AddressZeroProvided();
        }

        address _curveAMO = curveAMO;

        /// @dev if there was a previous AMO, revoke it's powers
        if (_curveAMO != address(0)) {
            _revokeRole(MINTER_ROLE, _curveAMO);
        }

        // @todo call marker method to check if amo is responding

        /// @dev set the new AMO
        curveAMO = newAMO;

        /// @dev grant the MINTER_ROLE to newAMO
        _grantRole(MINTER_ROLE, newAMO);
    }

    /// @dev mintShares allows for minting new xETH tokens
    /// @notice this function can only mint tokens if the contract is not paused
    /// @notice this function can only be called by the MINTER_ROLE
    /// @param amount amount of xETH to be minted, it cannot be 0
    function mintShares(
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        /// @dev if the amount to be minted is 0, revert.
        if (amount == 0) revert AmountZeroProvided();
        _mint(msg.sender, amount);
    }

    /// @dev burnShares allows for burning xETH tokens
    /// @dev this function can only burn tokens if the contract is not paused
    /// @dev this function can only be called by the MINTER_ROLE
    /// @param amount amount of xETH to be burned, it cannot be 0
    function burnShares(
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        /// @dev if the amount to be burned is 0, revert.
        if (amount == 0) revert AmountZeroProvided();
        _burn(msg.sender, amount);
    }

    /* ---------------------------- Utility functions --------------------------- */

    /// @dev pause allows for pausing the contract
    /// @notice this function can only be called by the PAUSER_ROLE
    /// @notice this function can only be called if the contract is not paused
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @dev unpause allows for unpausing the contract
    /// @notice this function can only be called by the PAUSER_ROLE
    /// @notice this function can only be called if the contract is paused
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /* ---------------------------- Overridden functions --------------------------- */

    /// @dev overrides the default ERC20 _beforeTokenTransfer hook
    /// @dev so that transfers can only happen if the contract is not paused
    /// @param from address of the sender
    /// @param to address of the recipient
    /// @param amount amount of tokens to be transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
