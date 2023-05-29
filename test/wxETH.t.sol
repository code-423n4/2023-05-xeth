// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {MockErc20} from "./mocks/MockERC20.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {ICurveFactory} from "src/interfaces/ICurveFactory.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {xETH as xETH_contract} from "src/xETH.sol";
import {WrappedXETH} from "src/wxETH.sol";

contract AMOAdminTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    address public owner;
    address public testUser;

    xETH_contract internal xETH;
    WrappedXETH internal wxETH;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        owner = users[0];
        testUser = users[1];

        vm.startPrank(owner);
        xETH = new xETH_contract();
        xETH.setAMO(owner);
        xETH.mintShares(1000 ether);

        wxETH = new WrappedXETH(address(xETH));
        vm.stopPrank();

        vm.label(address(xETH), "xETH");
        vm.label(address(wxETH), "wxETH");
        vm.label(owner, "owner");
        vm.label(testUser, "test_user");
    }

    function testCheckInitialData() public {
        assertEq(wxETH.exchangeRate(), 1e18);
        assertEq(address(wxETH.xETH()), address(xETH));
        assertEq(wxETH.lockedFunds(), 0);
        assertEq(wxETH.dripRatePerBlock(), 0);
        assertEq(wxETH.lastReport(), block.number);
        assertTrue(!wxETH.dripEnabled());
    }

    function testStake() public {
        uint256 amt = 10 ether;
        vm.prank(owner);
        xETH.transfer(testUser, amt);

        vm.startPrank(testUser);
        xETH.approve(address(wxETH), amt);
        wxETH.stake(amt);
        vm.stopPrank();

        assertEq(wxETH.totalSupply(), amt);
        assertEq(xETH.balanceOf(testUser), 0);
        assertEq(wxETH.balanceOf(testUser), amt);
        assertEq(wxETH.exchangeRate(), 1E18);
    }

    function testUnstake() public {
        uint256 amt = 5 ether;
        vm.prank(owner);
        xETH.transfer(testUser, amt);

        vm.startPrank(testUser);

        xETH.approve(address(wxETH), amt);
        wxETH.stake(amt);

        assertEq(wxETH.balanceOf(testUser), amt);

        wxETH.unstake(amt);

        assertEq(wxETH.balanceOf(testUser), 0);
        assertEq(wxETH.totalSupply(), 0);
        assertEq(xETH.balanceOf(testUser), amt);
        vm.stopPrank();
    }

    function testAddLockedFunds() public {
        uint256 amt = 20 ether;

        vm.startPrank(owner);

        xETH.approve(address(wxETH), amt);
        wxETH.addLockedFunds(amt);

        vm.stopPrank();

        assertEq(wxETH.lockedFunds(), amt);
        assertEq(wxETH.exchangeRate(), 1E18);

        /// add more tests here
    }

    function testSetDripRate() public {
        uint256 amt = 20 ether;
        uint256 blockTime = 15;
        uint256 duration = 604800;
        uint256 possibleDripRate = amt / (duration / blockTime);

        vm.prank(owner);
        wxETH.setDripRate(possibleDripRate);

        assertEq(wxETH.dripRatePerBlock(), possibleDripRate);
        /// @todo
    }

    function testDrip() public {
        uint256 dripAmt = 20 ether;
        uint256 stakeAmt = 80 ether;

        uint256 blockTime = 15;
        uint256 duration = 604800;
        uint256 possibleDripRate = dripAmt / (duration / blockTime);

        vm.startPrank(owner);
        wxETH.setDripRate(possibleDripRate);

        xETH.approve(address(wxETH), dripAmt);
        wxETH.addLockedFunds(dripAmt);

        wxETH.startDrip();
        assertTrue(wxETH.dripEnabled());

        xETH.transfer(testUser, stakeAmt);
        vm.stopPrank();

        vm.startPrank(testUser);
        xETH.approve(address(wxETH), stakeAmt);
        wxETH.stake(stakeAmt);

        assertEq(wxETH.balanceOf(testUser), stakeAmt);

        /// move 1000 blocks
        uint moveWindow = 1000;
        vm.roll(block.number + moveWindow);
        uint256 currentBalanceShouldBe = stakeAmt +
            (possibleDripRate * moveWindow);

        wxETH.accrueDrip();

        assertEq(
            wxETH.previewUnstake(wxETH.balanceOf(testUser)),
            currentBalanceShouldBe
        );

        vm.roll(block.number + moveWindow);
        currentBalanceShouldBe = stakeAmt + (possibleDripRate * moveWindow * 2);

        wxETH.accrueDrip();
        assertEq(
            wxETH.previewUnstake(wxETH.balanceOf(testUser)),
            currentBalanceShouldBe
        );

        vm.stopPrank();
    }

    function testDripForMultipleUsers() public {
        uint256 dripAmt = 20 ether;
        uint256 stakeAmt = 80 ether;
        uint256 blockTime = 15;
        uint256 duration = 604800;
        uint256 possibleDripRate = dripAmt / (duration / blockTime);

        vm.startPrank(owner);
        wxETH.setDripRate(possibleDripRate);
        xETH.approve(address(wxETH), dripAmt);
        wxETH.addLockedFunds(dripAmt);
        wxETH.startDrip();
        assertTrue(wxETH.dripEnabled());
        vm.stopPrank();

        uint startBlock = block.number;
        for (uint i = 1; i < users.length; i++) {
            address user = users[i];
            vm.prank(owner);
            xETH.transfer(user, stakeAmt);

            vm.startPrank(user);
            xETH.approve(address(wxETH), stakeAmt);
            wxETH.stake(stakeAmt);
            vm.stopPrank();
            assertEq(wxETH.balanceOf(user), wxETH.previewStake(stakeAmt));

            console.log("block number", block.number);
            vm.roll(block.number + 2000);

            wxETH.accrueDrip();

            uint256 fundsDistributed = possibleDripRate *
                (block.number - startBlock);

            assertEq(dripAmt - wxETH.lockedFunds(), fundsDistributed);
        }
    }

    function testStopDrip() public {
        uint256 dripAmt = 20 ether;
        uint256 stakeAmt = 80 ether;

        uint256 blockTime = 15;
        uint256 duration = 604800;
        uint256 possibleDripRate = dripAmt / (duration / blockTime);

        vm.startPrank(owner);
        wxETH.setDripRate(possibleDripRate);

        xETH.approve(address(wxETH), dripAmt);
        wxETH.addLockedFunds(dripAmt);

        wxETH.startDrip();
        assertTrue(wxETH.dripEnabled());

        xETH.transfer(testUser, stakeAmt);
        vm.stopPrank();

        vm.startPrank(testUser);
        xETH.approve(address(wxETH), stakeAmt);
        wxETH.stake(stakeAmt);
        vm.stopPrank();

        assertEq(wxETH.balanceOf(testUser), stakeAmt);

        /// move 1000 blocks
        uint moveWindow = 1000;
        vm.roll(block.number + moveWindow);
        uint256 currentBalanceShouldBe = stakeAmt +
            (possibleDripRate * moveWindow);

        wxETH.accrueDrip();

        assertEq(
            wxETH.previewUnstake(wxETH.balanceOf(testUser)),
            currentBalanceShouldBe
        );

        vm.roll(block.number + moveWindow);
        vm.prank(owner);
        /// @notice stopDrip, first finishes any previous drips possible
        /// @notice and then stops it
        wxETH.stopDrip();

        currentBalanceShouldBe = stakeAmt + (possibleDripRate * moveWindow * 2);

        assertEq(
            wxETH.previewUnstake(wxETH.balanceOf(testUser)),
            currentBalanceShouldBe
        );

        vm.roll(block.number + moveWindow);
        /// @notice no drip should happen
        wxETH.accrueDrip();

        /// @notice the previous amounts should match current amounts
        assertEq(
            wxETH.previewUnstake(wxETH.balanceOf(testUser)),
            currentBalanceShouldBe
        );

        // vm.stopPrank();
    }
}
