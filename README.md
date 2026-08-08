# Gog Roll Planner

Gog Roll Planner is a REFramework Lua mod for Monster Hunter Wilds. It reads the
game's predetermined Artian weapon streams and tells you how many skill resets
or weapon forges are needed to reach a selected result.

The mod does not change RNG, create equipment, or edit your save. It observes
the same state the game uses and calculates the route from it.

## What Works

- Predicting Gogma Artian set and group skill resets.
- Selecting a desired set skill and group skill in game.
- Showing the exact number of **Reset Skills** actions needed.
- Predicting the five base Artian reinforcement bonuses assigned when a weapon
  is forged.
- Selecting an exact five-bonus base Artian target.
- Showing how many weapons of the same weapon type and rarity must be forged to
  reach that target.
- Searching mixed **Amend (Reset Bonuses)** and **Amend (Keep Bonuses)** paths
  for an exact five-bonus Gogma reinforcement target.
- Exporting the current predictions as a CSV table for Google Sheets.
- Including or excluding each prediction stage from the combined plan and CSV.
- Treating base Artian Attack, Affinity, and Element bonuses as level I when the
  weapon is upgraded to a Gogma Artian weapon.

## Still In Development

- Calculating one optimal route from forging a base Artian weapon through its
  final Gogma set skill, group skill, and reinforcement bonuses.
- Comparing material and forging costs when several valid routes exist.

The Debug panel contains temporary Gogma reinforcement research and RNG
validation information. It is not required for the working skill or base
reinforcement predictions.

## Predict Gogma Reinforcements

1. Select the five desired values under **Gogma reinforcements**. Their order
   does not matter; the planner compares the complete set of five bonuses.
2. Perform one amendment on the selected Gogma Artian weapon to identify its
   current reinforcement stream.
3. Press **Recalculate** after changing the target.

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
<Monster Hunter Wilds>/reframework/autorun/GogRollPlanner.lua
```

If the game and REFramework are already running, open the REFramework menu with
`Insert` and select **Reset scripts**.

The mod appears under **Script Generated UI > Gog Roll Planner**.

## Predict Set And Group Skills

1. Open **Gog Roll Planner** in the REFramework menu.
2. Enable the mod.
3. Select the desired **Set skill** and **Group skill**.
4. Open the smithy's **Reset Skills** screen for the Gogma Artian weapon.
5. Reset its skills once.

That first reset identifies the selected weapon's predetermined stream. The mod
then displays its current skills and a route such as:

```text
Route: reset skills 12 time(s)
```

The count is the number of additional resets required from the current result.
If you change either target, press **Recalculate**. You do not need to perform
another reset unless you select a different weapon or reload an earlier save.

## Predict Base Artian Reinforcements

Base Artian weapons receive their complete five-bonus sequence when they are
forged. Reinforcing the weapon reveals and applies that existing sequence; it
does not generate one new random bonus at each level.

1. Select the desired values for **Bonus 1** through **Bonus 5**.
2. Forge one weapon of the weapon type and rarity you want to search.
3. Return to the mod panel.

The first forge identifies that weapon stream. The mod then reports how many
additional weapons of the same type and rarity must be forged. For example:

```text
Route: forge 3 more weapon(s), then keep the last one
```

Press **Recalculate** after changing any reinforcement target.

Element does not select a separate base reinforcement stream. The stream is
keyed by weapon type and rarity, so forging another element of the same weapon
type advances the same sequence.

## Saving Settings

The mod stores its enabled state and selected targets in:

```text
<Monster Hunter Wilds>/reframework/data/GogRollPlanner.json
```

This file is managed automatically. It is not necessary to edit it manually.
Removing it resets the mod's selections to their defaults.

## Export To Google Sheets

Use each section's **Include in plan** checkbox to choose which stages appear
in the combined plan and exported table. When both Gogma stages are selected,
their validated shortest routes are combined. Their RNG counters are
independent, so interleaving the actions cannot reduce the minimum total.

Press **Export predictions to CSV** after identifying and calculating the
streams you want to include. The mod writes:

```text
<Monster Hunter Wilds>/reframework/data/Gog Roll Planner/GogRollPlannerPredictions.csv
```

In Google Sheets, use **File > Import > Upload** and select that CSV file. The
table contains one row for every predicted forge, skill reset, and Gogma
amendment. Each row shows its step within that stage, the action to perform,
that individual action's predicted result, and the selected target. The three
stages describe their currently identified streams independently; the row
number is not yet a combined from-scratch execution order. Exporting happens
only when the button is pressed; the mod does not write this file while
navigating game menus.

When Base Artian and Gogma stages are selected together, the displayed Gogma
steps still belong to the currently identified Gogma weapon. Forge the chosen
base weapon and identify its Gogma streams before treating all three sections
as one end-to-end route.

## Debug Mode

Enable **Debug** only when collecting information for development. It shows the
captured native values and Gogma reinforcement candidate pools. Selecting a
weapon writes the complete selection probe to:

```text
<Monster Hunter Wilds>/reframework/data/Gog Roll Planner/SelectedWeaponProbe.txt
```

The file is replaced once per weapon selection so the long object details do
not need to fit in the REFramework overlay.

Selecting an Artian weapon also reads its current save-box work record and
identifies its set/group skill and Gogma reinforcement streams without spending
materials on an initial reset or amendment. This identification works with
Debug disabled; only the text probe export requires Debug.

Set/group skill streams depend on weapon type and elemental attribute. Weapons
of the same type but different elements can therefore have different skill
sequences.

Debug mode does not continuously write capture files. Earlier development
versions produced several text dumps under `reframework/data`; the current mod
does not use them and they may be removed.

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
reframework/autorun/GogRollPlanner.lua
```

Validated algorithms and current reverse-engineering notes are maintained in
`AGENTS.md`. Temporary disassembly files in the repository root are development
artifacts and are not part of the installed mod.

There are no automated in-game tests. After changing the script, run
`git diff --check`, deploy it to the game directory, reset REFramework scripts,
and validate the affected action in the smithy.
