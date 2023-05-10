// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.11;
// import "@openzeppelin-contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin-contracts/access/Ownable.sol";
// import "./interfaces/ICurvePool.sol";
// import {xETH as xETH_CONTRACT} from "./xETH.sol";

// // import {console} from "./test/utils/Console.sol";

// contract xETH_AMO is Ownable {
//     using SafeERC20 for ERC20;

//     error PoolIsEmpty();
//     error LpBalanceTooLow();
//     error ZeroAddressProvided();

//     uint256 public constant BASE_UNIT = 1E18;
//     uint256 public constant REBALANCE_UP_THRESHOLD = 0.78E18;
//     uint256 public constant REBALANCE_DOWN_THRESHOLD = 0.7E18;
//     uint256 public constant TARGET_REBALANCE = 0.74E18;
//     uint256 public constant TARGET_INVERSE = 1E18 - TARGET_REBALANCE;
//     uint256 public constant MAX_SLIPPAGE_BPS = 0.0006E18; /// @dev 7bps or 0.07%

//     uint256 public immutable xETHIndex;
//     uint256 public immutable stETHIndex;

//     xETH_CONTRACT public immutable xETH;
//     ERC20 public immutable stETH;
//     ICurvePool public immutable curvePool;

//     constructor(
//         address xETHAddress,
//         address stETHAddress,
//         address curvePoolAddress,
//         bool isToken0
//     ) {
//         if (
//             xETHAddress == address(0) ||
//             stETHAddress == address(0) ||
//             curvePoolAddress == address(0)
//         ) {
//             revert ZeroAddressProvided();
//         }

//         xETH = xETH_CONTRACT(xETHAddress);
//         stETH = ERC20(stETHAddress);
//         curvePool = ICurvePool(curvePoolAddress);

//         xETHIndex = isToken0 ? 0 : 1;
//         stETHIndex = isToken0 ? 1 : 0;
//     }

//     function preRebalanceCheck(
//         uint256 xETHBalance,
//         uint256 stETHBalance
//     ) internal pure {
//         /// @dev check if denominator is 0
//         if (xETHBalance + stETHBalance == 0) {
//             revert PoolIsEmpty();
//         }
//     }

//     function rebalance() external {
//         uint256 stETHBal = curvePool.balances(stETHIndex);
//         uint256 xETHBal = curvePool.balances(xETHIndex);

//         preRebalanceCheck(stETHBal, xETHBal);

//         uint256 xEthPct = (xETHBal * BASE_UNIT) / (stETHBal + xETHBal);

//         if (xEthPct > REBALANCE_UP_THRESHOLD) {
//             rebalanceUp(xETHBal, stETHBal);
//         } else if (xEthPct < REBALANCE_DOWN_THRESHOLD) {
//             rebalanceDown(xETHBal, stETHBal);
//         }
//     }

//     function calcLpAmount(
//         uint256 underlyingAmount,
//         uint256 vp
//     ) internal pure returns (uint256) {
//         return (underlyingAmount * BASE_UNIT) / vp;
//     }

//     function rebalanceUp(uint256 xETHBalance, uint256 stETHBalance) internal {
//         uint256 dA = xETHBalance -
//             ((TARGET_REBALANCE * stETHBalance) / TARGET_INVERSE);

//         /// @todo account for slippage correctly
//         // uint256 maxLPBurn = (dA * 1.005e18) / BASE_UNIT;
//         uint256 vp = curvePool.get_virtual_price();
//         uint256 maxLPBurn = (calcLpAmount(dA, vp) *
//             (BASE_UNIT + MAX_SLIPPAGE_BPS)) / BASE_UNIT;

//         uint256 amoBalance = ERC20(address(curvePool)).balanceOf(address(this));

//         /// @dev revert if AMO doesn't have enough LP Tokens
//         if (amoBalance == 0) {
//             revert LpBalanceTooLow();
//         }

//         if (maxLPBurn > amoBalance) {
//             maxLPBurn = amoBalance;
//             // dA = (maxLPBurn * 0.995e18) / BASE_UNIT;
//             dA = (maxLPBurn * (BASE_UNIT - MAX_SLIPPAGE_BPS)) / BASE_UNIT;
//         }

//         uint256 amountReceived = curvePool.remove_liquidity_one_coin(
//             maxLPBurn,
//             int128(int(xETHIndex)),
//             dA
//         );
//         xETH.burnShares(amountReceived);
//     }

//     function rebalanceDown(uint256 xETHBalance, uint256 stETHBalance) internal {
//         uint256 dA = ((TARGET_REBALANCE * stETHBalance) / TARGET_INVERSE) -
//             xETHBalance;

//         xETH.mintShares(dA);

//         uint256[2] memory amounts;
//         amounts[xETHIndex] = dA;

//         // @todo account for slippage correctly
//         // uint256 minLpOut = (dA * 0.995e18) / BASE_UNIT;
//         uint256 vp = curvePool.get_virtual_price();
//         uint256 minLpOut = (calcLpAmount(dA, vp) *
//             (BASE_UNIT - MAX_SLIPPAGE_BPS)) / BASE_UNIT;

//         ERC20(address(xETH)).safeApprove(address(curvePool), dA);
//         curvePool.add_liquidity(amounts, minLpOut);
//     }

//     function addLiquidity(
//         uint256 stETHAmount,
//         uint256 xETHAmount,
//         uint256 minLpOut
//     ) external onlyOwner returns (uint256 lpOut) {
//         stETH.safeTransferFrom(msg.sender, address(this), stETHAmount);
//         xETH.mintShares(xETHAmount);

//         uint256[2] memory amounts;

//         amounts[xETHIndex] = xETHAmount;
//         amounts[stETHIndex] = stETHAmount;

//         ERC20(address(xETH)).safeApprove(address(curvePool), xETHAmount);
//         stETH.safeApprove(address(curvePool), stETHAmount);

//         lpOut = curvePool.add_liquidity(amounts, minLpOut);
//     }

//     function removeLiquidity(
//         uint256 lpAmount,
//         uint256 minStETHOut,
//         uint256 minXETHOut
//     ) external onlyOwner returns (uint256[2] memory outputs) {
//         /// @dev check if AMO owns enough LP
//         uint256 amoBalance = ERC20(address(curvePool)).balanceOf(address(this));

//         if (lpAmount > amoBalance) {
//             revert LpBalanceTooLow();
//         }

//         uint256[2] memory minAmounts;

//         minAmounts[xETHIndex] = minXETHOut;
//         minAmounts[stETHIndex] = minStETHOut;

//         outputs = curvePool.remove_liquidity(lpAmount, minAmounts);

//         xETH.burnShares(outputs[xETHIndex]);
//         stETH.safeTransfer(msg.sender, outputs[stETHIndex]);
//     }

//     function removeLiquidityOnlyStETH(
//         uint256 lpAmount,
//         uint256 minStETHOut
//     ) external onlyOwner returns (uint256 stETHOut) {
//         /// @dev check if AMO owns enough LP
//         uint256 amoBalance = ERC20(address(curvePool)).balanceOf(address(this));

//         if (lpAmount > amoBalance) {
//             revert LpBalanceTooLow();
//         }

//         stETHOut = curvePool.remove_liquidity_one_coin(
//             lpAmount,
//             int128(int(stETHIndex)),
//             minStETHOut
//         );

//         stETH.safeTransfer(msg.sender, stETHOut);
//     }
// }
