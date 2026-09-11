# AFTERFALL

An open-world fantasy action RPG for Roblox.
Chapter 1 — **AFTERFALL: AWAKENING**

> **Current state:** foundation only. There is no gameplay yet.
> This repository sets up the structure that everything else will be built inside.

---

## How this project is put together

The project is split in two, and the split matters:

| | Lives where | Owned by |
|---|---|---|
| **The world** — terrain, models, lighting, the test arena | `AfterFall.rbxl` on your computer | Roblox Studio |
| **The code** — every script in the game | this repository, in `src/` | Git / GitHub |

A tool called **Rojo** connects them. You run Rojo, click Connect in Studio, and
every code file in `src/` appears inside your place automatically. Change a file
and Studio updates within a second.

You never have to copy or paste scripts by hand, and the place file never has to
go into Git — which is important, because `.rbxl` files are binary and Git cannot
merge them.

---

## First-time setup

You only do this once. Roughly 10 minutes.

### 1. Install Rokit

Rokit installs and version-locks the tools this project needs, so you never have
to hunt down the right version of anything.

Download the release for your operating system from
<https://github.com/rojo-rbx/rokit/releases>, unzip it, then run:

```
rokit self-install
```

Close and reopen your terminal afterwards so it can find the new command.

### 2. Install the project's tools

In a terminal, navigate into this folder and run:

```
rokit install
```

This reads `rokit.toml` and installs the exact versions this project uses:

| Tool | What it does |
|---|---|
| **Rojo** 7.5.1 | Syncs code from this folder into Roblox Studio |
| **StyLua** 2.1.0 | Formats code automatically so it always looks consistent |
| **Selene** 0.28.0 | Catches likely bugs before you ever run the game |

The first time, Rokit will ask whether you trust each tool. Answer yes. (To do
it up front instead: `rokit trust rojo-rbx/rojo Kampfkarren/selene JohnnyMorganz/StyLua`.)

### 3. Install the Rojo plugin for Studio

```
rojo plugin install
```

This installs the Rojo button into Studio's **Plugins** tab. Restart Studio if
it is already open.

### 4. Set up Selene's Roblox knowledge

```
selene generate-roblox-std
```

This downloads Roblox's current API list so Selene knows what `workspace`,
`game` and friends are. It creates `roblox.yml` — **commit that file**, so
nobody else has to run this step.

### 5. Create the place file

1. Open Roblox Studio and create a new **Baseplate**.
2. **File → Save to File As…**
3. Save it into this folder, named exactly **`AfterFall.rbxl`**.

`.gitignore` already excludes it, so it will not be committed. That is intended —
the place file is yours, the code is shared.

---

## Daily workflow

**1. Start Rojo.** In a terminal, in this folder:

```
rojo serve
```

Leave this running while you work. It prints a green "Server listening" line.

**2. Connect Studio.** Open `AfterFall.rbxl`, go to the **Plugins** tab, click
**Rojo → Connect**.

You should now see, in the Explorer panel:

```
ReplicatedStorage
  └── Shared          ← types, constants, and all game content definitions
ServerScriptService
  └── Server          ← everything the server decides
StarterPlayer
  └── StarterPlayerScripts
        └── Client    ← input, camera, UI, effects
```

**3. Press Play.** Open the **Output** window (View → Output). You should see
exactly these two lines:

```
[AFTERFALL] Server online — AFTERFALL: AWAKENING | save format v1 | 0 service(s) started
[AFTERFALL] Client online — AFTERFALL: AWAKENING | 0 controller(s) started
```

**If you see both lines, the foundation is working.** Zero services and zero
controllers is correct right now — there is no gameplay built yet.

### If something goes wrong

| What you see | What it means |
|---|---|
| Neither line appears | Rojo is not connected. Check the terminal is still running `rojo serve`, then reconnect in Studio. |
| `Server/Services folder is missing` | Rojo connected but did not sync fully. Disconnect and reconnect. |
| Studio shows no `Shared` folder | You opened a different place file, or Rojo was started in the wrong folder. |

---

## Checking your work

Before committing, from this folder:

```
stylua src/      # reformat everything to the house style
selene src/      # look for likely bugs
./tests/run.sh   # run the test suite
```

### The test suite

`tests/` runs **outside Roblox** using the Luau command-line tool, so it can
execute thousands of simulated combat frames in under a second on any machine.

It needs the `luau` binary from
<https://github.com/luau-lang/luau/releases> (not installed by `rokit install`,
because that release ships several binaries in one archive). Put it on your
PATH, or point at it directly:

```
LUAU=/path/to/luau ./tests/run.sh
```

What it currently proves:

- **`FrameClock.test.luau`** — that a 30fps phone and a 144fps PC run the
  identical number of combat frames per second, that a one-second stall drops
  time instead of spiralling, and that timing stays exact over five minutes of
  play.
- **`Config.test.luau`** — that every damage, poise, stamina and frame value
  matches the design table, and that the key balance relationships hold (a full
  chain staggers the wolf, three hits do not, the wolf's drop is a visible
  upgrade).

That second file matters more than it looks. A mistyped config value in a
data-driven game does not crash anything — the game just quietly plays wrong,
and everyone spends a week arguing about feel. These checks turn that into a
failing test.

---

## Repository layout

```
src/
├── shared/            → ReplicatedStorage.Shared   (both sides can read this)
│   ├── Constants/       Values several systems must agree on
│   ├── Types/           Shared data shapes, including the save schema
│   ├── Util/            FrameClock — the fixed 60Hz timestep
│   ├── Net/             Every client↔server message, declared in one place
│   └── Config/          ALL TUNING LIVES HERE
│         StatConfig     health, stamina, attributes, crit, the damage formula
│         CombatConfig   timing, hitstop, poise, block, spawn protection
│         WeaponConfig   weapons and the eight weapon types
│         MoveConfig     frame data — startup/active/recovery per move
│         EnemyConfig    the wolf's numbers
│
├── server/            → ServerScriptService.Server  (authoritative)
│   ├── init.server.luau   Startup order lives here
│   ├── Services/          PlayerService, DataService, CombatService, …
│   └── Modules/           Internal helpers
│
└── client/            → StarterPlayerScripts.Client (presentation only)
    ├── init.client.luau   Startup order lives here
    ├── Controllers/       Input, Camera, Combat, UI, …
    └── Modules/           Internal helpers
```

The rules this structure enforces, and why, are in
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## What comes next

Phase A (data, timing, networking) is done. Next is Phase B: player stats,
movement, stamina and spawn protection.

See `docs/ARCHITECTURE.md` for the rules the code is held to and the full
phase roadmap.
