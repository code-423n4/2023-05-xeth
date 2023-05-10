// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {MockErc20} from "./mocks/MockERC20.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {ICurveFactory} from "../interfaces/ICurveFactory.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {xETH as xETH_contract} from "../xETH.sol";
import {xETH_AMO} from "../AMO2.sol";

contract xETHTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;

    xETH_contract internal xETH;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        vm.startPrank(users[0]);
        xETH = new xETH_contract();
        vm.stopPrank();

        vm.label(address(xETH), "xETH");
    }

    function testControl() public {
        assertTrue(xETH.hasRole(xETH.DEFAULT_ADMIN_ROLE(), users[0]));
        assertTrue(xETH.hasRole(xETH.PAUSER_ROLE(), users[0]));
    }

    function testControl_fakeUser() public {
        assertTrue(!xETH.hasRole(xETH.DEFAULT_ADMIN_ROLE(), users[1]));
        assertTrue(!xETH.hasRole(xETH.PAUSER_ROLE(), users[1]));
    }

    function testFail_setAMO_zeroAddress() public {
        vm.startPrank(users[0]);
        xETH.setAMO(address(0));
        vm.stopPrank();
    }

    function testSetAMO() public {
        vm.startPrank(users[0]);

        xETH.setAMO(users[1]);

        vm.stopPrank();
    }

    function testFail_mintShares_notMinter() public {
        xETH.mintShares(1000);
    }

    function testFail_burnShares_notMinter() public {
        xETH.burnShares(1000);
    }

    function testMintAndBurnShares() public {
        address amo = users[2];
        vm.startPrank(users[0]);
        xETH.setAMO(amo);
        vm.stopPrank();

        vm.startPrank(amo);
        uint256 amount = 1000;
        xETH.mintShares(amount);
        assertEq(xETH.balanceOf(amo), amount);

        xETH.burnShares(amount);
        assertEq(xETH.balanceOf(amo), 0);
        vm.stopPrank();
    }

    function testFail_mintShares_zeroAmount() public {
        address amo = users[2];
        vm.startPrank(users[0]);
        xETH.setAMO(amo);
        vm.stopPrank();

        vm.startPrank(users[2]);
        xETH.mintShares(0);
        vm.stopPrank();
    }

    function testFail_burnShares_zeroAmount() public {
        address amo = users[2];
        vm.startPrank(users[0]);
        xETH.setAMO(amo);
        vm.stopPrank();

        vm.startPrank(users[2]);
        xETH.burnShares(0);
        vm.stopPrank();
    }
}
