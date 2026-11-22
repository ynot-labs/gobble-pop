# 《Gobble Pop!》（吞吞波波！）

面向美区 **H5（YouTube Playables / CrazyGames）/ iOS / Android** 的原创潮玩美食 × 物理吞噬休闲游戏（Godot 4.6 + Blender 5.3）。

## 立即在线试玩（H5）
- **GitHub Pages 在线版**：https://ynot-labs.github.io/gobble-pop/
- **操作方式**：鼠标按住拖拽 / 手机单指拖拽（桌面端也支持方向键），移动漩涡洞口吞噬小甜品升级扩容（Lv.1 → Lv.5），倒计时归零前清空顶部目标清单即可通关！

## 当前里程碑进度
- [x] **M1 · 工程骨架 & 首包 2D 三视图参考图**（`assets/refs_2d/`）
- [x] **M2 · Blender 5.3 首包 13 款 3D 资产 & 14 项 ASMR 音频/BGM**（全项通过面数与体积红线：4,440 Tris / 154.9 KB GLB / 281.5 KB 音频）
- [x] **M3 · World 1《糖果甜品工坊》完整 20 关 + 单线程 WebGL2 H5 打包**（`.pck` Gzip 690 KB，总包体 Gzip 9.78 MB，满足 YouTube Playables `<15 MiB` & CrazyGames `<=20 MB`）
- [ ] **M4 · World 2–4（21 款分包资产）+ 异步 `.pck` 分包 + UI 糖果图标图集**
- [ ] **M5 · iOS（App Store）& Android（Google Play）原生商业化双端打包**

## 目录结构
- `assets/refs_2d/`：2D 视觉定调与三视图参考图（已 `.gdignore`，不进导出包）
- `assets/models/`：Blender 5.3 导出的低模单 DrawCall `.glb` 模型
- `assets/audio/`：13 款 ASMR SFX + 1 首 45s 马林巴循环 BGM
- `shaders/`：动态挖空大理石桌面、旋涡 XP 进度环、泡泡糖拉丝形变、冰霜边框着色器
- `scripts/`：核心玩法、DDA 动态难度调控、IAA 广告抽象层（支持 YouTube Playables / CrazyGames / Mobile）
- `data/levels/`：World 1 Lv.1–Lv.20 锯齿波浪难度关卡配置
- `build/h5/`：Godot 4.6 单线程 WebGL2 发布产物（由 GitHub Actions 自动部署至 GitHub Pages）
