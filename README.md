# Gogma Artian Roll Planner

Gogma Artian Roll Planner is a REFramework Lua mod and standalone web
calculator for Monster Hunter Wilds. It reads the game's predetermined Artian
weapon streams and calculates how many forges, skill resets, or Gogma
amendments are needed to reach a selected result.

The mod does not change RNG, create equipment, or edit your save. It observes
the same state the game uses and calculates a route from it.

## How Artian Weapons Work

Artian weapons are not rolled one visible upgrade at a time. The game uses
saved RNG streams and consumes them when specific smithy actions happen:

1. **Base reinforcements are decided when the weapon is forged.** The weapon
   starts at 0/5, but its five reinforcement bonuses are already stored.
   Reinforcing the weapon reveals and applies that stored sequence.
2. **The material recipe controls the possible base bonus families.** The parts
   determine weapon type, element or status, production bonuses, and which
   reinforcement families can appear.
3. **The base forge stream is shared by weapon type and rarity.** Forging any
   weapon with the same weapon type and rarity consumes the next base result,
   even if the element or infusions are different.
4. **Gogma set/group skills use a separate stream.** The sequence depends on
   weapon type and elemental attribute. Upgrading a completed weapon to Gogma
   consumes the next skill result, and **Reset Skills** advances that stream.
5. **Gogma reinforcement amendments use another separate stream.** **Reset
   Bonuses** replaces all five bonuses. **Keep Bonuses** keeps each slot's
   bonus family and rerolls its permitted tier.

Reloading an earlier save restores the earlier stream positions. Actions on one
stream do not advance the others.

## What The Mod Does

- Calculates a full route from the current save counters and selected target.
- Predicts base Artian reinforcement results without requiring a test forge.
- Handles Gogma set/group skill resets.
- Searches mixed **Amend (Reset Bonuses)** and **Amend (Keep Bonuses)** routes
  for Gogma reinforcement targets.
- Estimates Artian parts, reinforcement points, Gogma material points, Tarred
  Devices, and zenny for the calculated route.
- Exports route predictions to CSV.
- Exports web calculator values for use outside the game.

## Installation

Copy the repository's `reframework` folder into the Monster Hunter Wilds game
directory. The resulting script path should be:

```text
<Monster Hunter Wilds>/reframework/autorun/GARP.lua
```

If the game and REFramework are already running, open the REFramework menu with
`Insert` and select **Reset scripts**.

The mod appears under **Script Generated UI > Gogma Artian Roll Planner**.

## Usage

Use **Full weapon plan** to choose the final weapon recipe, desired
reinforcements, and desired Gogma set/group skills. Press **Calculate full
plan** after changing the target.

Targets made only from base-tier bonuses may finish as base Artian weapons.
Selecting Gogma-tier bonuses makes the route continue through the Gogma upgrade
and amendment steps. Base-tier and Gogma-tier reinforcement bonuses cannot be
mixed in the same target.

The calculated route is a fixed snapshot of the save counters at calculation
time. Press **Calculate full plan** again after changing targets or after
intentionally advancing/reloading the save.

## Web Calculator

The repository root contains a standalone calculator that can be opened directly
in a browser or hosted with GitHub Pages:

```text
index.html
```

In the mod, press **Calculate full plan**, then use **Export web calculator
values** in the **Export** section. Import the generated JSON file on the web
page by selecting it, dragging it onto the import box, pasting the file, or
pasting its JSON text.

The mod writes:

```text
<Monster Hunter Wilds>/reframework/data/Gogma Artian Roll Planner/GogmaWebCalculatorValues.json
```

## Export

Use **Export predictions to CSV** to write the calculated route as a CSV table:

```text
<Monster Hunter Wilds>/reframework/data/Gogma Artian Roll Planner/GogmaArtianRollPlannerPredictions.csv
```

The CSV can be opened in spreadsheet tools such as Google Sheets, Excel, or
LibreOffice Calc.

## Notes

- Predictions depend on the current save state.
- Forging or rerolling the relevant weapon stream advances it.
- The mod cannot refund materials or undo an action. Save and reload normally
  when testing a route.
- A game update can change native methods or field layouts and may require a
  mod update.
- Settings are stored in:

```text
<Monster Hunter Wilds>/reframework/data/GogmaArtianRollPlanner.json
```
