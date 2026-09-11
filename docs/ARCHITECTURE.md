# AFTERFALL — Architecture

This document is the contract the codebase is held to. When a future change
conflicts with something written here, the change needs a stated reason, not a
quiet exception.

---

## 1. The server decides. The client presents.

The server is the only source of truth for anything that matters:

> damage · HP · XP · Gold · inventory · equipment · item ownership · mastery ·
> quests · bosses · enemy AI · trading · guild progression · world events

The client owns input, camera, UI, animation, VFX, sound and targeting
*presentation*.

**A player's Roblox client can be modified by that player.** Anything it is
trusted with, it will eventually lie about. So the client never reports an
outcome — it only ever makes a request:

```
Client:  "I pressed attack with the Longsword, first swing."
Server:  Do they exist? Alive? Is that weapon equipped? Does that attack exist?
         Does their current state allow it? Off cooldown? Enough stamina?
         Is the target real, and in range? Is the timing plausible?
         → only then does damage happen.
```

The client may *predict* presentation — play the swing animation the instant the
button is pressed, so the game feels responsive — but the server's answer is
what actually happened. If they disagree, the server wins.

## 2. Content is data, not code

This is the single most important decision in the project.

A weapon is a **data file**. So is an attack, an enemy, an item, an ability:

```
src/shared/Definitions/Weapons/Longsword.luau
src/shared/Definitions/Attacks/LS_M1_1.luau
src/shared/Definitions/Enemies/Wolf.luau
```

The combat engine reads those files. It does not contain a single line that
mentions "Longsword" specifically.

**Adding the Greatsword should mean adding files, not editing the engine.**

A codebase with a hand-written script per weapon works fine for three weapons
and collapses at thirty — every balance pass becomes thirty edits, and every
engine improvement has to be re-applied thirty times. Data-driven content is
what makes years of expansion possible.

## 3. One job per module

- Combat does not save player data.
- Inventory does not control enemy AI.
- Quests do not calculate sword hitboxes.

If a module's description needs the word "and", it is probably two modules.

## 4. Dependencies flow one way

Startup order is written down explicitly in `src/server/init.server.luau` and
`src/client/init.client.luau`. **A service may only depend on services listed
above it.**

Loading happens in two passes:

| Pass | What it may do |
|---|---|
| `Init` | Set up its own internal state. Must not use other services. |
| `Start` | Everything exists now, so it is safe to use other services. |

This is what makes it impossible to accidentally create a loop where A needs B,
B needs C, and C needs A — a failure mode that produces startup errors which are
extremely hard to trace back to their cause.

## 5. One door between client and server

**Every** RemoteEvent and RemoteFunction is declared in `src/shared/Net/`.
Nowhere else in the project may create one.

The reason is security. Remotes scattered through a project are how Roblox games
get exploited, because no one can hold the full list in their head. One file
means the entire attack surface fits on one screen and can be reviewed.

## 6. Extend before you build

Before writing a new module: search the repository, find what already exists,
and decide whether it can be extended. Two systems doing almost the same thing
is worse than one system doing it slightly awkwardly.

## 7. Player data is versioned from day one

`Constants.DATA_VERSION` starts at `1` and increases by one whenever the shape of
saved data changes. `DataService` migrates old saves forward — it never
discards them.

Two rules that are never bent:

- **A failed load is not a new player.** If a DataStore read fails, the player
  is not given a fresh empty save. That is how real progress gets erased.
- **DataStore failures are never ignored silently.** They are retried, and if
  they still fail, they are reported.

## 8. Performance is a design constraint, not a later cleanup

Target is ~12 players, hard ceiling 15 — but with NPCs, monsters, dungeons,
bosses and world events running alongside them.

Prefer event-driven logic over per-frame work. AI detail scales down with
distance from players: full simulation nearby, reduced at range, abstract
world-state far away. Exact distances and tick rates get **benchmarked**, not
guessed.

Do not optimise prematurely. Do not build something obviously wasteful either.

## 9. Style

Typed Luau (`--!strict`) wherever practical; avoid `any` unless genuinely
necessary. Small focused modules. Clear names. Comments explain **why**, not
what. Validate inputs defensively — especially anything that arrived from a
client.

`stylua src/` handles formatting. `selene src/` catches likely bugs. Both are
configured in this repo; neither is optional.

---

## Roadmap

The first playable milestone, in order:

```
spawn → move → sprint → find dummy → attack → heavy → dodge → block
→ perfect guard → parry → lock-on → fight Wolf → defeat Wolf
→ gain XP → receive loot → equip loot → see stat change
```

| # | Step | State |
|---|---|---|
| 1 | Toolchain, Rojo project, folder structure, bootstraps | **done** |
| 2 | Setup verified in Studio by the creative director | *next* |
| 3 | `Net` remote registry + first client↔server round trip | |
| 4 | `PlayerService` + `DataService` (versioned saves) | |
| 5 | Movement + stamina (walk, sprint, jump) | |
| 6 | Combat state machine + first attack + raycast hitboxes | |
| 7 | Training Dummy (damage, hit reaction, stagger, death, reset) | |
| 8 | Full Longsword M1 chain + Heavy, as data files | |
| 9 | Dodge, Block, Perfect Guard, Parry | |
| 10 | Wolf AI → XP → loot → equip → visible stat change | |

Step 4 comes before combat deliberately. Retrofitting a save system into a game
that already has progression is one of the most expensive mistakes a project can
make; building it early costs almost nothing.

Lock-on lands between 9 and 10, depending on how the Wolf fight plays.
