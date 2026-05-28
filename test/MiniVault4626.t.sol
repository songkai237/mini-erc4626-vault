// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MiniVault4626} from "../src/MiniVault4626.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MiniVault4626Test is Test {
    uint8 internal constant ASSET_DECIMALS = 6;
    uint8 internal constant DECIMAL_OFFSET = 3;

    MockERC20 internal asset;
    MiniVault4626 internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_BALANCE = 1_000_000e6;

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", ASSET_DECIMALS);
        vault = new MiniVault4626("Mini Vault", "mvUSD", address(asset), DECIMAL_OFFSET);

        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
    }

    function test_metadata() public view {
        assertEq(vault.asset(), address(asset));
        assertEq(vault.name(), "Mini Vault");
        assertEq(vault.symbol(), "mvUSD");
        assertEq(vault.decimals(), ASSET_DECIMALS + DECIMAL_OFFSET);
    }

    function test_deposit_mintsSharesAndTransfersAssets() public {
        uint256 assets = 100e6;

        vm.startPrank(alice);
        asset.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, alice);
        vm.stopPrank();

        assertEq(shares, vault.previewDeposit(assets));
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE - assets);
    }

    function test_firstDeposit_usesVirtualOffset() public {
        uint256 assets = 1e6;

        vm.prank(alice);
        asset.approve(address(vault), assets);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);

        assertGt(shares, 0);
        assertEq(vault.totalSupply(), shares);
        assertEq(vault.convertToAssets(shares), assets);
    }

    function test_mint_depositsRequiredAssets() public {
        uint256 shares = 1000e9;

        vm.startPrank(alice);
        uint256 assets = vault.previewMint(shares);
        asset.approve(address(vault), assets);
        uint256 assetsUsed = vault.mint(shares, alice);
        vm.stopPrank();

        assertEq(assetsUsed, assets);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), assets);
    }

    function test_redeem_returnsAssets() public {
        uint256 assets = 250e6;
        _deposit(alice, assets);

        uint256 shares = vault.balanceOf(alice);
        uint256 expectedAssets = vault.previewRedeem(shares);

        vm.prank(alice);
        uint256 assetsOut = vault.redeem(shares, alice, alice);

        assertEq(assetsOut, expectedAssets);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE - assets + assetsOut);
        assertEq(vault.totalAssets(), assets - assetsOut);
    }

    function test_withdraw_burnsShares() public {
        uint256 assets = 500e6;
        _deposit(alice, assets);

        uint256 withdrawAssets = 100e6;
        uint256 expectedShares = vault.previewWithdraw(withdrawAssets);

        vm.prank(alice);
        uint256 sharesBurned = vault.withdraw(withdrawAssets, alice, alice);

        assertEq(sharesBurned, expectedShares);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE - assets + withdrawAssets);
        assertEq(vault.totalAssets(), assets - withdrawAssets);
    }

    function test_withdraw_withShareAllowance() public {
        uint256 assets = 200e6;
        _deposit(alice, assets);

        uint256 withdrawAssets = 50e6;
        uint256 shares = vault.previewWithdraw(withdrawAssets);

        vm.prank(alice);
        vault.approve(bob, shares);

        vm.prank(bob);
        vault.withdraw(withdrawAssets, bob, alice);

        assertEq(vault.balanceOf(alice), vault.previewWithdraw(assets - withdrawAssets));
        assertEq(asset.balanceOf(bob), INITIAL_BALANCE + withdrawAssets);
    }

    function test_previewDeposit_matchesDeposit() public {
        uint256 assets = 123_456789;

        vm.startPrank(alice);
        asset.approve(address(vault), assets);
        uint256 previewShares = vault.previewDeposit(assets);
        uint256 actualShares = vault.deposit(assets, alice);
        vm.stopPrank();

        assertEq(actualShares, previewShares);
    }

    function test_previewRedeem_matchesRedeem() public {
        _deposit(alice, 300e6);
        uint256 shares = vault.balanceOf(alice);

        uint256 previewAssets = vault.previewRedeem(shares);

        vm.prank(alice);
        uint256 actualAssets = vault.redeem(shares, alice, alice);

        assertEq(actualAssets, previewAssets);
    }

    function test_maxWithdraw_equalsPreviewRedeemOfBalance() public {
        _deposit(alice, 400e6);
        assertEq(vault.maxWithdraw(alice), vault.previewRedeem(vault.balanceOf(alice)));
    }

    function test_maxRedeem_equalsBalance() public {
        _deposit(alice, 10e6);
        assertEq(vault.maxRedeem(alice), vault.balanceOf(alice));
    }

    function test_convertRoundtrip_floorsDown() public {
        _deposit(alice, 1_000_000e6);

        uint256 assets = 777_777e6;
        uint256 shares = vault.convertToShares(assets);
        uint256 roundtrip = vault.convertToAssets(shares);

        assertLe(roundtrip, assets);
        assertGe(assets - roundtrip, 0);
        assertLe(assets - roundtrip, 1);
    }

    function test_deposit_revertsWhenExceedsMax() public view {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }

    function test_redeem_revertsWhenExceedsBalance() public {
        _deposit(alice, 100e6);

        uint256 balance = vault.balanceOf(alice);
        uint256 tooManyShares = balance + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MiniVault4626.ERC4626ExceededMaxRedeem.selector, alice, tooManyShares, balance)
        );
        vault.redeem(tooManyShares, alice, alice);
    }

    function test_totalAssets_tracksDonations() public {
        _deposit(alice, 100e6);

        uint256 donation = 50e6;
        asset.mint(bob, donation);
        vm.prank(bob);
        asset.transfer(address(vault), donation);

        assertEq(vault.totalAssets(), 100e6 + donation);
    }

    function _deposit(address user, uint256 assets) internal {
        vm.startPrank(user);
        asset.approve(address(vault), assets);
        vault.deposit(assets, user);
        vm.stopPrank();
    }
}
