# GliderCancelRestore — 天擎鸟 E 键收伞

恢复 Palworld 中使用天擎鸟（Galeclaw）滑翔时按 **E** 立即结束滑翔的操作。Windows Steam 版 UE4SS Lua Mod。

## 功能

- 只对本地玩家正在使用的、ID 包含 `Eagle` 的天擎鸟滑翔生效。
- 调用游戏原生 `PalGliderComponent:EndGliding()`，结束后可再次按空格展开滑翔。
- 建造界面或 UI 鼠标指针显示时不触发。
- 不吞掉 E 原有输入，不修改体力、速度、重力、存档或全局键位。
- 缓存本地角色与滑翔组件，按 E 时不进行全局对象扫描。

## 安装与使用

1. 先准备与游戏版本兼容的 UE4SS。本仓库不附带或安装 UE4SS。
2. 从 Releases 下载安装 ZIP，将其中 `GliderCancelRestore` 文件夹放到 `Palworld/Mods/NativeMods/UE4SS/Mods/`。
3. 确认存在 `enabled.txt` 与 `Scripts/main.lua`。若 UE4SS 在其他位置，请使用其实际的 `Mods` 目录。
4. 从 Steam 启动游戏，携带天擎鸟，按空格展开滑翔，再按 E 收伞。

从源码安装时，本仓库根目录就是 Mod 目录；复制整个目录并命名为 `GliderCancelRestore`。

**不要同时启用此手动安装版与同功能的创意工坊版 `GliderCancelRestorePrivate`。** 如果已有创意工坊版，请先停用其中一份。

## 已验证环境与限制

- 历史实测游戏：Steam Palworld Build `24467282`。
- 历史实测加载器：UE4SS Experimental (Palworld) `experimental-palworld-6`，核心 v3.0.1 Beta #0，SHA `c838a8ac`。
- 当前版本：`0.3.2-cache-address-fix`。
- 历史实测：单人、本机作为房主。访客客户端、专用服务器与后续游戏版本未验证。
- 仅在允许客户端 Mod 的环境中使用；不要将单人测试结果视为服务器兼容保证。

这是历史实测版本的源码归档发布，尚未对当前游戏重新实测。游戏更新后请先确认兼容性；项目按现状提供，不承诺持续维护。

## 源码与卸载

完整 Lua 源码位于 `Scripts/main.lua`。运行日志生成在 Mod 自己的目录中。

退出游戏后移除 `GliderCancelRestore` 目录即可卸载；不会留下游戏配置或存档改动。

发布账户：[rainyaesc](https://github.com/rainyaesc)。这是非官方社区 Mod，与 Pocketpair 无隶属关系。
