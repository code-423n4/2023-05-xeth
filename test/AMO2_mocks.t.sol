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

contract MockAMO is xETH_AMO {
    constructor(
        address xETHAddress,
        address stETHAddress,
        address curvePoolAddress,
        address cvxStakerAddress,
        bool isXETHToken0
    )
        xETH_AMO(
            xETHAddress,
            stETHAddress,
            curvePoolAddress,
            cvxStakerAddress,
            isXETHToken0
        )
    {}

    function _testCooldown() public afterCooldownPeriod returns (bool) {}

    function _preRebalanceCheck() public view returns (bool isRebalanceUp) {
        isRebalanceUp = preRebalanceCheck();
    }

    function _bestRebalanceUpQuote(
        RebalanceUpQuote calldata defenderQuote
    ) public view returns (uint256) {
        return bestRebalanceUpQuote(defenderQuote);
    }

    function _bestRebalanceDownQuote(
        RebalanceDownQuote calldata defenderQuote
    ) public view returns (uint256) {
        return bestRebalanceDownQuote(defenderQuote);
    }

    function _applySlippage(uint256 amount, bool up) public view returns(uint256) {
      return applySlippage(amount, up ? upSlippage : downSlippage);
    }
}

contract AMORebalancingTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    ICurveFactory internal constant factory =
        ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);

    Utilities internal utils;
    address payable[] internal users;

    address internal owner;
    address internal bot;

    xETH_contract internal xETH;
    MockAMO internal AMO;
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

        AMO = new MockAMO(
            address(xETH),
            address(stETH),
            pool,
            address(cvxStaker),
            true
        );
        AMO.setRebalanceDefender(address(bot));

        cvxStaker.setOperator(address(AMO));

        vm.label(address(AMO), "amo");
        xETH.setAMO(address(AMO));

        stETH.mint(owner, 100e18);
        vm.stopPrank();
    }

    function testApplySlippage() public {
      uint256 amt = 1E18 * 3.1415926536;

      uint256 value = AMO._applySlippage(amt, true);
      assertEq(value, amt);

      value = AMO._applySlippage(amt, false);
      assertEq(value, (amt * (1E18 - AMO.downSlippage())) / 1E18);
    }

    function testCoolDown() public {
        uint256 cp = 1000;

        vm.prank(owner);
        AMO.setCooldownBlocks(cp);

        assertEq(AMO.cooldownBlocks(), cp);
        console.log("current block", block.number);

        AMO._testCooldown();

        assertEq(AMO.lastRebalanceBlock(), block.number);

        vm.expectRevert(xETH_AMO.CooldownNotFinished.selector);
        AMO._testCooldown();

        vm.roll(block.number + cp + 1);
        console.log("current block", block.number);
        AMO._testCooldown();
    }

    function testPreRebalanceCheck_rebalanceUp() public {
        vm.startPrank(owner);

        AMO.setRebalanceUpCap(40e18);

        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 40e18, 50 * 0.998e18);

        vm.stopPrank();

        bool isRebalanceUp = AMO._preRebalanceCheck();

        assertTrue(isRebalanceUp);
    }

    function testPreRebalanceCheck_rebalanceDown() public {
        vm.startPrank(owner);

        AMO.setRebalanceDownCap(40e18);

        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 10e18, 20 * 0.999e18);

        vm.stopPrank();

        bool isRebalanceUp = AMO._preRebalanceCheck();

        assertTrue(!isRebalanceUp);
    }

    function testPreRebalanceCheck_noRebalance() public {
        vm.startPrank(owner);

        AMO.setRebalanceUpCap(40e18);

        stETH.approve(address(AMO), 15e18);
        AMO.addLiquidity(15e18, 35e18, 50 * 0.998e18);

        vm.stopPrank();

        vm.expectRevert(xETH_AMO.RebalanceNotRequired.selector);
        AMO._preRebalanceCheck();
    }

    function testBestRebalanceUpQuote() public {
        vm.startPrank(owner);
        AMO.setSlippage(100 * 1E14, 100 * 1E14);
        AMO.setRebalanceUpCap(40e18);
        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 40e18, 50 * 0.998e18);
        vm.stopPrank();

        uint256 xETHBal = curvePool.balances(0);
        uint256 stETHBal = curvePool.balances(1);
        uint256 xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        assertTrue(xEthPct > AMO.REBALANCE_UP_THRESHOLD());

        uint256 xETHRemoved = xETHBal - ((0.74E18 * stETHBal) / 0.26E18);

        uint256 vp = curvePool.get_virtual_price();
        uint bps = 27E14; // 27bps
        uint256 lpBurn = (xETHRemoved * 1E18) / vp;
        uint256 minXethRemoved = (xETHRemoved * (1E18 - bps)) / 1E18;

        xETH_AMO.RebalanceUpQuote memory defenderQuote = xETH_AMO
            .RebalanceUpQuote(lpBurn, minXethRemoved);

        uint256 min_xETHReceived = AMO._bestRebalanceUpQuote(
            defenderQuote
        );

        // assertEq(bestQuote.lpBurn, defenderQuote.lpBurn);
        assertEq(min_xETHReceived, defenderQuote.min_xETHReceived);

        bps = 120E14; // 120bps
        minXethRemoved = (xETHRemoved * (1E18 - bps)) / 1E18;

        defenderQuote = xETH_AMO.RebalanceUpQuote(lpBurn, minXethRemoved);

        min_xETHReceived = AMO._bestRebalanceUpQuote(defenderQuote);

        // assertEq(bestQuote.lpBurn, defenderQuote.lpBurn);
        assertTrue(min_xETHReceived > defenderQuote.min_xETHReceived);
    }

    function testBestRebalanceDownQuote() public {
        vm.startPrank(owner);

        AMO.setRebalanceDownCap(40e18);

        stETH.approve(address(AMO), 10e18);
        AMO.addLiquidity(10e18, 10e18, 20 * 0.999e18);

        vm.stopPrank();

        uint256 xETHBal = curvePool.balances(0);
        uint256 stETHBal = curvePool.balances(1);
        uint256 xEthPct = (xETHBal * 1E18) / (stETHBal + xETHBal);

        assertTrue(xEthPct < AMO.REBALANCE_DOWN_THRESHOLD());

        uint256 dA = ((0.74E18 * stETHBal) / 0.26E18) - xETHBal;

        uint256 vp = curvePool.get_virtual_price();
        uint bps = 20E14; // 20bps
        uint256 minLpOut = (((dA * 1E18) / vp) * (1E18 - bps)) / 1E18;

        xETH_AMO.RebalanceDownQuote memory defenderQuote = xETH_AMO
            .RebalanceDownQuote(dA, minLpOut);

        uint256 minLpReceived = AMO
            ._bestRebalanceDownQuote(defenderQuote);

        // assertEq(bestQuote.xETHAmount, defenderQuote.xETHAmount);
        assertEq(minLpReceived, defenderQuote.minLpReceived);

        bps = 120E14; // 120bps
        minLpOut = (((dA * 1E18) / vp) * (1E18 - bps)) / 1E18;

        defenderQuote = xETH_AMO.RebalanceDownQuote(dA, minLpOut);

        minLpReceived = AMO._bestRebalanceDownQuote(defenderQuote);

        // assertEq(bestQuote.xETHAmount, defenderQuote.xETHAmount);
        assertTrue(minLpReceived > defenderQuote.minLpReceived);
    }
}
