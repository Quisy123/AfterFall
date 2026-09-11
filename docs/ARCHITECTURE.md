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

## 2. Combat runs on a fixed 60Hz timestep

Nothing in combat ever reads delta-time. `Shared/Util/FrameClock` collects real
elapsed time in an accumulator and releases it one fixed 1/60th-second frame at
a time, so a 9-frame startup is 9 frames on a 30fps phone and a 144fps PC
alike.

Proven, not asserted: `tests/FrameClock.test.luau` simulates both devices and
checks they produce identical frame counts.

Catch-up after a stall is capped. Past the cap, time is **dropped** rather than
queued — otherwise a hitch makes the next frame more expensive, which makes the
hitch worse, which is the spiral of death.

Hitstop participates in this timeline: it is implemented as *not advancing* an
entity's move clock for N frames, never as a client-side visual pause. If the
client froze and the server did not, every timing after the hit would disagree.

## 3. Content is data, not code

This is the single most important decision in the project.

A weapon is **data**. So is an attack, an enemy, an item, an ability. All of it
lives in `src/shared/Config/`:

```
StatConfig     health, stamina, attributes, crit, the damage formula
CombatConfig   timing, hitstop, poise, block, spawn protection, lag compensation
WeaponConfig   weapons and the eight weapon types
MoveConfig     frame data — startup / active / recovery for every move
EnemyConfig    enemy stats, attacks and AI tuning
```

The combat engine reads those files. It does not contain a single line that
mentions "Longsword" specifically.

**One home, not two.** An earlier `Definitions/` tree was removed rather than
left empty beside `Config/`. Two plausible homes for the same kind of data is
how a codebase ends up with a weapon defined in one place and its attacks in
another. If per-item files are ever worth splitting out, that is a deliberate
move made when there is enough content to justify it — not a second folder
sitting empty waiting to cause ambiguity.

**Adding the Greatsword should mean adding files, not editing the engine.**

A codebase with a hand-written script per weapon works fine for three weapons
and collapses at thirty — every balance pass becomes thirty edits, and every
engine improvement has to be re-applied thirty times. Data-driven content is
what makes years of expansion possible.

## 4. One job per module

- Combat does not save player data.
- Inventory does not control enemy AI.
- Quests do not calculate sword hitboxes.

If a module's description needs the word "and", it is probably two modules.

## 5. Dependencies flow one way

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

## 6. One door between client and server

**Every** RemoteEvent and RemoteFunction is declared in `src/shared/Net/`.
Nowhere else in the project may create one.

The reason is security. Remotes scattered through a project are how Roblox games
get exploited, because no one can hold the full list in their head. One file
means the entire attack surface fits on one screen and can be reviewed.

## 7. No premature abstraction — a standing rule

**There is no `BaseEnemy` class, no `EnemyController`, and no shared AI state
machine. There will not be one until a second enemy exists.**

The wolf is one hand-written file with its own state machine and its own
timers. When a second enemy is built, it too is hand-written. Only then, with
two real implementations to compare, does whatever genuinely repeats get
extracted.

This rule exists because violating it *feels like good engineering*. Writing
the framework first looks responsible and reads well in review. It is still
wrong here, for a specific reason: a shared state machine pushes every enemy
toward a common rhythm, and combat averaged toward a common shape is how a
game ends up full of damage sponges without anyone ever deciding to make one.

The cost of writing the second enemy by hand is a few hours. The cost of an
abstraction built before anyone knew what varied is every enemy after it.

**If you are an agent reading this file and about to create a base class for
something that exists once: don't.**

## 8. Extend before you build

Before writing a new module: search the repository, find what already exists,
and decide whether it can be extended. Two systems doing almost the same thing
is worse than one system doing it slightly awkwardly.

## 9. Player data is versioned from day one

`Constants.DATA_VERSION` starts at `1` and increases by one whenever the shape of
saved data changes. `DataService` migrates old saves forward — it never
discards them.

Two rules that are never bent:

- **A failed load is not a new player.** If a DataStore read fails, the player
  is not given a fresh empty save. That is how real progress gets erased.
- **DataStore failures are never ignored silently.** They are retried, and if
  they still fail, they are reported.

## 10. Performance is a design constraint, not a later cleanup

Target is ~12 players, hard ceiling 15 — but with NPCs, monsters, dungeons,
bosses and world events running alongside them.

Prefer event-driven logic over per-frame work. AI detail scales down with
distance from players: full simulation nearby, reduced at range, abstract
world-state far away. Exact distances and tick rates get **benchmarked**, not
guessed.

Do not optimise prematurely. Do not build something obviously wasteful either.

## 11. Style

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
| — | Toolchain, Rojo project, folder structure, bootstraps | **done** |
| **A** | FrameClock, Net, configs, save schema, types | **done** |
| B | Player stats, movement, sprint, stamina, spawn protection | |
| C | Combat state machine, Longsword moves, hitboxes, damage, poise | |
| D | The wolf — hand-built, no abstraction | |
| E | XP, loot drop, equip, visible stat change | |
| F | VFX tiers, trail, hitstop, screen shake, HUD | |

The save schema is designed in Phase A and written in Phase B, before combat.
Retrofitting a save system into a game that already has progression is one of
the most expensive mistakes a project can make; doing it early costs almost
nothing.
