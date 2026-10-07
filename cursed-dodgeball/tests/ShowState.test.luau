return function(t)
	local ShowState = require("../src/ReplicatedStorage/CursedDodgeball/Pure/ShowState")
	local Config = require("../src/ReplicatedStorage/CursedDodgeball/Config")

	local function rng() return 0.5 end
	local function types(events)
		local out = {}
		for _, e in events do out[#out + 1] = e.type end
		return table.concat(out, ",")
	end
	local function has(events, ty)
		for _, e in events do if e.type == ty then return e end end
		return nil
	end
	local function run(state, seconds, dt)
		dt = dt or 0.5
		local all = {}
		local elapsed = 0
		while elapsed < seconds - 1e-9 do
			for _, e in state:step(dt) do all[#all + 1] = e end
			elapsed += dt
		end
		return all
	end
	local function fresh(n)
		local s = ShowState.new(Config, rng)
		for i = 1, n do s:addPlayer("p" .. i) end
		return s
	end

	-- intermission re-arms below the minimum
	do
		local s = fresh(3)
		t.eq(s.phase, "Intermission", "starts in intermission")
		local ev = run(s, 21)
		t.eq(s.phase, "Intermission", "stays in intermission with 3 players")
		t.ok(s.timer > 0, "timer re-armed")
		t.ok(not has(ev, "BallsDrawn"), "no balls drawn")
	end

	-- full show with 20 players
	do
		local s = fresh(20)
		local ev = run(s, 20)
		t.eq(s.phase, "Round", "round starts at 20 players")
		t.eq(s.round, 1, "round 1")
		t.ok(has(ev, "BallsDrawn"), "balls drawn on round start")
		t.eq(has(ev, "BallsDrawn").round, 1, "balls drawn for round 1")
		t.eq(s:liveCount(), 20, "20 live")
		t.eq(s:roleOf("p1"), "Live", "p1 live")
		-- hits down to 8
		local evs = {}
		for i = 1, 12 do
			for _, e in s:hit("p" .. i, "p20", i) do evs[#evs + 1] = e end
		end
		t.eq(s:liveCount(), 8, "8 live after 12 hits")
		t.eq(s:roleOf("p1"), "Ghost", "p1 is a ghost")
		local cut = has(evs, "Cut")
		t.ok(cut, "cut fires at 8")
		t.eq(cut and cut.round, 1, "cut round 1")
		t.eq(s.phase, "Replay", "replay after cut")
		run(s, 8.5)
		t.eq(s.phase, "Round", "round 2 after replay")
		t.eq(s.round, 2, "round 2")
		t.eq(s:roleOf("p1"), "Spectator", "ghosts from round 1 are spectators in round 2 unless they return")
		-- round 2: ghost mechanics before cut
		-- p13..p20 live. hit p13 to make a ghost with one throw
		s:hit("p13", "p20", 100)
		t.eq(s:roleOf("p13"), "Ghost", "p13 ghost")
		local gh = s:ghostThrowHit("p13", "p14")
		t.ok(has(gh, "GhostReturned"), "ghost swap event")
		t.eq(s:roleOf("p13"), "Live", "p13 back in")
		t.eq(s:roleOf("p14"), "Ghost", "p14 is now the ghost")
		t.ok(not has(gh, "Cut"), "ghost swap never cuts")
		t.eq(s:liveCount(), 7, "live count unchanged by swap")
		local again = s:ghostThrowHit("p14", "p13")
		t.ok(has(again, "GhostReturned"), "second swap event")
		t.eq(s:roleOf("p14"), "Live", "p14 back in")
		t.eq(s:roleOf("p13"), "Spectator", "p13 already used his one throw this round, so straight to the stands")
		local spent = s:ghostThrowHit("p13", "p15")
		t.eq(#spent, 0, "a spectator cannot ghost-throw")
		s:hit("p15", "p20", 100.5)
		t.eq(s:roleOf("p15"), "Ghost", "p15 ghost")
		s:ghostThrowSpent("p15")
		t.eq(s:roleOf("p15"), "Spectator", "miss sends ghost to the stands")
		t.eq(s:liveCount(), 6, "six live: p14, p16..p20")
		-- shield
		local c = s:catch("p16", "p17") -- p16 catches p17's throw
		t.ok(has(c, "ShieldGained"), "catch gives shield")
		t.eq(s:roleOf("p17"), "Ghost", "thrower out on catch")
		local blocked = s:hit("p16", "p20", 102)
		t.ok(not has(blocked, "Eliminated"), "shield blocks the hit")
		t.eq(s:roleOf("p16"), "Live", "p16 still live after shielded hit")
		local sec = s:hit("p16", "p20", 103)
		t.ok(has(sec, "Eliminated"), "second hit eliminates")
		-- live now: p14, p18, p19, p20 => cut to 4 fires
		t.eq(s.phase, "Replay", "cut at 4 reached")
		run(s, 8.5)
		t.eq(s.phase, "Round", "final starts")
		t.eq(s.round, 3, "round 3")
		-- in final, a hit player is a spectator immediately
		s:hit("p18", "p20", 200)
		t.eq(s:roleOf("p18"), "Spectator", "no ghosts in the final")
		s:hit("p19", "p20", 201)
		local w = s:hit("p14", "p20", 202)
		local win = has(w, "Winner")
		t.ok(win, "winner event")
		t.eq(win and win.id, "p20", "p20 wins")
		t.eq(s.phase, "Crowning", "crowning")
		run(s, 15.5)
		t.eq(s.phase, "Intermission", "back to intermission")
	end

	-- shield expires after 3 s
	do
		local s = fresh(20)
		run(s, 20)
		s:catch("p1", "p2")
		local ev = run(s, 3.5)
		t.ok(has(ev, "ShieldExpired"), "shield expired event")
		local h = s:hit("p1", "p3", 1)
		t.ok(has(h, "Eliminated"), "hit lands after shield expiry")
	end

	-- buzzer sets flood, cut still by count
	do
		local s = fresh(20)
		run(s, 20)
		local ev = run(s, 91)
		t.ok(has(ev, "FloodStarted"), "flood at cap")
		t.eq(s.flood, true, "flood flag")
		t.eq(s.phase, "Round", "round continues under flood")
		for i = 1, 12 do s:hit("p" .. i, "p20", i) end
		t.eq(s.phase, "Replay", "cut under flood")
		t.eq(s.flood, false, "flood clears after cut")
	end

	-- player leaving mid-round counts toward the cut
	do
		local s = fresh(20)
		run(s, 20)
		for i = 1, 11 do s:hit("p" .. i, "p20", i) end
		t.eq(s.phase, "Round", "9 live, no cut yet")
		local ev = s:removePlayer("p12")
		t.ok(has(ev, "Cut"), "leaving triggers the cut")
	end

	-- small show (5 players) runs two rounds
	do
		local s = fresh(5)
		run(s, 20)
		t.eq(s.phase, "Intermission", "5 is below the minimum, no start")
		s:addPlayer("p6")
		run(s, 20)
		t.eq(s.phase, "Round", "6 starts")
		s:removePlayer("p6")
		-- 5 live, show was planned at 6 so uses normal rounds; test the explicit small path
		local small = ShowState.new(Config, rng)
		for i = 1, 6 do small:addPlayer("q" .. i) end
		run(small, 20)
		t.eq(#small.rounds, 3, "6 players use three rounds")
		-- force a small show by config
		local cfg = table.clone(Config)
		cfg.Players = table.clone(Config.Players)
		cfg.Players.Min = 4
		cfg.Players.SmallShowBelow = 6
		local s4 = ShowState.new(cfg, rng)
		for i = 1, 4 do s4:addPlayer("r" .. i) end
		run(s4, 20)
		t.eq(#s4.rounds, 2, "4 players use two rounds")
		t.eq(s4.rounds[1].CutTo, 3, "small round 1 cuts to 3")
	end

	-- double hit on the last two: earlier stamp loses, never zero players
	do
		local s = fresh(20)
		run(s, 20)
		for i = 1, 12 do s:hit("p" .. i, "p20", i) end
		run(s, 8.5)
		for i = 13, 16 do s:hit("p" .. i, "p20", i) end
		run(s, 8.5)
		t.eq(s.round, 3, "final")
		s:hit("p17", "p20", 300)
		s:hit("p18", "p20", 301)
		-- p19 and p20 left; both hit same frame, p19 stamp 400, p20 stamp 399
		local e1 = s:hit("p20", "p19", 400)
		local e2 = s:hit("p19", "p20", 399)
		local win = has(e1, "Winner") or has(e2, "Winner")
		t.ok(win, "a winner exists")
		t.eq(s:liveCount(), 1, "never zero live")
	end

	-- hits on non-live players are ignored
	do
		local s = fresh(20)
		run(s, 20)
		s:hit("p1", "p2", 1)
		local ev = s:hit("p1", "p3", 2)
		t.eq(#ev, 0, "ghost cannot be hit")
		t.eq(s:liveCount(), 19, "count unchanged")
	end

	-- phase changes emit
	do
		local s = fresh(20)
		local ev = run(s, 20)
		local pc = has(ev, "PhaseChanged")
		t.ok(pc and pc.phase == "Round" and pc.round == 1, "phase changed to round 1")
	end
end
