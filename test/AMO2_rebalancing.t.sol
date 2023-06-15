// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {MockErc20} from "./mocks/MockERC20.sol";
import {console} from "./utils/Console.sol";
import {MockCVXStaker} from "./mocks/MockCVXStaker.sol";
import {Vm} from "forge-std/Vm.sol";

import {ICurveFactory} from "src/interfaces/ICurveFactory.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {xETH as xETH_contract} from "src/xETH.sol";
import {xETH_AMO} from "src/AMO2.sol";

contract AMORebalancingTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    ICurveFactory internal constant factory =
        ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);

    Utilities internal utils;
    address payable[] internal users;

    address internal owner;
    address internal bot;

    xETH_contract internal xETH;
    xETH_AMO internal AMO;
    MockErc20 internal stETH;
    ICurvePool internal curvePool;
    MockCVXStaker internal cvxStaker;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        address payable[] memory moreUsers = utils.createUsers(2);

        owner = moreUsers[0];
        vm.label(owner, "owner");

        bot = moreUsers[1];
        vm.label(bot, "bot");

        vm.startPrank(owner);

        xETH = new xETH_contract();
        stETH = new MockErc20("Staked Ether", "StETH", 18);

        vm.label(address(xETH), "xETH");
        vm.label(address(stETH), "stETH");

        address[4] memory coins;
        coins[0] = address(xETH);
        coins[1] = address(stETH);

        address pool = factory.deploy_plain_pool(
            "XETH-stETH Pool",
            "XETH/stETH",
            coins,
            200, // A
            4000000, // Fee
            3, // asset type 1 = ETH, 3 = Other
            1 // implementation index = balances
        );
        vm.label(pool, "curve_pool");

        curvePool = ICurvePool(pool);
        cvxStaker = new MockCVXStaker(pool);

        AMO = new xETH_AMO(
            address(xETH),
            address(stETH),
            pool,
            address(cvxStaker),
            0
        );
        AMO.setRebalanceDefender(address(bot));

        cvxStaker.setOperator(address(AMO));

        vm.label(address(AMO), "amo");
        xETH.setAMO(address(AMO));

        stETH.mint(owner, 100e18);
        vm.stopPrank();
    }

    function testRebalanceDown() public {
        vm.startPrank(owner);

        AMO.setRebalanceDownCap(40e18);

        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 10e18, 20 * 0.999e18);

        vm.stopPrank();

        vm.startPrank(bot);

        uint256 xETHBal = curvePool.balances(0);
        uint256 stETHBal = curvePool.balances(1);

        console.log("xETHBal", xETHBal);
        console.log("stETHBal", stETHBal);

        uint256 xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        console.log("xEthPct", xEthPct);

        assertTrue(xEthPct < AMO.REBALANCE_DOWN_THRESHOLD());

        uint256 dA = ((0.74E18 * stETHBal) / 0.26E18) - xETHBal;

        console.log("addition of xETH", dA);

        uint256 vp = curvePool.get_virtual_price();
        uint bps = 20E14; // 20bps
        uint256 minLpOut = (((dA * 1E18) / vp) * (1E18 - bps)) / 1E18;

        console.log("minLpOut", minLpOut);

        xETH_AMO.RebalanceDownQuote memory quote = xETH_AMO.RebalanceDownQuote(
            dA,
            minLpOut
        );

        uint256 lpAmountOut = AMO.rebalanceDown(quote);

        console.log("rebalance, lpAmountOut", lpAmountOut);
        console.log(
            "rebalance, lpAmountOut diff",
            (lpAmountOut * 1e18) / minLpOut
        );

        xETHBal = curvePool.balances(0);
        stETHBal = curvePool.balances(1);
        xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        console.log("xETHBal", xETHBal);
        console.log("stETHBal", stETHBal);
        console.log("xEthPct", xEthPct);

        vm.stopPrank();
    }

    function testRebalanceUp() public {
        vm.startPrank(owner);

        AMO.setRebalanceUpCap(40e18);

        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 40e18, 50 * 0.998e18);

        vm.stopPrank();

        vm.startPrank(bot);

        uint256 xETHBal = curvePool.balances(0);
        uint256 stETHBal = curvePool.balances(1);

        console.log("xETHBal", xETHBal);
        console.log("stETHBal", stETHBal);

        uint256 xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        console.log("xEthPct", xEthPct);

        assertTrue(xEthPct > AMO.REBALANCE_UP_THRESHOLD());

        uint256 minXethRemoved = xETHBal - ((0.74E18 * stETHBal) / 0.26E18);

        console.log("removal of min xETH", minXethRemoved);

        uint256 vp = curvePool.get_virtual_price();
        uint bps = 27E14; // 27bps
        uint256 lpBurn = (((minXethRemoved * 1E18) / vp) * (1E18 + bps)) / 1E18;

        console.log("lp Burn", lpBurn);

        xETH_AMO.RebalanceUpQuote memory quote = xETH_AMO.RebalanceUpQuote(
            lpBurn,
            minXethRemoved
        );

        uint256 xEthRemoved = AMO.rebalanceUp(quote);

        console.log("rebalance, xEthRemoved", xEthRemoved);
        console.log(
            "rebalance, xEth diff",
            (xEthRemoved * 1e18) / minXethRemoved
        );

        xETHBal = curvePool.balances(0);
        stETHBal = curvePool.balances(1);
        xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        console.log("xETHBal", xETHBal);
        console.log("stETHBal", stETHBal);
        console.log("xEthPct", xEthPct);

        vm.stopPrank();
    }
}
