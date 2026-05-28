// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MiniVault4626} from "../../src/MiniVault4626.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";


contract VaultHandler is Test {
    MockERC20 public immutable asset;
    MiniVault4626 public immutable vault;

    address[] public actors;

    /// @notice Total underlying minted to actors (conservation baseline).
    uint256 public totalMinted;

    uint256 public callCount;

    constructor(MockERC20 asset_, MiniVault4626 vault_, address[] memory actors_, uint256 totalMinted_) {
        asset = asset_;
        vault = vault_;
        actors = actors_;
        totalMinted = totalMinted_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }

    function deposit(uint256 assets, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 balance = asset.balanceOf(actor);
        if (balance == 0) return;

        assets = bound(assets, 1, balance);

        vm.startPrank(actor);
        asset.approve(address(vault), assets);
        vault.deposit(assets, actor);
        vm.stopPrank();

        callCount++;
    }

    function mint(uint256 shares, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        shares = bound(shares, 1, 1e30);

        uint256 assetsNeeded = vault.previewMint(shares);
        uint256 balance = asset.balanceOf(actor);
        if (balance < assetsNeeded) return;

        vm.startPrank(actor);
        asset.approve(address(vault), assetsNeeded);
        vault.mint(shares, actor);
        vm.stopPrank();

        callCount++;
    }

    function withdraw(uint256 assets, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 maxAssets = vault.maxWithdraw(actor);
        if (maxAssets == 0) return;

        assets = bound(assets, 1, maxAssets);

        vm.prank(actor);
        vault.withdraw(assets, actor, actor);

        callCount++;
    }

    function redeem(uint256 shares, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 maxShares = vault.maxRedeem(actor);
        if (maxShares == 0) return;

        shares = bound(shares, 1, maxShares);

        vm.prank(actor);
        vault.redeem(shares, actor, actor);

        callCount++;
    }

    /// @dev Donate underlying to the vault without minting shares.
    function donate(uint256 amount, uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        uint256 balance = asset.balanceOf(actor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(actor);
        asset.transfer(address(vault), amount);

        callCount++;
    }

    function sumActorShares() external view returns (uint256 total) {
        for (uint256 i = 0; i < actors.length; i++) {
            total += vault.balanceOf(actors[i]);
        }
    }

    function sumActorAssets() external view returns (uint256 total) {
        for (uint256 i = 0; i < actors.length; i++) {
            total += asset.balanceOf(actors[i]);
        }
    }
}
