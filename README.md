# Mini ERC4626 Vault

一个基于 [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) 的极简 Tokenized Vault 练习项目，使用 Foundry 开发与测试。

## 项目简介

ERC-4626 将以太坊上的「金库 / 收益池」标准化为统一的接口：用户存入底层资产（underlying asset），获得代表份额的 vault share；赎回时按份额换回资产。该标准让钱包、聚合器、DeFi 协议可以用同一套逻辑对接不同的 vault，而不必为每个产品单独适配。

本项目旨在从零实现一个**最小可用**的 ERC4626 vault：

- **份额与资产的换算**：`convertToShares` / `convertToAssets`、首次存款时的份额定价
- **存取流程**：`deposit` / `mint` / `withdraw` / `redeem` 及对应的事件
- **预览与滑点**：`previewDeposit`、`previewWithdraw` 等与链上执行的一致性
- **常见边界**：空池首存、舍入方向、与 ERC-20 的 `transferFrom` 交互

Vault 将底层 ERC-20 作为 `asset()`，自身发行的 share 同时满足 ERC-20 与 ERC-4626 语义（份额代币可转账、授权）。

## 技术栈


| 工具                                                   | 用途             |
| ---------------------------------------------------- | -------------- |
| [Foundry](https://book.getfoundry.sh/)               | 编译、测试、部署脚本     |
| [forge-std](https://github.com/foundry-rs/forge-std) | 测试与 cheatcodes |


## 项目结构（规划）

```
src/          # Vault 合约与相关接口
test/         # 单元测试与 ERC4626 行为覆盖
script/       # 部署脚本（可选）
```

## 快速开始

```bash
# 安装依赖（含 forge-std 子模块）
forge install

# 编译
forge build

# 运行测试
forge test -vvv

# 格式化
forge fmt
```

## 参考

- [EIP-4626: Tokenized Vault Standard](https://eips.ethereum.org/EIPS/eip-4626)

