--!strict
--[[
	FrameClock — fixed 60Hz timestep

	The most important technical decision in the project lives in this file.

	THE PROBLEM

	Roblox calls your code once per rendered frame, and that rate is whatever
	the player's device manages: ~30 times a second on a weak phone, 144 on a
	good PC, and irregularly on both. If combat timing were driven by the time
	elapsed between those calls (delta-time), then a 9-frame startup would be a
	different length of real time on every device, and a dodge's i-frames would
	cover a different slice of the fight depending on hardware.

	That is unacceptable. "I dodged that" has to mean the same thing everywhere.

	THE SOLUTION

	Collect real elapsed time in an accumulator. Whenever a whole 1/60th of a
	second has piled up, run exactly one simulation frame. Combat never sees
	delta-time at all -- it only ever advances one fixed frame at a time.

		accumulator += dt
		while accumulator >= 1/60 do
			accumulator -= 1/60
			step()
		end

	A device running at 144fps produces a step on some calls and not others. A
	device running at 30fps produces two steps per call. Both devices run the
	identical number of simulation frames per second of real time, so frame 3 of
	a dodge is frame 3 everywhere.

	THE CATCH-UP CAP

	If the game stalls for a full second, the naive loop above tries to run 60
	frames at once. That takes time, which makes the next stall worse, which
	demands more catch-up: the "spiral of death", where the game freezes solid
	and never recovers.

	So catch-up is capped. Past the cap, time is DROPPED rather than queued --
	the accumulator is drained either way. The simulation briefly runs slow
	instead of trying to replay a backlog it can never finish. Dropped frames
	are counted so a stall shows up in diagnostics instead of hiding.

	PURITY

	This module deliberately requires nothing -- not RunService, not the config
	modules, no Roblox API at all. Everything it needs arrives through the
	constructor. That is what lets the test suite in tests/ run it thousands of
	times outside Roblox and prove the timing is exact.

	Binding it to Heartbeat is the caller's job:

		local clock = FrameClock.new(CombatConfig.SECONDS_PER_FRAME, CombatConfig.MAX_CATCHUP_FRAMES)
		RunService.Heartbeat:Connect(function(dt)
			for _ = 1, clock:Advance(dt) do
				stepCombat()
			end
		end)
]]

local FrameClock = {}
FrameClock.__index = FrameClock

export type FrameClock = {
	-- Length of one simulation frame, in seconds. Never changes after creation.
	secondsPerFrame: number,
	-- Most frames a single Advance call may return.
	maxCatchupFrames: number,

	-- Real time collected but not yet spent on a frame. Always less than one
	-- frame's worth once Advance has returned.
	accumulator: number,
	-- Total frames simulated since creation. This is the authoritative clock
	-- that combat timing is measured against.
	frame: number,
	-- Frames abandoned to the catch-up cap. Non-zero means the game stalled.
	droppedFrames: number,

	Advance: (self: FrameClock, deltaSeconds: number) -> number,
	Reset: (self: FrameClock) -> (),
}

--[[
	secondsPerFrame  -- pass CombatConfig.SECONDS_PER_FRAME (1/60)
	maxCatchupFrames -- pass CombatConfig.MAX_CATCHUP_FRAMES
]]
function FrameClock.new(secondsPerFrame: number, maxCatchupFrames: number): FrameClock
	assert(secondsPerFrame > 0, "FrameClock: secondsPerFrame must be greater than zero")
	assert(maxCatchupFrames >= 1, "FrameClock: maxCatchupFrames must be at least one")

	local self = {
		secondsPerFrame = secondsPerFrame,
		maxCatchupFrames = maxCatchupFrames,
		accumulator = 0,
		frame = 0,
		droppedFrames = 0,
	}

	return setmetatable(self, FrameClock) :: any
end

--[[
	Feeds real elapsed time in and returns how many simulation frames to run
	right now. The caller runs exactly that many steps.

	Returns 0 frequently on fast hardware -- that is correct and expected, not
	a stall.

	Nonsense input (negative, NaN) is ignored rather than corrupting the clock:
	`deltaSeconds > 0` is false for both, and a clock that quietly refuses bad
	time is far better than one that silently jumps the whole simulation.
]]
function FrameClock.Advance(self: FrameClock, deltaSeconds: number): number
	if deltaSeconds > 0 then
		self.accumulator += deltaSeconds
	end

	local steps = math.floor(self.accumulator / self.secondsPerFrame)
	if steps <= 0 then
		return 0
	end

	-- Drain what we counted BEFORE applying the cap. Draining the full amount
	-- is what converts an unpayable backlog into dropped time instead of debt
	-- that compounds on every subsequent call.
	self.accumulator -= steps * self.secondsPerFrame

	if steps > self.maxCatchupFrames then
		self.droppedFrames += steps - self.maxCatchupFrames
		steps = self.maxCatchupFrames
	end

	self.frame += steps
	return steps
end

--[[
	Returns the clock to its starting state. Intended for tests and for a clean
	restart between rounds -- not for normal play, where the frame counter is
	expected to run continuously.
]]
function FrameClock.Reset(self: FrameClock)
	self.accumulator = 0
	self.frame = 0
	self.droppedFrames = 0
end

return FrameClock
