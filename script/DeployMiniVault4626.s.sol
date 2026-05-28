// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MiniVault4626} from "../src/MiniVault4626.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";


contract DeployMiniVault4626 is Script {
    function run() external returns (MiniVault4626 vault, address asset) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerPrivateKey != 0) {
            vm.startBroadcast(deployerPrivateKey);
        } else {
            vm.startBroadcast();
        }

        (vault, asset) = _deploy();

        vm.stopBroadcast();

        console2.log("Asset", asset);
        console2.log("Vault", address(vault));
        console2.log("Vault decimals", vault.decimals());
        console2.log("Total assets", vault.totalAssets());
    }

    function _deploy() internal returns (MiniVault4626 vault, address asset) {
        asset = vm.envOr("ASSET_ADDRESS", address(0));

        string memory vaultName = vm.envOr("VAULT_NAME", string("Mini Vault"));
        string memory vaultSymbol = vm.envOr("VAULT_SYMBOL", string("mvault"));
        uint8 decimalOffset = uint8(vm.envOr("DECIMAL_OFFSET", uint256(0)));
        uint256 seedDeposit = vm.envOr("SEED_DEPOSIT", uint256(0));

        bool deployedMock = asset == address(0);
        if (deployedMock) {
            uint8 assetDecimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(6)));
            MockERC20 mock =
                new MockERC20(string.concat("Mock ", vaultSymbol), string.concat("m", vaultSymbol), assetDecimals);
            asset = address(mock);
        }

        vault = new MiniVault4626(vaultName, vaultSymbol, asset, decimalOffset);

        if (seedDeposit > 0 && vault.totalAssets() == 0) {
            if (deployedMock) {
                MockERC20(asset).mint(msg.sender, seedDeposit);
            }
            IERC20(asset).approve(address(vault), seedDeposit);
            vault.deposit(seedDeposit, msg.sender);
            console2.log("Seed deposit into vault", seedDeposit);
        }
    }
}
