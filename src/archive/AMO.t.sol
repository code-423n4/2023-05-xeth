// // SPDX-License-Identifier: Unlicense
// pragma solidity >=0.8.0;

// import {DSTest} from "ds-test/test.sol";
// import {Utilities} from "./utils/Utilities.sol";
// import {MockErc20} from "./mocks/MockERC20.sol";
// import {console} from "./utils/Console.sol";
// import {Vm} from "forge-std/Vm.sol";

// import {ICurveFactory} from "src/interfaces/ICurveFactory.sol";
// import {ICurvePool} from "src/interfaces/ICurvePool.sol";
// import {xETH as xETH_contract} from "src/xETH.sol";
// import {xETH_AMO} from "./AMO.sol";

// contract ContractTest is DSTest {
//     Vm internal immutable vm = Vm(HEVM_ADDRESS);
//     ICurveFactory internal constant factory =
//         ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);

//     Utilities internal utils;
//     address payable[] internal users;

//     xETH_contract internal xETH;
//     xETH_AMO internal AMO;
//     MockErc20 internal stETH;
//     ICurvePool internal curvePool;

//     function setUp() public {
//         utils = new Utilities();
//         users = utils.createUsers(5);

//         vm.startPrank(users[0]);

//         xETH = new xETH_contract();
//         stETH = new MockErc20("Staked Ether", "StETH", 18);

//         vm.label(address(xETH), "xETH");
//         vm.label(address(stETH), "stETH");

//         address[4] memory coins;
//         coins[0] = address(xETH);
//         coins[1] = address(stETH);

//         address pool = factory.deploy_plain_pool(
//             "XETH-stETH Pool",
//             "XETH/stETH",
//             coins,
//             200, // A
//             4000000, // Fee
//             3, // asset type 1 = ETH, 3 = Other
//             1 // implementation index = balances
//         );
//         vm.label(pool, "curve_pool");

//         curvePool = ICurvePool(pool);

//         AMO = new xETH_AMO(address(xETH), address(stETH), pool, true);
//         vm.label(address(AMO), "curve_amo");
//         xETH.setAMO(address(AMO));

//         stETH.mint(users[0], 100e18);
//         vm.stopPrank();
//     }

//     function testRebalanceDown() public {
//         vm.startPrank(users[0]);
//         stETH.approve(address(AMO), 10e18);
//         AMO.addLiquidity(10e18, 10e18, 20 * 0.999e18);
//         AMO.rebalance();

//         uint256 a = curvePool.balances(0);
//         uint256 b = curvePool.balances(1);

//         console.log("xeth a:", a);
//         console.log("stETH a:", b);
//         console.log(
//             "xeth/steth after add liquidity rebalance:",
//             (a * 1e18) / (a + b)
//         );

//         stETH.approve(address(curvePool), 4e18);
//         uint256 amountRecevied = curvePool.exchange(1, 0, 2e18, 2 * 0.995e18);

//         console.log("amountRecevied", amountRecevied);

//         a = curvePool.balances(0);
//         b = curvePool.balances(1);
//         console.log("xeth b:", a);
//         console.log("stETH b:", b);
//         console.log("xeth/steth after swap:", (a * 1e18) / (a + b));

//         AMO.rebalance();

//         a = curvePool.balances(0);
//         b = curvePool.balances(1);
//         console.log("xeth c:", a);
//         console.log("stETH c:", b);
//         console.log("xeth/steth after 2nd rebalance:", (a * 1e18) / (a + b));

//         vm.stopPrank();
//     }

//     function testRebalanceUp() public {
//         vm.startPrank(users[0]);

//         stETH.approve(address(AMO), 10e18);
//         AMO.addLiquidity(10e18, 40e18, 50 * 0.995e18);

//         uint256 a = curvePool.balances(0);
//         uint256 b = curvePool.balances(1);

//         console.log("xeth a:", a);
//         console.log("stETH a:", b);
//         console.log("xeth/steth after add liquidity:", (a * 1e18) / (a + b));

//         AMO.rebalance();

//         a = curvePool.balances(0);
//         b = curvePool.balances(1);
//         console.log("xeth b:", a);
//         console.log("stETH b:", b);
//         console.log("xeth/steth after rebalance:", (a * 1e18) / (a + b));

//         vm.stopPrank();
//     }

//     function testRebalanceUp_85_pct() public {
//         vm.startPrank(users[0]);

//         stETH.approve(address(AMO), 15e18);
//         AMO.addLiquidity(15e18, 85e18, 50 * 0.995e18);

//         uint256 a = curvePool.balances(0);
//         uint256 b = curvePool.balances(1);

//         console.log("xeth a:", a);
//         console.log("stETH a:", b);
//         console.log("xeth/steth after add liquidity:", (a * 1e18) / (a + b));

//         AMO.rebalance();

//         a = curvePool.balances(0);
//         b = curvePool.balances(1);
//         console.log("xeth b:", a);
//         console.log("stETH b:", b);
//         console.log("xeth/steth after rebalance:", (a * 1e18) / (a + b));

//         vm.stopPrank();
//     }

//     function testRebalanceDown_65_pct() public {
//         vm.startPrank(users[0]);

//         stETH.approve(address(AMO), 35e18);
//         AMO.addLiquidity(35e18, 65e18, 100 * 0.995e18);

//         uint256 a = curvePool.balances(0);
//         uint256 b = curvePool.balances(1);

//         console.log("xeth a:", a);
//         console.log("stETH a:", b);
//         console.log("xeth/steth after add liquidity:", (a * 1e18) / (a + b));

//         AMO.rebalance();

//         a = curvePool.balances(0);
//         b = curvePool.balances(1);
//         console.log("xeth b:", a);
//         console.log("stETH b:", b);
//         console.log("xeth/steth after rebalance:", (a * 1e18) / (a + b));

//         vm.stopPrank();
//     }
// }
