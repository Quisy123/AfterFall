--!strict
--[[
	FrameClock tests

	Runs OUTSIDE Roblox, via the Luau CLI:

		luau tests/FrameClock.test.luau

	The whole point of the fixed timestep is that combat timing is identical on
	every device. That claim is worth proving rather than asserting, so these
	tests simulate hardware the CI machine does not have: a 30fps phone, a
	144fps PC, a device with wildly irregular frame pacing, and one that stalls
	for a full second.
]]

local FrameClock = require("../src/shared/Util/FrameClock")

local SECONDS_PER_FRAME = 1 / 60
local MAX_CATCHUP = 8

local failures = 0
local checks = 0

local function check(name: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(`  PASS  {name}`)
	else
		failures += 1
		print(`  FAIL  {name}{if detail then "  --  " .. detail else ""}`)
	end
end

local function newClock()
	return FrameClock.new(SECONDS_PER_FRAME, MAX_CATCHUP)
end

--[[
	Runs `seconds` of simulated time at a steady frame rate and reports how many
	simulation frames the clock produced.
]]
local function runSteady(fps: number, seconds: number): number
	local clock = newClock()
	local dt = 1 / fps
	for _ = 1, math.floor(fps * seconds) do
		clock:Advance(dt)
	end
	return clock.frame
end

print("\n=== FrameClock ===\n")

-- 1. The core promise: same real time in, same frame count out, on any device.
do
	local expected = 600 -- 10 seconds x 60
	for _, fps in { 30, 60, 72, 90, 120, 144, 240 } do
		local frames = runSteady(fps, 10)
		check(
			`10s at {fps}fps produces {expected} frames`,
			math.abs(frames - expected) <= 1,
			`got {frames}`
		)
	end
end

-- 2. Irregular pacing must not drift. Real devices never deliver steady dt.
do
	local clock = newClock()
	local totalTime = 0
	-- Deterministic pseudo-random pacing between 4ms and 50ms, so a failure
	-- here is reproducible rather than a once-in-a-blue-moon flake.
	local seed = 12345
	for _ = 1, 4000 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local dt = 0.004 + (seed % 1000) / 1000 * 0.046
		totalTime += dt
		clock:Advance(dt)
	end
	local expected = math.floor(totalTime * 60)
	check(
		"irregular frame pacing does not drift",
		math.abs(clock.frame - expected) <= 1,
		`{clock.frame} frames over {string.format("%.2f", totalTime)}s, expected ~{expected}`
	)
	check("no frames dropped during normal pacing", clock.droppedFrames == 0, `dropped {clock.droppedFrames}`)
end

-- 3. A stall must drop time, never queue an unpayable backlog.
do
	local clock = newClock()
	local steps = clock:Advance(1.0) -- a full second in one call = 60 frames owed
	check("a 1s stall is capped at the catch-up limit", steps == MAX_CATCHUP, `ran {steps} frames`)
	check("frames beyond the cap are recorded as dropped", clock.droppedFrames == 60 - MAX_CATCHUP, `dropped {clock.droppedFrames}`)

	-- The critical property: the very next normal frame behaves normally. If
	-- the backlog had been queued instead of dropped, this would cap again and
	-- keep capping -- the spiral of death.
	local next = clock:Advance(SECONDS_PER_FRAME)
	check("the frame after a stall runs normally (no spiral)", next == 1, `ran {next} frames`)
end

-- 4. Bad input must be refused, not absorbed.
do
	local clock = newClock()
	check("negative delta produces no frames", clock:Advance(-5) == 0)
	check("zero delta produces no frames", clock:Advance(0) == 0)
	check("NaN delta produces no frames", clock:Advance(0 / 0) == 0)
	check("clock is untouched by bad input", clock.frame == 0 and clock.accumulator == 0)

	-- And still works afterwards.
	check("clock still advances after bad input", clock:Advance(SECONDS_PER_FRAME) == 1)
end

-- 5. Sub-frame time accumulates rather than being lost.
do
	local clock = newClock()
	local tiny = SECONDS_PER_FRAME / 4
	check("quarter-frame produces nothing", clock:Advance(tiny) == 0)
	check("half-frame produces nothing", clock:Advance(tiny) == 0)
	check("three-quarter-frame produces nothing", clock:Advance(tiny) == 0)
	check("the fourth quarter completes one frame", clock:Advance(tiny) == 1)
	check("exactly one frame was simulated", clock.frame == 1)
end

-- 6. Long-run precision. Floating point must not accumulate error over a fight.
do
	local clock = newClock()
	for _ = 1, 60 * 300 do -- five minutes at 60fps
		clock:Advance(SECONDS_PER_FRAME)
	end
	check(
		"five minutes of play stays frame-exact",
		math.abs(clock.frame - 60 * 300) <= 1,
		`{clock.frame} frames, expected {60 * 300}`
	)
end

-- 7. Reset returns the clock to a clean state.
do
	local clock = newClock()
	clock:Advance(1.0)
	clock:Reset()
	check("reset clears frame, accumulator and dropped count",
		clock.frame == 0 and clock.accumulator == 0 and clock.droppedFrames == 0)
end

print(`\n{checks - failures}/{checks} checks passed\n`)
if failures > 0 then
	error(`{failures} FrameClock check(s) failed`, 0)
end
