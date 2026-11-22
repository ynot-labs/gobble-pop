# 《Gobble Pop!》（吞吞波波！）

面向美区 **H5（YouTube Playables / CrazyGames）/ iOS / Android** 的原创潮玩美食 × 物理吞噬休闲游戏（Godot 4.6 + Blender 5.3）。

## 立即在线试玩（H5）
- **GitHub Pages 在线版**：https://ynot-labs.github.io/gobble-pop/
- **操作方式**：鼠标按住拖拽 / 手机单指拖拽（浮动虚拟摇杆 + 桌面方向键），移动漩涡洞口吞噬物品升级扩容（Lv.1 → Lv.5），倒计时归零前清空顶部目标清单即可通关！
- **顶部快捷跳关栏**：一键切换 **4 大世界（W1 Bakery / W2 Toybox / W3 Bento / W4 Magic）** 及各世界的 `START / HARD / CLIFF / MEGA BOSS` 核心关卡。

## 4 大世界 × 50 关完整内容（含 4 个 30×34 超大关）
| 世界 | 关卡范围 | 主题视觉 | 核心机制 / 障碍 | 陡崖关 / 超大关 |
| --- | --- | --- | --- | --- |
| **World 1** | Lv.1–20 | Sugar Rush Bakery（甜品工坊） | 泡泡糖黏滞拉丝陷阱 | `Lv.10` Gum Gauntlet / `Lv.20` Grand Bakery Palace（30×34） |
| **World 2** | Lv.21–30 | Gacha Toybox（潮玩扭蛋箱） | 弹性橡皮筋护栏 + 泡泡糖 | `Lv.29` Golden Runway / `Lv.30` Mega Gacha Vault（30×34） |
| **World 3** | Lv.31–40 | Neon Bento Street（霓虹便当街） | 熔化芝士陷阱 + **时间炸弹（-3s）** | `Lv.39` Midnight Ramen Rush / `Lv.40` Grand Night Market（30×34） |
| **World 4** | Lv.41–50 | Cozy Alchemist Desk（炼金魔药桌） | 荧光史莱姆陷阱 + **时间炸弹（-3s）** + 弹性护栏 | `Lv.49` Arcane Gauntlet / `Lv.50` Grand Alchemist Library（30×34，5 Boss） |

## 当前里程碑进度
- [x] **M1 · 工程骨架 & 全部 4 大世界 2D 参考图**（`assets/refs_2d/`）
- [x] **M2 · Blender 5.3 全套 35 款 3D 资产（Core 5 + W1 9 + W2 8 + W3 6 + W4 7）& 14 项 ASMR 音频/BGM**
- [x] **M3 · 全部 4 大世界 50 关（含 4 个 30×34 超大关）+ 自动化难度/可达性校验器（50/50 PASS）+ 单线程 WebGL2 H5 打包**
- [ ] **M4 · 异步 `.pck` 远程分包 & 商业化激励广告 SDK 实机联调**
- [ ] **M5 · iOS（App Store）& Android（Google Play）原生双端打包**

## 目录结构
- `assets/refs_2d/`：2D 视觉定调与三视图参考图（已 `.gdignore`，不进导出包）
- `assets/models/`：Blender 5.3 导出的低模单 DrawCall `.glb` 模型（`core/` + `world1/`–`world4/`）
- `assets/audio/`：13 款 ASMR SFX + 1 首 45s 马林巴循环 BGM
- `assets/web/`：自定义 Key Visual 启动封面（`custom_shell.html` + `cover_splash.jpg`）
- `shaders/`：动态挖空桌面、旋涡 XP 进度环、黏滞拉丝形变、冰霜边框着色器
- `scripts/`：核心吞噬玩法、浮动摇杆、泡泡糖/芝士/史莱姆拉丝、橡皮筋护栏、时间炸弹（`-3s`）、DDA 调控、IAA 广告抽象层
- `data/levels/`：50 个差异化构图关卡 JSON（`level_001.json`–`level_050.json`）
- `tools/`：Blender 自动化建模脚本、50 关生成器（`generate_all_levels.py`）、耗时与 Lv.5 通道可达性自动校验器（`validate_difficulty.py`）、H5 包体审计（`audit_h5_bundle.py`）
- `build/h5/`：Godot 4.6 单线程 WebGL2 发布产物（由 GitHub Actions 自动部署至 GitHub Pages）
