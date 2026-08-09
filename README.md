# Gogma Artian Roll Planner

Gogma Artian Roll Planner is a REFramework Lua mod for Monster Hunter Wilds. It reads the
game's predetermined Artian weapon streams and tells you how many skill resets
or weapon forges are needed to reach a selected result.

The mod does not change RNG, create equipment, or edit your save. It observes
the same state the game uses and calculates the route from it.

## How Artian Weapons Work

In-game, Artian weapons are not rolled one visible upgrade at a time. The game
uses saved RNG streams and consumes them when specific smithy actions happen:

1. **Choose Artian parts and forge the base weapon.** The parts determine the
   weapon type, element or status, and production bonuses shown on the weapon.
2. **The five base reinforcement bonuses are decided at forge time.** They are
   already stored on the new weapon even though the weapon starts at level 0/5.
   Reinforcing it reveals and applies those five stored bonuses; it does not
   make a fresh random roll at every level.
3. **The part recipe controls what base bonuses are possible.** Each part has
   an element/status and either Attack or Affinity Infusion. Two matching
   attributes determine the forged weapon's attribute; three matching
   attributes also grant Element Infusion. Those material choices change which
   bonus families can appear on the forged weapon.
4. **Forging advances a predetermined base reinforcement stream.** The stream
   is tied to the save state, weapon type, and rarity. Forging any weapon with
   the same weapon type and rarity consumes the next result from that stream,
   even if the element or infusions are different. Reloading an earlier save
   restores the earlier stream position.
5. **Upgrade the completed base weapon into a Gogma Artian weapon.** Base
   Attack Boost I, Affinity Boost I, and Element Boost I become their
   corresponding Gogma level-I bonuses. Sharpness Boost keeps the same name.
6. **Gogma set/group skills use their own stream.** The sequence depends on the
   weapon type and elemental attribute. **Reset Skills** advances this stream.
   Upgrading another completed weapon to Gogma also advances it once; merely
   forging a base Artian weapon does not.
7. **Gogma reinforcement amendments use another independent stream.**
   **Reset Bonuses** replaces all five bonuses from the full eligible pool.
   **Keep Bonuses** preserves each slot's bonus family and rerolls its permitted
   tier.

The base forge stream, Gogma skill stream, and Gogma reinforcement amendment
stream are separate. Spending actions on one stream does not advance the
others.

Forging any weapon of the same weapon type and rarity advances the shared base
forge stream. The disposable weapons do not need the same element or infusion
parts. Only the final weapon must use the intended recipe. For example, an Ice
Insect Glaive made from three Attack Infusion parts can be reached by forging
cheaper rarity-8 Insect Glaives first, then using the Ice/Attack parts only for
the target forge.

## What Works

- Predicting Gogma Artian set and group skill resets.
- Selecting a desired Gogma set skill and group skill.
- Showing the exact number of **Reset Skills** actions needed.
- Predicting the five base Artian reinforcement bonuses assigned when a weapon
  is forged.
- Selecting one exact five-bonus reinforcement target. Base-tier targets may
  finish as base Artian weapons; advanced targets continue through Gogma.
- Showing how many weapons of the same weapon type and rarity must be forged to
  reach a base-tier target or the best starting point for a Gogma target.
- Searching mixed **Amend (Reset Bonuses)** and **Amend (Keep Bonuses)** paths
  for an exact five-bonus Gogma reinforcement target.
- Exporting the current predictions as a CSV table for Google Sheets.
- Including or excluding each prediction stage from the combined plan and CSV.
- Treating base Artian Attack, Affinity, and Element bonuses as level I when the
  weapon is upgraded to a Gogma Artian weapon.
- Taking a fixed from-scratch planning snapshot that compares disposable
  advance-forges with the final target forge, skill resets, and Gogma
  amendments.
- Reading the saved base-forge counter directly from the save manager.
  Calculating a plan does not consume parts or require a test forge.
- Estimating Artian parts, reinforcement points, Gogma material points, Tarred
  Devices, and zenny for the calculated route.

## Choose Targets

Use the **Full weapon plan** section to choose the final recipe, desired
reinforcements, and desired Gogma set/group skills. Press **Calculate full
plan** after changing any target.

Targets made only from **Attack Boost I**, **Affinity Boost I**, **Element
Boost I**, and **Sharpness Boost** may finish as base Artian weapons. Selecting
any II, III, EX, or **Sharpness/Ammo Boost EX** bonus makes it a Gogma target;
the planner then chooses the best base result as a starting point. Base I
bonuses cannot be mixed with Gogma II/III/EX bonuses in one target. Sharpness
Boost is shared by both stages.

The planner searches both amendment modes together and displays the shortest
reachable route. A mixed result is shown as a number of **Reset Bonuses**
amendments followed by a number of **Keep Bonuses** amendments. This order is
intentional: only the last Reset matters because it replaces all five bonuses.

## Requirements

- Monster Hunter Wilds on Windows.
- [REFramework](https://github.com/praydog/REFramework) installed for the game.

## Installation

Copy the repository's `reframework` folder into the Monster Hunter Wilds game
directory. The resulting script path should be:

```text
<Monster Hunter Wilds>/reframework/autorun/GARP.lua
```

If the game and REFramework are already running, open the REFramework menu with
`Insert` and select **Reset scripts**.

The mod appears under **Script Generated UI > Gogma Artian Roll Planner**.

## Web Calculator

The repository root contains a standalone calculator that can be opened directly
in a browser or hosted with GitHub Pages:

```text
index.html
```

In the mod, press **Calculate full plan**, then use **Export web calculator
values** in the **Export** section. The mod writes:

```text
<Monster Hunter Wilds>/reframework/data/Gogma Artian Roll Planner/GogmaWebCalculatorValues.json
```

Import that file on the web page by selecting it, dragging it onto the import
box, pasting the file, or pasting its JSON text. The web calculator then reuses
the same seed, counters, recipe, and targets outside the game.

## Base Artian Results

Base Artian weapons receive their complete five-bonus sequence when they are
forged. Reinforcing the weapon reveals and applies that existing sequence; it
does not generate one new random bonus at each level.

1. Under **Full weapon plan**, select the weapon type and the element/status and
   infusion on each of its three final materials. The selectors use that
   weapon's required Blade, Tube, Disc, and Device combination.
2. Under **Desired reinforcements**, select only base-tier values for **Bonus
   1** through **Bonus 5**, then press **Calculate full plan**.

The mod reads the current stream position directly and reports how many weapons
of that type and rarity must be forged. For example:

```text
Route: forge 3 more weapon(s), then keep the last one
```

Press **Calculate full plan** after changing any reinforcement target.

Element does not select a separate base reinforcement counter. The counter is
keyed by weapon type and rarity, so forging another element of the same weapon
type advances the same sequence. The mod uses the game's base bonus pool
and removes Sharpness after it has been selected twice while generating the
five bonuses. Material combinations can change the available bonus families;
the mod derives that pool without consuming a weapon.

If the selected target asks for an excluded family or more copies than the
recipe permits, the UI reports **Impossible for this recipe** instead of
searching thousands of unreachable forge results.

## Plan A Complete Weapon

1. Under **Full weapon plan**, choose the final weapon type and all three final
   materials. The planner derives the forged attribute and bonus availability.
2. Select which stages to include and choose the desired reinforcements and
   Gogma set/group skills. The reinforcement target itself determines whether
   the weapon may stop at base Artian or must continue to Gogma.
3. Press **Calculate full plan**. No weapon needs to be forged first.

The calculation takes a fixed snapshot of the saved counters. It may tell you
to forge disposable weapons first. Those advance-forges only need to match the
target's weapon type and rarity; they may use any valid parts. The last forge
uses the selected final materials. The plan then lists reinforcement, the Gogma
upgrade, paid skill resets, and Reset/Keep amendment steps. The listed
**Reset Skills** count starts after the free skill assignment performed by the
Gogma upgrade itself.

Disposable base weapons advance the base reinforcement stream as soon as they
are forged. The full plan uses them when they reduce the combined base/Gogma
reinforcement route. For skills, the planner only shows **Reset Skills** because
upgrading disposable weapons advances the same stream by the same amount while
costing substantially more materials.

If the plan starts directly with the target forge, that means the current base
stream already gives the best combined route. It does not mean disposable
forges were omitted from the search.

When the selected target contains a Gogma-tier bonus, the selected base Artian
bonuses are not a separate requirement. The planner considers every base result
allowed by the final recipe and chooses the one that reaches the requested
Gogma bonuses with the fewest total forges and amendments. A target containing
only base-tier bonuses instead ends after the base weapon is reinforced to 5/5,
unless the Gogma skill stage is also included.

The forge and reinforcement snapshot stays unchanged while browsing the smithy
list. Press **Calculate full plan** again only when you intentionally want to
start from the current save counters or after changing the targets. Runtime
validation after the upgrade does not rewrite that snapshot.

The mod reads the currently loaded character's saved creation counter directly
when a plan is calculated. This matters after reloading a save because the
game replaces its live save-data objects.

## Saving Settings

The mod stores its enabled state and selected targets in:

```text
<Monster Hunter Wilds>/reframework/data/GogmaArtianRollPlanner.json
```

This file is managed automatically. It is not necessary to edit it manually.
Removing it resets the mod's selections to their defaults.

## Material Costs

The full weapon plan includes a cost estimate based on the actions in its saved
route:

- Each rarity-8 forge uses 3 Artian parts and 10,000z.
- Reinforcing the kept base weapon through all five levels uses 15,000 base
  reinforcement points and 10,000z in total.
- Upgrading the completed weapon to Gogma uses 3 Tarred Devices and 30,000z.
- Each **Reset Skills** action uses 1,500 Gogma material points and 9,000z.
- Each **Amend** action uses 6,000 Gogma material points and 5,000z.

Base reinforcement ores are worth 20 points for Drearisite, 100 for Specklite,
200 for Argecite, and 300 for Oricalcite. The overlay shows how many of each ore
would be needed if only that ore were used. You can mix ores freely.

Gogma materials with a focus matching the weapon contribute twice their listed
points. Because the best mixture depends on the materials in the player's box,
the planner reports the required point total instead of pretending there is one
exact item count. If the upgraded weapon's skill stream has not been identified,
the estimate is marked partial and does not yet include skill-reset costs.

## Export To Google Sheets

Use **Include reinforcements in plan** and **Include set/group skills in plan**
to choose which stages appear in the combined plan and exported table. When
both Gogma stages are selected, their validated shortest routes are combined.
Their RNG counters are independent, so interleaving the actions cannot reduce
the minimum total.

Press **Export predictions to CSV** after identifying and calculating the
streams you want to include. The mod writes:

```text
<Monster Hunter Wilds>/reframework/data/Gogma Artian Roll Planner/GogmaArtianRollPlannerPredictions.csv
```

In Google Sheets, use **File > Import > Upload** and select that CSV file. The
table contains one row for every predicted forge, skill reset, and Gogma
amendment, plus a full-plan totals row. Each row shows its step within that
stage, the action to perform, its predicted result, the selected target, and
the points, zenny, parts, or Tarred Devices consumed. Exporting happens only
when the button is pressed; the mod does not write this file while navigating
game menus.

Set/group skill streams depend on weapon type and elemental attribute. Weapons
of the same type but different elements can therefore have different skill
sequences.

## Important Notes

- Predictions depend on the current save state. Reloading a save restores the
  streams stored in that save.
- Forging or rerolling the relevant weapon stream advances it.
- The mod cannot refund materials or undo an action. Save and reload normally
  when testing a route.
- A game update can change native methods or field layouts and may require a mod
  update.

## Development

The active source is:

```text
reframework/autorun/GARP.lua
```

Validated algorithms and current reverse-engineering notes are maintained in
`AGENTS.md`. Temporary disassembly files in the repository root are development
artifacts and are not part of the installed mod.

There are no automated in-game tests. After changing the script, run
`git diff --check`, deploy it to the game directory, reset REFramework scripts,
and validate the affected action in the smithy.
