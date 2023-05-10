// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICurvePool {
    // function get_balances() external view returns (uint256[] memory);

    function balances(uint256 i) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 burn_amount,
        int128 coin_idx,
        uint256 min_received
    ) external returns (uint256);

    function remove_liquidity(
        uint256 burn_amount,
        uint256[2] memory amounts
    ) external returns (uint256[2] memory);

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount
    ) external returns (uint256);

    function calc_token_amount(
        uint256[2] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);

    function get_virtual_price() external view returns (uint256);
}
