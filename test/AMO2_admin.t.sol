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

contract AMOAdminTest is DSTest {
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

    function testSetRebalanceDefender() public {
        vm.expectRevert(xETH_AMO.ZeroAddressProvided.selector);
        vm.prank(owner);
        AMO.setRebalanceDefender(address(0));

        address newDefender = address(0x42111);

        vm.prank(owner);
        AMO.setRebalanceDefender(newDefender);

        assertEq(AMO.defender(), newDefender);
        assertTrue(AMO.hasRole(AMO.REBALANCE_DEFENDER_ROLE(), newDefender));
    }

    function testSetRebalanceDefender_wrongOwner() public {
        address newDefender = address(0x42111);

        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        AMO.setRebalanceDefender(newDefender);
    }

    function testSetSlippage() public {
        assertEq(AMO.upSlippage(), 0);
        assertEq(AMO.downSlippage(), 100 * 1E14);

        vm.prank(owner);
        AMO.setSlippage(20 * 1E14, 180 * 1E14);

        assertEq(AMO.upSlippage(), 20 * 1E14);
        assertEq(AMO.downSlippage(), 180 * 1E14);

        vm.prank(owner);
        AMO.setSlippage(0, 0);

        assertEq(AMO.upSlippage(), 0);
        assertEq(AMO.downSlippage(), 0);
    }

    function testSetSlippage_wrongOwner() public {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        AMO.setSlippage(0, 0);
    }

    function testSetRebalanceUpCap() public {
        vm.expectRevert(xETH_AMO.ZeroValueProvided.selector);
        vm.prank(owner);
        AMO.setRebalanceUpCap(0);

        uint256 newRebalanceUpCap = 10 ether;

        vm.prank(owner);
        AMO.setRebalanceUpCap(newRebalanceUpCap);

        assertEq(AMO.rebalanceUpCap(), newRebalanceUpCap);
    }

    function testSetRebalanceUpCap_wrongOwner() public {
        uint256 newRebalanceUpCap = 10 ether;

        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        AMO.setRebalanceUpCap(newRebalanceUpCap);
    }

    function testSetRebalanceDownCap() public {
        vm.expectRevert(xETH_AMO.ZeroValueProvided.selector);
        vm.prank(owner);
        AMO.setRebalanceDownCap(0);

        uint256 newRebalanceDownCap = 10 ether;

        vm.prank(owner);
        AMO.setRebalanceDownCap(newRebalanceDownCap);

        assertEq(AMO.rebalanceDownCap(), newRebalanceDownCap);
    }

    function testSetRebalanceDownCap_wrongOwner() public {
        uint256 newRebalanceDownCap = 10 ether;

        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        AMO.setRebalanceDownCap(newRebalanceDownCap);
    }

    function testSetCooldownBlocks() public {
        uint256 newCooldownBlocks = 200;

        vm.expectRevert(xETH_AMO.ZeroValueProvided.selector);
        vm.prank(owner);
        AMO.setCooldownBlocks(0);

        vm.prank(owner);
        AMO.setCooldownBlocks(newCooldownBlocks);
        assertEq(AMO.cooldownBlocks(), newCooldownBlocks);
    }

    function testSetCooldownBlocks_wrongOwner() public {
        uint256 newCooldownBlocks = 200;

        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        AMO.setCooldownBlocks(newCooldownBlocks);
    }
}
