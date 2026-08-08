# Global Codex Guidance (~/.codex/AGENTS.md)

Global working agreements for Codex CLI.

## Accuracy, recency, and sourcing (REQUIRED)

When a request depends on recency (e.g., "latest", "current", "today", "as of now"):

1. **Establish the current date/time** and state it explicitly in ISO format.
   - Preferred: `date -Is` (timestamp).

2. **Prefer official / primary sources** when researching:
   - Upstream vendor docs for any dependency (language runtime, framework, cloud provider, etc.)

3. **Prefer the most recent authoritative information**:
   - Use the newest versioned docs, release notes, or changelogs.
   - Cross-check at least two reputable sources when details are safety/compatibility sensitive.

### Context7 MCP

- Use Context7 when you need library/API docs.
- If known, pin the library with slash syntax (e.g., `use library /supabase/supabase`).
- Mention the target version.
- Fetch minimal targeted docs; summarize (no large dumps).

### Web search policy

- Enable and use web search only when it materially improves correctness (e.g., up-to-date APIs, recent advisories, release notes).
- Prefer official docs and primary sources; otherwise use Context7 MCP or reputable, widely-cited references.
- Record source dates (publish/release dates) when relevant.

## Default autonomy and safety

- Default to read-only exploration and analysis.
- When edits are needed, prefer **workspace-scoped** write access and keep changes inside the repo.
- When interacting with remote APIs, you must use READ-only calls, unless explicitily instructed otherwise by the user. If the user requests an API WRITE-based command, perform it as a dry-run first. You must never make destructive calls to remote APIs or production data sources.

### Editing files

- Make the smallest safe change that solves the issue.
- Preserve existing style and conventions.
- Prefer patch-style edits (small, reviewable diffs) over full-file rewrites.
- After making changes, run the project’s standard checks when feasible (format/lint, unit tests, build/typecheck).

### Reading project documents (PDFs, uploads, long text, CSVs, etc)

- Read the full document first.
- Draft the output.
- **Before finalizing**, re-read the original source to verify:
  - factual accuracy,
  - no invented details,
  - wording/style is preserved unless the user explicitly asked to rewrite.
- If paraphrasing is required, label it explicitly as a paraphrase.

### Container-first policy (REQUIRED)

- Codex must **never** install system packages on the host unless explicitly instructed.
- Prefer container images to supply all tooling used by the project.
- For code projects and dependencies: **use containers by default**.
- If the repo has an existing container workflow (Dockerfile/compose/Makefile targets), follow it.
- If the repo has no container workflow, create a minimal one.
- Keep repo-specific container details in the repo’s `AGENTS.md`.

### Secrets and sensitive data

- Never print secrets (tokens, private keys, credentials) to terminal output.
- Do not request users paste secrets.
- Avoid commands that might expose secrets (e.g., dumping env vars broadly, `cat ~/.ssh/*`).
- Prefer existing authenticated CLIs; redact sensitive strings in any displayed output.

## Baseline workflow

- Start every task by determining:
  1. Goal + acceptance criteria.
  2. Constraints (time, safety, scope).
  3. What must be inspected (files, commands, tests, docs).
  4. Whether the request depends on **recency** (if yes, apply the "Accuracy, recency, and sourcing" rules).
  5. If requirements are ambiguous, ask targeted clarifying questions before making irreversible changes.

## CONTINUITY.md (REQUIRED)

Maintain a single continuity file for the current workspace: `.agent/CONTINUITY.md`.

- `.agent/CONTINUITY.md` is a living document and canonical briefing designed to survive compaction; do not rely on earlier chat/tool output unless it's reflected there.

- At the start of each assistant turn: read `.agent/CONTINUITY.md` before acting.

### File Format

Update `.agent/CONTINUITY.md` only when there is a meaningful delta in:

  - `[PLANS]`: "Plans Log" is a guide for the next contributor as much as checklists for you.
  - `[DECISIONS]`: "Decisions Log" is used to record all decisions made.
  - `[PROGRESS]`: "Progress Log" is used to record course changes mid-implementation, documenting why and reflecting upon the implications.
  - `[DISCOVERIES]`: "Discoveries Log" is for when when you discover optimizer behavior, performance tradeoffs, unexpected bugs, or inverse/unapply semantics that shaped your approach, capture those observations with short evidence snippets (test output is ideal.
  - `[OUTCOMES]`: "Outcomes Log" is used at completion of a major task or the full plan, summarizing what was achieved, what remains, and lessons learned.

### Anti-drift / anti-bloat rules

- Facts only, no transcripts, no raw logs.
- Every entry must include:
  - a date in ISO timestamp (e.g., `2026-01-13T09:42Z`)
  - a provenance tag: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`
  - If unknown, write `UNCONFIRMED` (never guess). If something changes, supersede it explicitly (don't silently rewrite history).
- Keep the file bounded, short and high-signal (anti-bloat). 
- If sections begin to become bloated, compress older items into milestone (`[MILESTONE]`) bullets.

## Definition of done

A task is done when:

- the requested change is implemented or the question is answered,
  - verification is provided:
  - build attempted (when source code changed),
  - linting run (when source code changed),
  - errors/warnings addressed (or explicitly listed and agreed as out-of-scope),
  - plus tests/typecheck as applicable,
- documentation is updated exhaustively for impacted areas,
- impact is explained (what changed, where, why),
- follow-ups are listed if anything was intentionally left out.
- `.agent/CONTINUITY.md` is updated if the change materially affects goal/state/decisions.

# Gog Roll Planner Agent Guide

## Project

This repository contains a compact REFramework Lua planner for Monster Hunter
Wilds Artian/Gogma set/group skills and base reinforcement sequences.

The active implementation is:

```text
reframework/autorun/GARP.lua
```

Treat the Lua source as authoritative. `README.md` is the player-facing guide;
keep its working features and limitations aligned with the implementation.

## Environment

- Development root: `D:\Games\Capcom Mods\Games\MonsterHunterWilds\Dev\Gog Roll Planner`
- Installed script: `D:\Games\Steam\steamapps\common\MonsterHunterWilds\reframework\autorun\GARP.lua`
- Runtime data: `D:\Games\Steam\steamapps\common\MonsterHunterWilds\reframework\data`
- REFramework UI opens with `Insert`; script changes require **Reset scripts**.
- Deploy by copying the development Lua file to the installed script path.
- The game directory is outside the normal writable workspace and may require
  elevated permission.

Do not overwrite user runtime configuration or capture files during deployment.

## Confirmed Findings

### Gogma set/group skill rerolls

- Rerolls occur in `app.Em0078_ArtianUtil.lotterySkill(app.savedata.cEquipWork)`.
- The weighted `ArtianSkillGroupData` table has total probability 294.
- The plugin maps `ArtianSkillType` values to set/group skill combinations.
- The native RNG model has been validated against consecutive in-game results.
- Seed input combines weapon type, attribute force, save seed, and the skill
  stream's persistent counter.
- The runtime enum returned by `getArtianSkillType` already uses the fixed table
  ID. Do not add one: runtime value `1` is Doshaguma / Neopteron Alert, while
  changing it to `2` incorrectly labels the result as Neopteron Camouflage.
- The skill counter is read from the stream object at offset `0xF4`. Do not
  reuse it for Gogma reinforcement prediction.
- A newly upgraded Gogma weapon advances/uses the relevant predetermined stream;
  route planning must eventually compare rerolls against creating additional
  weapons.

### Reinforcement encoding

- `cEquipWork.BonusByGrinding` stores five three-digit bonus codes in reverse
  display order.
- Base code mappings are `4=Element`, `6=Attack`, `7=Sharpness`, `8=Affinity`.
- Base Attack/Affinity/Element level I is treated as the corresponding base
  Artian bonus.
- There is only `Sharpness Boost` and `Sharpness/Ammo Boost EX` in the sharpness
  family. Do not add Defense Boost or Slot Boost.
- Gogma rerolls do not roll base-tier Attack/Affinity/Element bonuses; they start
  at tier II.

### Base Artian reinforcement generation

- `app.GUI000019` is the base reinforcement material/confirmation controller.
- `_EquipWork` is the selected weapon and `_TemporaryEquipWork` is a candidate
  used by some paths.
- `execute()` handles confirmation/material processing; `applyGrind(Boolean)` is
  not used by the tested base path.
- A fresh `0/5` weapon already has its complete five-slot sequence in
  `BonusByGrinding` before reinforcement:

- Base Artian creation advances `cEquipParam`'s
  `getArtianCreateCount(TYPE, RARE)` / `addArtianCreateCount(TYPE, RARE)` counter.
  Controlled Fire/Water Insect Glaive tests show elements share the same stream;
  the counter signature indicates the stream is keyed by weapon type and rarity.
- `getArtianEquipWork(...)` only initializes the weapon from its parts.
  `addEquipBoxArtianWeapon(...)` only inserts the completed work into the box, so
  reinforcement-sequence generation occurs inline between those calls in
  `createArtianWeapon(...)`.
- Base rarity-8 reinforcement generation is now reverse-engineered from
  `createArtianWeapon(...)`: initialize the existing four-word xorshift with
  `(saveSeed % 100000000 + weaponType * 1000 + rarity) XOR 0x00AC9365`, advance
  `createCount * 10` steps, then use five successive values against a
  recipe-built `List<app.ArtianGrindingData.cPartsPoint>`.
  `GrindingNum` only controls how many entries have been revealed/applied.
- Therefore the sequence is generated at weapon creation, not once per level.
- Each native `cPartsPoint` entry stores `BonusId`, a current-use count, and a
  maximum-use count. A draw chooses one live entry by `rng % poolSize`,
  increments its count, and removes it when the maximum is reached.
- v0.2.37/38 incorrectly treated filtered rows from
  `ArtianDataSetting._BonusData` as the constructed native pool. The executable
  applies additional compatibility tests before constructing `cPartsPoint`
  entries, so those rows and their apparent limits cannot drive prediction.
- v0.2.39 restores the validated base pool in native order:
  `{Element:5, Attack:5, Sharpness:2, Affinity:5}`. At seed `8524433`, weapon
  type `10`, rarity `7`, and count `32`, this reproduces the captured native
  result `6006007007006` exactly. Do not replace it with unfiltered Excel rows.
- Material recipes can change the native usage limits. v0.2.40 fits the four
  limits in memory from the completed forge using the pinned pre-forge RNG
  state, then uses that recipe pool for validation and route search. This runs
  once per forge and performs no disk I/O or menu polling.
- v0.2.41 also fits filtered subsets and native row order. The captured
  Fire/Thunder/Poison result `8004007007008` cannot be produced by any ordering
  or limits of the complete four-entry pool; it is reproduced by
  `{Element:1, Sharpness:2, Affinity:2}` with Attack absent.
- v0.2.42 shows the fitted recipe pool in the production UI and rejects targets
  containing an unavailable family or more copies than its fitted maximum.
  Gogma identification prompts direct the player to hover over a weapon; an
  initial Reset Skills or amendment is no longer required.
- The production plugin performs no automatic file logging or research dumps.

### Gogma reinforcement rerolls (in progress)

- Native method:
  `app.Em0078_ArtianUtil.lotteryCreateBonus(app.user_data.WeaponData.cData, app.savedata.cEquipWork, System.Boolean)`.
- Current executable address: `0x00000001441123C0`. The method ends at
  `0x0000000144112CD7`; its candidate-pool helper begins at
  `0x0000000144113060`.
- The Boolean distinguishes **Amend (Keep Bonuses)** from
  **Amend (Reset Bonuses)**. They construct different weighted candidate pools
  and therefore produce different deterministic transitions.
- Static disassembly confirms the seed formula:
  `(saveSeed % 100000000 + weaponType * 1000 + attributeForce) XOR 0x00AC9365`.
- It initializes the same four-word xorshift family used elsewhere and warms it
  for 100 iterations. It then advances using a separate Gogma reinforcement
  stream counter read at offset `0xA8`, multiplied by ten. This counter and the
  exact weighted draws are implemented in v0.2.2's Debug validation path and
  have been validated in game. It is not the
  skill counter at `0xF4`; earlier attempts using the displayed skill counter
  could not reproduce reinforcement rolls for this reason.
- Each of the five slots consumes one RNG result modulo that slot's total
  candidate weight. Candidate entries are packed as `(weight << 32) | bonusId`.
  The helper adjusts later-slot weights according to previously selected bonus
  families and the keep/reset mode.
- `getTargetBonusId(...)` returns
  `ValueTuple<List<LotBonusIdInfo>, UInt32>` where each entry has `BonusId` and
  `Probability`. Capture its return value, not an argument, when validating the
  native pool builder.
- Confirmed Reset Bonuses sequence from `4007004008008`:
  `7012011016014`, `7014014015009`, `14014012016017`, `7016009015013`,
  `11015007017010`, `11007014016009`, `16011009007009`.
- Confirmed Keep Bonuses sequence from `4007004008008`:
  `901013017014`, `9011016014017`, `16011013014010`, `13011016017014`,
  `16011009010017`.
- The same Reset sequence appeared while the old captured counter changed from
  165 to 158, further confirming that value was the unrelated skill counter.
- v0.2.2 validation sample for Reset mode (`mode=0`), weapon type 10,
  attribute 9, save seed 8524433, Gogma counter 55:
  `7012016012009 -> 17009010012016`. Predicted runtime IDs were
  `{15, 11, 9, 8, 16}` with weighted rolls `34/1000`, `93/920`, `27/870`,
  `64/820`, and `32/770`; the reconstructed packed value matched exactly.
- v0.2.2 validation sample for Keep mode (`mode=1`) at Gogma counter 56:
  `17009010012016 -> 14013017012009`. Predicted runtime IDs were
  `{8, 11, 16, 12, 13}` with weighted rolls `71/300`, `46/200`, `84/300`,
  `29/250`, and `66/220`; the reconstructed packed value matched exactly.
  The captured pools confirm that Keep mode preserves each slot's bonus family
  and rerolls only among that slot's permitted tiers.
- v0.2.3 local Reset pool simulation was validated again at Gogma counter 57:
  `14013017012009 -> 12010016015013`, with native/predicted IDs
  `{12, 14, 15, 9, 11}` and per-slot totals `1000, 950, 870, 790, 740`.
  The five-slot packed prediction matched the actual result. For the target
  multiset `{Attack EX x2, Attack III, Sharpness/Ammo EX, Affinity EX}`, the
  repeated-Reset search reported distance 2407 and a correctly reordered
  matching result.
- v0.2.4 searches Reset and Keep together. It retains one representative for
  each five-slot bonus-family layout at every depth; exact tiers do not affect
  a later Keep pool, so this deduplication preserves reachable outcomes. Any
  shortest mixed route can be represented as zero or more Resets followed by
  zero or more Keeps because actions before the final Reset do not affect its
  output.
- First v0.2.4 mixed-route sample, starting after Gogma counter 45, targeted
  `{Attack EX x2, Attack III, Sharpness/Ammo EX, Affinity EX}`. The planner
  reported 26 Reset amendments followed by 4 Keep amendments (30 total), with
  predicted packed result corresponding to exactly that multiset. The capture
  that identified the stream was Keep mode and independently validated its
  native/local result as `4007004008008 -> 9011013017014`. The 30-action mixed
  endpoint still needs in-game validation.
- Known Gogma three-digit codes are:
  `007 Sharpness Boost`, `009 Attack II`, `010 Affinity II`,
  `011 Sharpness/Ammo EX`, `012 Element II`, `013 Attack III`,
  `014 Affinity III`, `015 Element EX`, `016 Attack EX`, `017 Affinity EX`.
  Codes are stored in reverse display order.

## Runtime Files

`GogRollPlanner.json` stores only user-facing selections and the enabled state.
Older research capture files may remain under `reframework/data`, but the
production plugin neither reads nor writes them.

v0.2.6 provides an explicit, button-triggered CSV export at
`reframework/data/Gog Roll Planner/GogRollPlannerPredictions.csv`. It writes only the current
step-by-step route predictions and must not be moved into a draw loop or native
getter hook.

v0.2.8 adds persisted per-stage inclusion controls. The combined current-weapon
Gogma optimum is the sum of the shortest skill and reinforcement routes because
the game stores and advances their counters independently. Base forge results
must not be presented as sharing the currently captured Gogma streams; a future
forged weapon has to be upgraded and identified before a true end-to-end route
can be claimed.

v0.2.9 restricts `getArtianSkillType` capture to an active `lotterySkill` call.
The getter also runs when reinforcement menus close; accepting those calls
overwrote the skill route with a displayed weapon value and reinforcement RNG
context.

v0.2.10 fixes the ImGui checkbox compatibility wrapper. Do not use Lua's
`second ~= nil and second or first` idiom for boolean return values because a
valid unchecked `false` falls through to `first`; use an explicit nil check.

v0.2.11 adds a Debug-only, selection-triggered probe on
`app.GUI080301.setCurrentWeapon(app.EquipBoxInfo.WeaponInfo)`. It inspects
`_CurrentWeaponInfo` only when a weapon selection changes and reports up to 30
field names/types plus any nested `app.savedata.cEquipWork`. This probe is for
mapping automatic stream initialization and must remain isolated from the
production route state until its layout is validated.

The first selection capture confirmed `app.EquipBoxInfo.WeaponInfo` contains
`Data: app.user_data.WeaponData.cData` and `_TextureInfo`, but no direct
`cEquipWork`. v0.2.12 extends the bounded probe into WeaponData/EquipSet fields
and lists only Current/Equip/Weapon/Artian fields from the GUI080301 owner to
find the save-box lookup key without polling.

The v0.2.12 capture exposed WeaponData fields `_Index`, `_Type`, `_Rare`, and
`_Attribute`, which should provide the static seed inputs. GUI080301 also owns
`_skillListSelectEquip: app.EquipDef.EquipSet` and `_PartsArtianList`; v0.2.13
reports scalar values and recursively inspects those two context objects for
the matching save-box `cEquipWork`.

v0.2.14 writes that complete Debug-only selection probe once per selection to
`reframework/data/Gog Roll Planner/SelectedWeaponProbe.txt`. Keep high-volume
reflection output in that file rather than rendering it in the overlay.

When `fs.get_game_path` is unavailable, Lua file paths are already relative to
`reframework/data`; do not prefix fallback paths with `reframework/data/` or
the mod will create a duplicated nested directory.

The v0.2.16 selected-weapon hook resolves `WeaponInfo -> WorkInfo -> Work` to
the real `app.savedata.cEquipWork`. Selection now feeds that object through the
validated skill and Gogma input capture, while the expensive text export stays
Debug-only.

On selection, the persisted `gogma_counter` at offset `0xA8` is already the
counter for the next amendment. Assign it directly to `state.gogma_next_counter`;
only the amendment post-hook adds one to the counter captured before that roll.

Static disassembly of `lotterySkill` at `0x144112000` confirms its seed is
`(saveSeed % 100000000 + weaponType * 1000 + getAttributeForce(work)) XOR
0x00AC9365`. The seed call at `0x144112077` is `getAttributeForce`; the later
call to `getBaseBonusByCreateingInt` at `0x14411226F` participates in writing
the resulting skill value, not RNG initialization. Controlled Blast/Dragon
Insect Glaive reload tests also confirm that element changes the skill stream.

The production selection path resolves
`GUI080301.<_PartsArtianList>k__BackingField.<WorkInfo>k__BackingField.<Work>k__BackingField`.
Some screens may expose `WorkInfo` directly on `WeaponInfo`, so that is checked
first. The bounded recursive reflection scan is Debug-only; running it on every
list hover causes visible menu stutter.

Because the direct `WorkInfo` backing-field chain is not populated consistently,
the non-Debug fallback performs a narrow, allocation-light search through only
`WeaponInfo`, `EquipSet`, `PartsArtianList`, and `EquipWork` references. It must
stop at the first `cEquipWork` and must not collect or format reflected fields.
Optional `get_field` probes must be wrapped in `pcall`; REFramework throws when
a managed object does not own the requested backing field instead of returning
`nil`.
The `app.GUI080301` parts-list field is the direct field `_PartsArtianList`, not
the compiler-generated name `<_PartsArtianList>k__BackingField`.

Base forge validation must pin its prediction when `addArtianCreateCount` is
called. A later `getArtianCreateCount` may run before `addEquipBoxArtianWeapon`
and expose the next weapon's count, so validating against a global latest-getter
prediction breaks on consecutive forges.

Skill validation is finalized one frame after `lotterySkill` returns. The
confirmation preview can already display the generated pair while an immediate
`getArtianSkillType` call still observes the previous backing value; preserve
the pre-roll RNG snapshot and defer only the actual-result read.

The skill counter read while merely selecting a weapon points to its next reset,
so that first simulated value is reset 1. A counter captured before an active
`lotterySkill` call produces the roll being validated, so subsequent route
distance starts with the following ten-step result. Keep this distinction in
both route search and CSV export.

## Development Guidance

- Preserve the validated predictors and keep the UI focused on actionable routes.
- Do not reintroduce automatic disk I/O or hot getter hooks. In particular,
  `getGrindingBonus` fires continuously while the equipment UI is visible.
- REFramework's Lua ImGui binding is limited. Follow existing wrappers and avoid
  assuming newer Dear ImGui functions exist.
- Hook arguments are raw ABI values. Confirm runtime layout before conversion.
  Use `sdk.to_managed_object` for managed references, `sdk.to_valuetype` for
  value arguments, and `sdk.get_native_field` only when the raw layout is known.
- Use `thread.get_hook_storage()` to carry values safely from pre-hooks to
  post-hooks.
- `GUI080301.setCurrentWeapon` must carry both `args[2]` and `args[3]` through
  hook storage. Its `_CurrentWeaponInfo` field can lag behind the method
  argument, causing only some highlighted weapons to be identified.
- Wrap research probes with `pcall`; a failed optional hook must not disable the
  validated skill-reroll hook.
- Avoid hooking noisy getters unless they provide unique state. For example,
  `getGrindingBonus` fires continuously while the equipment UI is visible.
- Run `git diff --check` after edits. There is no automated game-runtime test;
  validation requires resetting scripts and performing the corresponding action
  in game.
- Keep temporary reverse-engineering hooks isolated in `debug_state`,
  `install_gogma_reinforcement_probe`, `install_target_bonus_probe`, and
  `draw_debug_research`. They must remain behind the Debug checkbox and should
  be removed after the native predictor is validated.

## Static Analysis

- Game executable:
  `D:\Games\Steam\steamapps\common\MonsterHunterWilds\MonsterHunterWilds.exe`
- Local disassembler:
  `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\14.51.36231\bin\Hostx64\x64\dumpbin.exe`
- Useful options are `/DISASM:BYTES` and `/RANGE:vaMin,vaMax`.
- Generated working dumps in the repository root:
  `lotteryCreateBonus.disasm.txt`, `getTargetPoolHelper.disasm.txt`, and
  `createArtianWeapon.disasm.txt`.
  These are analysis artifacts, not files shipped with the mod.

## Current Next Step

1. Validate v0.2.42's fitted base pool against consecutive homogeneous and
   mixed-material recipes. Predicted must equal actual without consulting the
   unfiltered `ArtianBonusData` rows.
2. Validate v0.2.4's mixed Reset/Keep route against in-game amendments,
   including a route that uses both modes. Targets are compared as multisets,
   including duplicates such as two Attack EX bonuses.
3. Combine base forging, Gogma upgrade, set/group resets, and reinforcement
   amendments into one cost-aware route search.
