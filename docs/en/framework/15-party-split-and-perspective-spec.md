# 15 · Party Split, Perspective and Remote Play — Spec

> Status: **design final, not yet implemented** (TASKS P5). Related: whitepaper §5 (story graph) and §7 (two forms), doc 04 (screens), doc 08 (edges), doc 09 (encounters and forms), doc 11 (rules), doc 12 (gestures), doc 16 (maps), tech/02 (pack format).

A classic tabletop moment: *"You two take the archive, we'll check the docks — meet at the lighthouse at midnight."* This spec makes that a first-class, data-driven feature: the party can **split into groups**, each group follows its **own sub-plot**, the player **switches or splits the view** between them, and groups stay connected through **limited remote interaction and teleportation**. The same model is the foundation for **online multiplayer** later (one player per character or group).

## 1. Concepts

| Term | Meaning |
|---|---|
| **Roster** | Every character in the party (player template + companions), as today. |
| **Group** | A subset of the roster that is physically together. When the party is whole there is exactly one group, `main`. |
| **Thread** | The sub-plot a group is playing: a sub-graph of the story graph with its own *current node*. One group = one thread. |
| **Split edge** | An edge that divides the party into groups and sends each into its thread. |
| **Rejoin node** | The node where threads converge. It waits until every group has arrived (a barrier). |
| **Focus** (primary perspective) | The group whose thread the console is driving right now. Exactly one group has focus. |
| **Link** | A limited channel between separated groups: messages, help, remote triggers, teleporting members or items (§5). |

Invariants:

- **One Board, one event stream, one Doom Clock** — groups share world state; a flag written in one thread is visible in the others (they live in the same world). Threads differ only in *where each group is* and *who is in it*.
- A character belongs to exactly one group at a time.
- Only one **encounter** runs at a time (§4.3); other groups are paused while it plays.

## 2. Story-graph model

### 2.1 Split edge

```json
{ "type": "split", "label": "Split up: docks and archive",
  "groups": [
    { "id": "docks",   "members": ["player_blank"],                         "entry": "T-D1" },
    { "id": "archive", "members": ["companion_kelan", "companion_laofei"], "entry": "T-A1" }
  ],
  "rejoin": "N3-0",
  "assign": "fixed",
  "linear_fallback": "N2-L1" }
```

- `members`: fixed assignment, or `"assign": "player"` — the player drags portraits into the groups (with `min`/`max` per group and `requires` such as "Kelan must go to the archive");
- `entry`: the first node of each thread; `rejoin`: the convergence node (must be reachable from every thread);
- `linear_fallback`: the edge used when splitting isn't unlocked yet (NG+ progression, §7) — then the party stays together and plays a single linear path. **Required** whenever the split is gated;
- Inventory: on split the player **divides the pack** (§3.3); equipment stays with whoever wears it.

### 2.2 Thread nodes

- Thread nodes are ordinary nodes; three extra conditions are available in the condition DSL:
  - `in_group: "<char_id>"` — the focused group contains that character (unique scenes for a character);
  - `group_size: {"lte": 1}` — "alone" scenes;
  - `thread: "<group_id>"` — the node belongs to that thread (validator uses it to keep threads separate).
- **Per-character checks**: inside a thread, a check edge is rolled by the group's **lead** (the first member, or a `roller` declared on the edge). Its modifier comes from that character's attributes and proficiencies (doc 11 §2) — so Kelan's thread genuinely plays like Kelan.
- Battles inside a thread take **only that group's members** (`party_from: "group"` on the encounter). Content must tune them for the smaller party (V8 checks unit caps per group size).

### 2.3 Rejoin

- A group that reaches the rejoin node shows **"Waiting at the lighthouse"** and loses focus; focus moves to the next unfinished group.
- When the last group arrives, the groups merge back into `main`, the pack is pooled again, and the rejoin node plays a **reunion beat** (`on_rejoin` effects, text variants that reference what each thread did via its flags).
- A `doom_clock` edge may force an early rejoin ("midnight comes whether you're ready or not"); unfinished threads resolve through their `timeout` edge (failure is a branch, doc 08 §2).

### 2.4 Time across threads

- The Doom Clock is shared. Thread nodes advance it as usual; because the player chooses which group acts, the framework keeps threads from drifting apart: a group may be at most **`max_drift` clock segments** ahead of the slowest group (manifest, default 1). When a group hits the cap, its actions are disabled with the hint "The others need time — switch to them".
- Time edges (`doom_clock`) fire for **every** thread that has one at that segment.

## 3. State on the Board

| Key | Content |
|---|---|
| `<ns>.party.groups` | `{group_id: {members: [char ids], node: node_id, status: "active"|"waiting"|"in_encounter"}}` |
| `<ns>.party.focus` | The focused group id |
| `<ns>.party.stash.<group_id>` | `{item_id: count}` — the part of the pack this group carries |
| `<ns>.party.links` | Remaining link charges per group (§5) |

- These are bookkeeping keys (never read out on the settle screen) written with provenance like every other key.
- `global.inv` stays the party total; the stash keys partition it. Invariant (validated in tests): the stashes sum to `global.inv` while split; on rejoin the stashes are cleared.
- Saves snapshot the groups like any other Board state; "Continue" restores focus.

### 3.3 Dividing the pack

```
┌──────────────────────────────┐
│ Divide the pack              │
│ [Docks: Unwritten] [Archive: Kelan, Old Fei] │ ← group drop targets
├──────────────────────────────┤
│ Docks pouch 1/2: ● Potion ×1 │
│ Archive pouch 2/2: ● Potion ×1 ● Ink Flask ×1 │
├──────────────────────────────┤
│ Unassigned: Ink Flask ×1, Half-Page Tide Chart │ ← library (drag onto a group)
├──────────────────────────────┤
│ [Default split]   [Split up] │
└──────────────────────────────┘
```

On split, a **Divide the pack** sheet appears (reusing the loadout library and drag-and-drop, doc 09 §9.1 v2): each group is a drop target; items are dragged between groups; the quick pouch is per group. A **Default split** button gives each group a fair share (healing first, then by member count).

## 4. Interface

### 4.1 Perspective switcher (both forms)

A **group strip** replaces the party chips in the status band while the party is split. Each group is a tab: portraits, HP summary, and a status dot (● acting, ◌ waiting, ⚔ in battle, ✉ unread link message).

- **Tap a group tab** = switch focus (the main view cross-fades to that thread's scene; the console rebinds to that group);
- **Swipe horizontally on the main view** = previous / next group (portrait), mirroring the console tab swipe;
- The unfocused groups keep a one-line **"Meanwhile…"** ticker (their last log line) under the strip.

### 4.2 Portrait (time form)

```
┌──────────────────────────────┐
│ Clock 4 → 5 ⚠   [Docks●][Archive◌] │ ← group strip (status band)
│ Meanwhile at the Archive: Kelan… │ ← one-line ticker
├──────────────────────────────┤
│                              │
│   Main view: focused thread  │
│   (room / scene / dialogue)  │
│                              │
├──────────────────────────────┤
│ d20  last roll …             │ ← dice strip (shared)
│ Action | Log | Party         │ ← console drives the focused group
│ [choices…]  [✉ Link]         │
└──────────────────────────────┘
```

- **Split view (portrait)**: tap ⧉ in the status band to stack two threads (top 45% / bottom 55%). The focused half is full-brightness and owns the console; the other half is a live but dimmed read-only view. Tap the dimmed half to swap focus. Available for **two groups**; with three or more, the switcher is the only mode. Disabled during encounters (the encounter takes the full screen, doc 09 §5).

### 4.3 Landscape (space form)

```
┌───────────────┬───────────────────────────┬───────────┐
│ Docks (focus) │ Archive                   │ Group rail│
│ main view     │ secondary view (dimmed)   │ [Docks●]  │
│               │                           │ [Archive◌]│
│               │                           │ [✉ Link]  │
├───────────────┴───────────────────────────┴───────────┤
│ Console for the focused group  (action wheel / log)   │
└───────────────────────────────────────────────────────┘
```

- Side-by-side split for two groups (focused pane 60%, other 40%); a third group appears as a thumbnail in the rail. Tap a pane or a rail entry to focus.
- **Encounters**: only one battle at a time. When a group enters a battle, the battle takes the whole screen; other groups pause ("time holds while steel speaks"). A future version may allow simultaneous battles in split view (§8).

### 4.4 Gestures (doc 12 additions)

| Gesture | Where | Effect |
|---|---|---|
| Tap | Group tab / pane | Switch focus |
| Swipe left/right | Main view (portrait, outside encounters) | Previous / next group |
| Long-press | Group tab | Group card (members, stash, link charges) |
| Drag | Item from the Party tab onto another group's tab | Send it through a link (§5.2), if allowed |
| Tap ⧉ | Status band | Toggle split view |

## 5. Links: remote interaction and teleportation

Links are **scarce and diegetic** — they come from items, places or skills declared by content, never from a menu that always works. Each costs a **link charge** (restored on a long rest) and is logged with provenance.

### 5.1 Remote interaction (limited)

| Link | Effect | Typical source |
|---|---|---|
| **Message** | Send one short, pre-written line (choose from 3 content-provided options); may write a shared flag (e.g. "the archive found the cipher key") that unlocks options in the other thread | Paired quills, sending shells |
| **Help from afar** | The other group's **next check** rolls with advantage (doc 11 §3.1 source "link") | Same, or a bond ability |
| **Remote trigger** | Activate an interactable in another thread that content marked `remote: true` (pull the lever that opens the other group's gate) | A node with a `remote` edge |

Content declares remote triggers as an edge type:

```json
{ "type": "remote", "label": "Pull the tide lever (opens the archive gate)", "target_thread": "archive",
  "effects": [ { "write": "archive_gate_open", "value": true } ], "cost": 1 }
```

### 5.2 Teleportation (members and items)

| Teleport | Rule |
|---|---|
| **Item** | Move items from one group's stash to another (drag onto the group tab). Cost 1 charge; weight-free but limited to `max_items` per send (manifest, default 2). |
| **Member** | Move a character from one group to another. Only between **anchors** (content-declared nodes with `anchor: true` — circles, mirrors, ink doors). Cost 2 charges and **+1 Doom Clock**. A group may never be emptied. |
| **Recall** | Everyone to one anchor = an early rejoin, if the rejoin node allows it (`allow_recall`). |

Rules that keep it fair: links never move **encounters** (you can't teleport into a running battle), never bypass `requires` gates on the receiving thread, and are disabled while the sender is in an encounter.

## 6. Mode and orientation rules

- A split works in **both forms** (doc 09 §8); the campaign's chosen form decides the layout (§4.2 / §4.3).
- **Side campaigns** follow the same decision tree as main campaigns (doc 09 §2), restated for authors:
  - a **space-based** side campaign (big maps, many units, tactical positioning) is declared `space` → **landscape**;
  - a **time-based, multi-room** side scenario (a sequence of rooms, fragments, a ticking clock) is declared `time` → **portrait**.
- Split view needs room: portrait split view is limited to two groups; landscape supports two panes + rail.

## 7. Feature progression across playthroughs

A content pack can **unlock framework features per playthrough** so the first run is simple and later runs open up. Declared in the manifest:

```json
"progression": {
  "1": { "split": false, "links": false, "lead": "player" },
  "2": { "split": true,  "links": false, "lead": "player" },
  "3": { "split": true,  "links": true,  "lead": "any" }
}
```

- `split: false` → every split edge takes its `linear_fallback`; the party never divides;
- `links: false` → link edges and link UI are hidden (split threads are then fully independent);
- `lead: "any"` → at campaign start the player may choose a **companion as the lead character** (their thread becomes the main perspective; doc 08 text variants handle the changed point of view);
- Unlocks are read from `<ns>.ngplus.playthrough` (NG+ carry-over, tech/02 §2.7) and can also be granted by achievements (doc 06: entitlement-style lighting, never sold as power);
- Validator: every gated split edge has a `linear_fallback`; every thread is completable without links unless the pack declares `links_required` for that thread (then it must be unlocked in the same tier as `split`).

## 8. Online multiplayer (future, architecture constraints now)

Not in scope for implementation; the constraints below keep it possible and are **binding from now on**:

1. **Seats**: a multiplayer session maps players to characters (or to groups when split). Choice edges while together resolve by the group's **leader vote** (configurable: leader decides / majority / unanimous with timeout).
2. **Authority**: one host (later a server) owns the Board, the event stream and the RNG seed. Clients send **Commands** — the same isomorphic `{type, actor, target, skill, item, source}` objects the shells already send (tech/01 §6.2); shells never write the Board.
3. **Dice fairness**: all rolls happen on the authority; clients only animate the given result (doc 17 — physics never decides).
4. **Disconnects**: the auto-play agent (doc 09 §9.3) takes over the absent player's characters, tagged `source: auto`.
5. **Rollout**: (1) local pass-and-play (one device, seat handoff screen); (2) asynchronous online turns (sync the event stream); (3) real-time co-op. A split party is the natural way to give each player their own scenes.

## 9. Validation (packlint additions, tech/02 §12)

- **V16 split integrity**: every thread is reachable from its entry, reaches the rejoin node, and has no edges into another thread except via `rejoin`/`remote`;
- **V17 group battles**: encounters inside a thread declare `party_from: "group"` and respect unit caps for the smallest possible group;
- **V18 progression fallbacks**: gated splits have `linear_fallback`; `links_required` threads are unlocked together with their split.

## 10. Acceptance (summary; full checklist in doc 13)

- Split → divide the pack → two threads playable in any order → rejoin with a reunion beat referencing both threads;
- Focus switching by tap and swipe; split view in both forms; a running battle pauses the other groups;
- Message, help-from-afar, remote trigger, item and member teleport each cost charges, are logged, and respect gates;
- Playthrough 1 of a pack with `progression` never splits; playthrough 2 does.
