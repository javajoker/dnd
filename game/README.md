# game/ —— 抄本纪元 Godot 工程

> 研发流程与铁律：`.claude/skills/godot-dev/SKILL.md`（每次任务必读）
> 验收审计：`.claude/skills/godot-acceptance/SKILL.md`
> 英文版：[`README.en.md`](README.en.md)；英文技能 `godot-dev-en` / `godot-acceptance-en`
> 设计真相：`../docs/`（framework 设计 / tech 技术契约 / story 内容）

## 环境

- Godot 4.7.2：`/Applications/Godot.app/Contents/MacOS/Godot`（GDScript 通道，tech/01 E-1 裁决）
- 无头测试：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/run.gd`

## 结构

| 目录 | 职责 | 铁律 |
|---|---|---|
| `core/` | 逻辑核：状态板 / 事件流 / 故事图 / 遭遇状态机 / 规则包 / 存档 | 只含 RefCounted，零引擎依赖 |
| `shell/` | 渲染壳：九类界面 + 竖屏时间 / 横屏空间双形态 | 只消费事件流、只读状态板 |
| `packs/` | 内容包源（tech/02 §1 结构），发布打 PCK | 数据驱动，不含逻辑 |
| `tools/` | packlint（V1~V14）/ simulate（bot 仿真）/ winrate / shell_diff / 资产生成器 | 命令行，复用 core 求值代码 |
| `tests/` | 无头测试 | 随功能递增断言 |

## 技术原型路线（tech/01 §10）

TP0 逻辑核骨架 → TP1 campaign01 仿真全结局 → TP2 单遭遇竖屏壳 → TP3 双壳事件流一致性 → TP4 九界面最小闭环。

## 手势层

- 12 §1 全词表已落地（`shell/ui/gesture_recognizer.gd` / `gesture_layer.gd`，双壳共享）：点按、长按、拖动、拖动轨迹、横滑、双指点击、捏合；
- 铁律不变：一切手势必须有按钮等价路径（12 §1）。

## 已知问题

见 `../docs/en/tech/code-review-2026-11-10.md`：启动不读回存档（B1）、横屏只缩放桌面窗口（B2）、新开局固定种子（B3）、测试读写真实 user:// 数据（B4）。整改路线见 `../docs/framework/03-TASKS.md` P4。
