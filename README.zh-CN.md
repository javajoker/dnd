# 抄本纪元 ·《烬港残页》

> English (default)：[`README.md`](README.md)

一款跑团式 d20 角色扮演手游（Godot 4.7）。你是一个"白页者"，身处一本正在褪色的书中：掷出命骰，每一次成败都会让故事分岔。引擎是内容包框架——战役、支线与子游戏都是数据，不是代码。

游戏为中英双语：缺省英文；手机系统语言为中文或玩家手动选择时为中文。英文移动版竖屏优先，序章与幕一免费，完整战役一次性解锁；国内发行口径为本体免费（完整战役随本体）。

## 仓库结构

| 目录 | 内容 |
|---|---|
| [`game/`](game/README.zh-CN.md) | Godot 工程：逻辑核、双渲染壳、内容包、工具、测试 |
| [`docs/`](docs/README.zh-CN.md) | 设计文档（中文原文为设计真相；英文镜像在 `docs/en/`） |
| [`prototype/`](prototype/README.zh-CN.md) | 零依赖浏览器原型（九类界面） |
| `.claude/` | 研发代理与技能（`godot-dev(-en)`、`godot-acceptance(-en)`、`godot-developer(-en)`） |

## 快速开始

需要 Godot 4.7.2（macOS：`/Applications/Godot.app/Contents/MacOS/Godot`）。运行游戏：`godot --path game`；无头测试：`godot --headless --path game -s tests/run.gd`；内容包校验：`godot --headless --path game -s tools/packlint.gd -- packs/campaign01`。截图、语言/市场/安全区参数与导出见 [`game/README.zh-CN.md`](game/README.zh-CN.md)。

## 进度

见 [TASKS](docs/framework/03-TASKS.md)（P4 段）与[代码评审](docs/en/tech/code-review-2026-11-10.md)。英文版游戏侧工作已完成；剩余需要商店账号与真机：计费插件适配器、导出模板 / SDK、真机走查。

## 许可

见 [LICENSE](LICENSE)。
