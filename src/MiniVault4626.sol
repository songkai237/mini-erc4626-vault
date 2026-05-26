// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MiniVault4626 is ERC20, IERC4626 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    IERC20 private immutable i_asset;
    uint8 private immutable i_assetDecimals;
    uint8 private immutable i_decimalOffset;

    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    constructor(string memory name, string memory symbol, address _asset, uint8 decimalOffset_)
        ERC20(name, symbol)
    {
        i_asset = IERC20(_asset);
        i_assetDecimals = IERC20Metadata(_asset).decimals();
        i_decimalOffset = decimalOffset_;
    }

    function decimals() public view override(IERC20Metadata, ERC20) returns (uint8) {
        return i_assetDecimals + i_decimalOffset;
    }

    function asset() public view returns (address assetTokenAddress) {
        return address(i_asset);
    }

    function totalAssets() public view returns (uint256) {
        return i_asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function maxDeposit(address) public pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);
    }

    function maxMint(address) public pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        assets = previewMint(shares);
        _deposit(msg.sender, receiver, assets, shares);
    }

    function maxWithdraw(address owner) public view returns (uint256 maxAssets) {
        return previewRedeem(maxRedeem(owner));
    }

    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function maxRedeem(address owner) public view returns (uint256 maxShares) {
        return balanceOf(owner);
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    function _decimalsOffset() internal view returns (uint8) {
        return i_decimalOffset;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        i_asset.safeTransferFrom(caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        i_asset.safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
