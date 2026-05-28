// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MiniVault4626} from "../../src/MiniVault4626.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {VaultHandler} from "./VaultHandler.sol";

contract MiniVault4626InvariantTest is Test {
    uint8 internal constant ASSET_DECIMALS = 6;
    uint8 internal constant DECIMAL_OFFSET = 3;

    uint256 internal constant ACTOR_BALANCE = 10_000_000e6;

    MockERC20 internal asset;
    MiniVault4626 internal vault;
    VaultHandler internal handler;

    address[] internal actors;

    function setUp() public {
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));

        asset = new MockERC20("Mock USD", "mUSD", ASSET_DECIMALS);
        vault = new MiniVault4626("Mini Vault", "mvUSD", address(asset), DECIMAL_OFFSET);

        for (uint256 i = 0; i < actors.length; i++) {
            asset.mint(actors[i], ACTOR_BALANCE);
        }

        handler = new VaultHandler(asset, vault, actors, actors.length * ACTOR_BALANCE);

        vm.startPrank(actors[0]);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, actors[0]);
        vm.stopPrank();

        targetContract(address(handler));
    }

    function invariant_totalAssetsMatchesBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }

    function invariant_allSharesHeldByActors() public view {
        assertEq(handler.sumActorShares(), vault.totalSupply());
    }

    function invariant_assetConservation() public view {
        uint256 accounted = handler.sumActorAssets() + vault.totalAssets();
        assertEq(accounted, handler.totalMinted());
    }

    function invariant_fullRedeemWithinAssets() public view {
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;
        assertLe(vault.convertToAssets(supply), vault.totalAssets());
    }

    function invariant_convertToIndependentOfCaller() public {
        uint256 assets = 1000e6;
        if (vault.totalAssets() == 0) return;

        address caller1 = actors[0];
        address caller2 = actors[1];

        vm.prank(caller1);
        uint256 shares1 = vault.convertToShares(assets);

        vm.prank(caller2);
        uint256 shares2 = vault.convertToShares(assets);

        assertEq(shares1, shares2);
    }
}
