// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IXETH is IERC20 {
    function burnShares(uint256 amount) external;

    function mintShares(uint256 amount) external;
}
