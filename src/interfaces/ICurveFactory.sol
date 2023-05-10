// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICurveFactory {
    function deploy_pool(
        string memory name,
        string memory symbol,
        address[] memory coins,
        uint256 A,
        uint256 mid_fee,
        uint256 out_fee,
        uint256 allowed_extra_profit,
        uint256 fee_gamma,
        uint256 adjustment_step,
        uint256 admin_fee,
        uint256 ma_half_time,
        uint256 initial_price
    ) external returns (address);

    function deploy_plain_pool(
        string memory name,
        string memory symbol,
        address[4] memory coins,
        uint256 A,
        uint256 fee,
        uint256 asset_type,
        uint256 impl_idx
    ) external returns (address);
}
