# Glossary — Chinese ↔ English (canonical terms)

> Every English document under `docs/en/` uses these renderings. When translating new docs or writing
> English game text, use this table so names stay consistent across docs, code comments and content packs.
> `docs/en/` is the design source of truth. This table maps the Chinese terms still found in the archived docs (`archive/zh-CN/`), code comments and the zh-CN game text to their canonical English names.

## Framework / technical terms

| 中文 | English | Notes |
|---|---|---|
| 框架白皮书 | Framework Whitepaper | |
| 五层漏斗 | five-layer funnel | L0 Epic → L4 Encounter |
| 纪元 | Epic (L0) / Era (in-world) | |
| 战役 / 战役书 | Campaign / Campaign Book | |
| 故事线 | Arc (story arc) | |
| 遭遇 | Encounter | |
| 世界状态板 / 状态板 | World State Board / Board | `Board` in code |
| 事件流 | Event Stream | `EventStream` in code |
| 旗标 | Flag | |
| 声望 | Reputation | |
| 时间钟 | Doom Clock | |
| 羁绊 | Bond | |
| 抉择倾向 | Alignment | |
| 溯源 | provenance | |
| 选择边 / 检定边 / 道具边 / 时间边 / 声望(倾向)边 | choice edge / check edge / item edge / time edge / reputation (alignment) edge | |
| 失败路 | failure path | |
| 收束 | convergence | |
| 内容包 | Content Pack | |
| 规则包 | Rule Pack | `light_v1` |
| 轻规则 / 标准 / 深度 | Light / Standard / Deep | rule-depth tiers |
| 权利 / 权利模型 | Entitlement / Entitlement Model | `global.entitlement.*` |
| 付费禁区 | monetization no-go zones | |
| 迭代双轨 / 内容轨 / 运营轨 | dual-track iteration / content track / operations track | |
| 一核两壳 | one core, two shells | |
| 横屏·空间战役 | Landscape · Spatial campaign | |
| 竖屏·时间战役 | Portrait · Temporal campaign | |
| 双模式可选 | dual-mode (player's choice) | |
| 强制竖屏 | forced portrait | |
| 三段呼吸 | three-band "breathing" layout | portrait main view / console heights flex |
| 横屏五区 | landscape five-zone layout | |
| 操作台 | Console (action console) | portrait bottom band |
| 房间序列 | room sequence | |
| 战术格 | tactical grid | |
| 整备 | Loadout (pre-battle prep) | |
| 快捷栏 | Quickbar | |
| 托管 | Auto-play (AutoAgent) | |
| 结算界面 | Settlement screen | |
| 历史卷轴 | History Scroll | |
| 图鉴 | Compendium | (avoids clash with "Codex" in the title) |
| 主屏 | Home screen | |
| 入口 | Entry screen | |
| 掷骰演出 | dice-roll presentation | |
| 快掷 / 全屏演出 | quick roll / full-screen roll | |
| 检定 / 豁免 / 难度 DC | check / saving throw / DC | |
| 优势 / 劣势 | advantage / disadvantage | |
| 暴击 | critical hit | |
| 死亡豁免 | death saves | |
| 属性：力 / 巧 / 智 | Might / Finesse / Wits | `might` / `finesse` / `wits` |
| 行动经济（移动/动作/附赠） | action economy (move / action / bonus) | |
| 修饰器管线 | modifier pipeline | base→add→mul→override→clamp |
| 多周目 / 继承 | New Game+ (NG+) / carry-over | |
| 子游戏 | Sub-game | |
| 支线挂接 | graft (side-arc grafting) | manifest `graft` |
| 校验 V1~V14 | validation rules V1–V14 | packlint |
| 审计 / 验收 | audit / acceptance | |
| 待裁决 | pending ruling | |

## World & story names (The Age of the Codex)

| 中文 | English |
|---|---|
| 抄本纪元 | The Age of the Codex (game title) |
| 艾洛温 | Elowen |
| 织命者 | the Weavers |
| 《万象卷轴》 | the Scroll of All Things |
| 织卷 | the Weave |
| 抄本 | codex page (a person's personal page of fate) |
| 褪墨 / 褪墨之灾 | the Fading |
| 白页者 | the Unwritten |
| 命骰 | the Fatedie |
| 誊写庭 | the Scriptorium |
| 断墨会 | the Uninked |
| 拾遗行会 | the Salvage Guild |
| 烬港 / 烬港自由市 | Ashenport / the Free City of Ashenport |
| 墨守 ↔ 留白 | Inkbound ↔ Blankward (alignment axis) |
| 撤销 / 被撤销者 / 撤销区 | revoked / the Revoked / the Revoked Quarter |
| 缮写圣城 | the Holy City of Scribes |
| 裂页荒原 | the Torn-Page Wastes |
| 深墨书库 | the Deep Ink Archive |
| 《烬港残页》 | *Ashenport Fragments* (campaign01) |
| 雾码头的回声 | *Echoes of Fog Wharf* (arc_tide) |
| 竞技场连战 | Arena Gauntlet (sub-game `arena`) |
| 解谜迷宫 | Riddle Maze (sub-game `riddle_maze`) |
| 休整所经营 | Haven Management (candidate sub-game) |
| 珂兰 | Kelan (companion) |
| 老费 | Old Fei (companion, `laofei`) |
| 墨魈 / 墨魈幼体 / 墨魈群 | Ink Fiend / Ink Imp / Ink Swarm |
| 守页人 | the Page Warden (boss) |
| 墨潮化身 | the Inktide Avatar (final boss) |
| 黑羽卫 | Black Feather Guard |
| 税吏 / 税吏卫队 | the Tax Collector / Tax Collector's Guard |
| 潮汐塔 | the Tide Tower |
| 雾码头 / 沉书阁 | Fog Wharf / the Sunken Library |
| 半页潮汐表 | Half-Page Tide Chart |
| 黑羽令 | Black Feather Token |
| 誊写庭印戒 | Scriptorium Signet |
| 织命者残简 | Weaver's Fragment |
| 墨核 | Ink Core |
| 补给药水 | Supply Potion |
| 执笔者 | the Penbearer (NG+ origin) |
| 追忆 | Remembrance (NG+ perspective) |
| 结局 E1 重墨 / E2 自由灰 / E3 新篇 / E4 褪墨吞港 | E1 Re-inked / E2 Free Ash / E3 A New Page / E4 The Fading Takes the Harbor |
