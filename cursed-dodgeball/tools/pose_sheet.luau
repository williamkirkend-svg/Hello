-- Prints one JSON line per named static pose, for the pose sheet (tools/pose_preview.py --sheet).
local Poses = require("../src/ReplicatedStorage/CursedDodgeball/Movement/Poses")
local function fmt(n) return string.format("%.4f", n) end
local function emit(name, pose)
	local parts = {}
	for _, j in Poses.JOINTS do
		local v = pose[j]
		table.insert(parts, string.format('"%s":[%s,%s,%s]', j, fmt(v.x), fmt(v.y), fmt(v.z)))
	end
	table.insert(parts, string.format('"RootPos":[%s,%s,%s]', fmt(pose.RootPos.x), fmt(pose.RootPos.y), fmt(pose.RootPos.z)))
	table.insert(parts, string.format('"RootSpin":[%s,%s,%s]', fmt(pose.RootSpin.x), fmt(pose.RootSpin.y), fmt(pose.RootSpin.z)))
	print(string.format('{"scene":"sheet","label":"%s","pos":[0,3,0],"yaw":0,"state":"","speed":0,"pose":{%s}}', name, table.concat(parts, ",")))
end
emit("idle", Poses.idle(0))
for i = 0, 7 do emit("sprint " .. i .. "/8", Poses.run(i / 8, 0.82)) end
for i = 0, 3 do emit("jog " .. i .. "/4", Poses.run(i / 4, 0.57)) end
emit("air rise", Poses.air(1, true))
emit("air apex", Poses.air(0, true))
emit("air fall", Poses.air(-1, true))
emit("tuck", Poses.tuck())
emit("wall run 0", Poses.wallRun(0, 1))
emit("wall run 1/4", Poses.wallRun(0.25, 1))
emit("wall kick", Poses.wallKick(1))
emit("slide", Poses.slide())
emit("dash fwd", Poses.dash(0, -1))
emit("dash right", Poses.dash(1, 0))
emit("land light", Poses.land("Light", 1))
emit("land medium", Poses.land("Medium", 1))
emit("land heavy", Poses.land("Heavy", 1))
emit("roll 1/4", Poses.roll(0.25))
emit("roll 1/2", Poses.roll(0.5))
emit("mantle", Poses.mantle(0.5))
