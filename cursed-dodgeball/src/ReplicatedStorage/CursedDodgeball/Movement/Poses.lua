-- Cursed Dodgeball procedural poses for the R15 rig. Pure: numbers only, no Roblox requires.
--
-- A pose is a table of joint rotations in radians (Euler x, y, z applied in the joint's own frame) plus
--   RootPos   offset of the hips from the root part, in studs, character space
--   RootSpin  extra whole-body rotation (rolls), applied about a pivot above the hips, never smoothed
-- Character space: X right, Y up, Z back (forward is -Z), matching Roblox.
-- Sign conventions (R15 joints have axis-aligned C0/C1 frames):
--   Hip / Shoulder  x > 0 swings the limb forward     z > 0 moves a right limb outward (left: z < 0)
--   Knee            x < 0 bends the knee
--   Elbow           x > 0 bends the elbow
--   Ankle           x > 0 lifts the toes, x < 0 points them
--   Root / Waist    x > 0 leans back (and swings the legs forward), x < 0 leans forward
--                   z > 0 rolls the body to its left, y > 0 turns it to its left
local Poses = {}

Poses.JOINTS = {
	"Root", "Waist", "Neck",
	"LShoulder", "LElbow", "LWrist", "RShoulder", "RElbow", "RWrist",
	"LHip", "LKnee", "LAnkle", "RHip", "RKnee", "RAnkle",
}

local MIRROR = { LShoulder = "RShoulder", LElbow = "RElbow", LWrist = "RWrist", LHip = "RHip", LKnee = "RKnee", LAnkle = "RAnkle" }
for a, b in pairs(table.clone(MIRROR)) do MIRROR[b] = a end

local TAU = 2 * math.pi
local sin, cos, max, min = math.sin, math.cos, math.max, math.min

local function v(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end

function Poses.new()
	local p = {}
	for _, j in Poses.JOINTS do p[j] = v() end
	p.RootPos = v()
	p.RootSpin = v()
	return p
end

local function set(p, j, x, y, z)
	p[j].x, p[j].y, p[j].z = x or 0, y or 0, z or 0
end

local function lerpNum(a, b, w) return a + (b - a) * w end

function Poses.lerp(a, b, w)
	local p = Poses.new()
	for _, j in Poses.JOINTS do
		local pa, pb, o = a[j], b[j], p[j]
		o.x, o.y, o.z = lerpNum(pa.x, pb.x, w), lerpNum(pa.y, pb.y, w), lerpNum(pa.z, pb.z, w)
	end
	for _, k in { "RootPos", "RootSpin" } do
		p[k].x, p[k].y, p[k].z = lerpNum(a[k].x, b[k].x, w), lerpNum(a[k].y, b[k].y, w), lerpNum(a[k].z, b[k].z, w)
	end
	return p
end

-- Weighted sum of poses; weights need not add to 1 (they are normalised).
function Poses.blend(list)
	local p = Poses.new()
	local total = 0
	for _, e in list do total += e[2] end
	if total <= 1e-9 then return p end
	for _, e in list do
		local q, w = e[1], e[2] / total
		if w > 0 then
			for _, j in Poses.JOINTS do
				local o, s = p[j], q[j]
				o.x += s.x * w
				o.y += s.y * w
				o.z += s.z * w
			end
			for _, k in { "RootPos", "RootSpin" } do
				p[k].x += q[k].x * w
				p[k].y += q[k].y * w
				p[k].z += q[k].z * w
			end
		end
	end
	return p
end

-- Left/right mirror: swap sides, negate the sideways rotations (y and z) and sideways offset.
function Poses.mirror(src)
	local p = Poses.new()
	for _, j in Poses.JOINTS do
		local from = src[MIRROR[j] or j]
		set(p, j, from.x, -from.y, -from.z)
	end
	p.RootPos.x, p.RootPos.y, p.RootPos.z = -src.RootPos.x, src.RootPos.y, src.RootPos.z
	p.RootSpin.x, p.RootSpin.y, p.RootSpin.z = src.RootSpin.x, -src.RootSpin.y, -src.RootSpin.z
	return p
end

-- Keep the head level and looking ahead whatever the body is doing.
local function stabiliseHead(p, k)
	k = k or 0.7
	p.Neck.x -= (p.Root.x + p.Waist.x) * k
	p.Neck.y -= (p.Root.y + p.Waist.y) * k
	p.Neck.z -= p.Root.z * k * 0.6
end

function Poses.idle(t)
	local p = Poses.new()
	local breathe = sin(t * 1.6)
	local sway = sin(t * 0.5)
	set(p, "Root", 0.02 * breathe * 0.5, 0, 0.025 * sway)
	set(p, "Waist", -0.03 - 0.02 * breathe, 0, -0.01 * sway)
	set(p, "LShoulder", 0.06, 0, -0.1 - 0.02 * breathe)
	set(p, "RShoulder", 0.06, 0, 0.1 + 0.02 * breathe)
	set(p, "LElbow", 0.18)
	set(p, "RElbow", 0.18)
	set(p, "LHip", 0.1, 0, -0.04)
	set(p, "RHip", 0.1, 0, 0.04)
	set(p, "LKnee", -0.18)
	set(p, "RKnee", -0.18)
	set(p, "LAnkle", 0.08)
	set(p, "RAnkle", 0.08)
	p.RootPos.x = 0.06 * sway
	p.RootPos.y = -0.06 - 0.025 * breathe
	stabiliseHead(p, 0.8)
	return p
end

-- One leg of the run cycle. ph is that leg's phase angle; s is speed 0..1.
local function runLeg(p, hip, knee, ankle, ph, s, bias)
	local amp = 0.5 + 0.48 * s
	local swing = sin(ph)
	local fwd = cos(ph) -- > 0 while the leg is swinging forward
	local kick = max(0, cos(ph + 0.45))
	p[hip].x = bias + amp * swing
	-- stance: the planted knee loads up to about 30 degrees at mid-stance instead of locking straight
	local stance = max(0, -fwd)
	p[knee].x = -(0.16 + (0.85 + 0.95 * s) * kick ^ 1.3 + (0.32 + 0.22 * s) * stance * stance)
	p[ankle].x = -0.32 * (0.4 + 0.6 * s) * max(0, -swing) * max(0, -fwd) + 0.18 * max(0, fwd)
end

function Poses.run(phase, s)
	s = math.clamp(s, 0, 1)
	local p = Poses.new()
	local ph = phase * TAU
	-- full-out sprint, matched to references 1, 4 and 5: the body pitches hard forward (about 34 degrees
	-- at sprint speed, 40 at the cap); the legs are rotated back under it so the feet land under the body
	local lean = 0.08 + 0.62 * s
	local pelvisShare = 0.5
	local hipBias = 0.08 + lean * pelvisShare
	runLeg(p, "RHip", "RKnee", "RAnkle", ph, s, hipBias)
	runLeg(p, "LHip", "LKnee", "LAnkle", ph + math.pi, s, hipBias)
	p.RHip.z, p.LHip.z = 0.03, -0.03

	-- arms out wide from the sides, elbows near 90 degrees, big swing biased behind the body
	local armAmp = 0.45 + 0.8 * s
	local armOut = 0.12 + 0.45 * s
	local armBack = 0.12 - 0.32 * s
	local rs, ls = sin(ph), sin(ph + math.pi)
	set(p, "RShoulder", armBack - armAmp * rs, 0, armOut + 0.12 * s * max(0, -rs))
	set(p, "LShoulder", armBack - armAmp * ls, 0, -armOut - 0.12 * s * max(0, -ls))
	set(p, "RElbow", 1.05 + 0.45 * s + 0.25 * max(0, -rs))
	set(p, "LElbow", 1.05 + 0.45 * s + 0.25 * max(0, -ls))
	set(p, "RWrist", -0.1)
	set(p, "LWrist", -0.1)

	local twist = sin(ph)
	set(p, "Root", -lean * pelvisShare, 0.12 * s * twist, 0)
	set(p, "Waist", -lean * (1 - pelvisShare), -0.3 * s * twist, 0)
	p.RootPos.y = (0.16 + 0.2 * s) * (math.abs(sin(ph)) - 0.55) - 0.15 * s
	p.RootPos.z = -0.35 * s -- hips carried slightly forward of the root, into the lean
	-- head goes forward with the body (references): only partly counter-rotated at speed
	stabiliseHead(p, 0.75 - 0.4 * s)
	return p
end

-- Airborne. vy01: +1 rising fast, 0 apex, -1 falling fast. leadRight picks which knee leads the jump.
function Poses.air(vy01, leadRight)
	vy01 = math.clamp(vy01, -1, 1)
	local rise, apex, fall = Poses.new(), Poses.new(), Poses.new()
	-- rise: lead knee up, trail leg back, opposite arm forward
	set(rise, "RHip", 1.0)
	set(rise, "RKnee", -1.45)
	set(rise, "RAnkle", -0.15)
	set(rise, "LHip", -0.35, 0, -0.05)
	set(rise, "LKnee", -0.75)
	set(rise, "LAnkle", -0.35)
	set(rise, "LShoulder", 0.95, 0, -0.25)
	set(rise, "RShoulder", -0.35, 0, 0.3)
	set(rise, "LElbow", 0.7)
	set(rise, "RElbow", 0.55)
	set(rise, "Root", -0.08)
	set(rise, "Waist", 0.06)
	-- apex: legs gather, arms open
	set(apex, "RHip", 0.65)
	set(apex, "RKnee", -1.2)
	set(apex, "LHip", 0.3)
	set(apex, "LKnee", -1.0)
	set(apex, "RAnkle", -0.1)
	set(apex, "LAnkle", -0.1)
	set(apex, "LShoulder", 0.35, 0, -0.55)
	set(apex, "RShoulder", 0.35, 0, 0.55)
	set(apex, "LElbow", 0.5)
	set(apex, "RElbow", 0.5)
	-- fall: arms up and out for balance, legs reaching for the ground
	set(fall, "RHip", 0.35, 0, 0.06)
	set(fall, "RKnee", -0.5)
	set(fall, "LHip", 0.12, 0, -0.06)
	set(fall, "LKnee", -0.38)
	set(fall, "RAnkle", 0.12)
	set(fall, "LAnkle", 0.12)
	set(fall, "LShoulder", 0.75, 0, -0.85)
	set(fall, "RShoulder", 0.6, 0, 0.9)
	set(fall, "LElbow", 0.4)
	set(fall, "RElbow", 0.4)
	set(fall, "Root", 0.05)
	set(fall, "Waist", 0.04)
	local p
	if vy01 >= 0 then p = Poses.lerp(apex, rise, vy01) else p = Poses.lerp(apex, fall, -vy01) end
	if not leadRight then p = Poses.mirror(p) end
	stabiliseHead(p, 0.6)
	return p
end

-- Double jump: a quick knee tuck.
function Poses.tuck()
	local p = Poses.new()
	set(p, "RHip", 1.5, 0, 0.08)
	set(p, "LHip", 1.45, 0, -0.08)
	set(p, "RKnee", -2.15)
	set(p, "LKnee", -2.2)
	set(p, "RAnkle", -0.4)
	set(p, "LAnkle", -0.4)
	set(p, "RShoulder", 0.85, 0, 0.25)
	set(p, "LShoulder", 0.85, 0, -0.25)
	set(p, "RElbow", 1.5)
	set(p, "LElbow", 1.5)
	set(p, "Root", -0.18)
	set(p, "Waist", -0.12)
	p.RootPos.y = 0.45
	stabiliseHead(p, 0.6)
	return p
end

-- Wall run. side: +1 wall on the right, -1 wall on the left. Built for a right wall, mirrored for left.
function Poses.wallRun(phase, side)
	local p = Poses.run(phase, 1)
	local ph = phase * TAU
	-- higher knees, quicker feet
	p.RHip.x += 0.2
	p.LHip.x += 0.2
	p.RKnee.x -= 0.25
	p.LKnee.x -= 0.25
	-- body tips its head away from the wall, feet toward it
	p.Root.z = 0.42
	p.Root.x = -0.04
	p.Waist.z = 0.08
	p.RootPos.x = 0.5
	p.RootPos.y = -0.05
	-- wall-side arm reaches forward and up toward the wall, outer arm back and out
	set(p, "RShoulder", 1.4 + 0.1 * sin(ph * 2), 0, 0.3)
	set(p, "RElbow", 0.35)
	set(p, "LShoulder", -0.55 + 0.15 * sin(ph), 0, -0.95)
	set(p, "LElbow", 0.45)
	p.Neck.x, p.Neck.y, p.Neck.z = 0.02, 0, -0.25
	if side == -1 then p = Poses.mirror(p) end
	return p
end

-- Push off a wall: legs drive into it, body arches away, arms fling out.
function Poses.wallKick(side)
	local p = Poses.new()
	set(p, "RHip", -0.25, 0, 0.55)
	set(p, "LHip", -0.1, 0, 0.3)
	set(p, "RKnee", -0.25)
	set(p, "LKnee", -0.45)
	set(p, "RAnkle", -0.4)
	set(p, "LAnkle", -0.35)
	set(p, "Root", 0.22, 0, -0.25)
	set(p, "Waist", 0.15, 0, -0.1)
	set(p, "RShoulder", 0.6, 0, 1.3)
	set(p, "LShoulder", 0.6, 0, -1.35)
	set(p, "RElbow", 0.25)
	set(p, "LElbow", 0.25)
	p.Neck.x = -0.1
	if side == -1 then p = Poses.mirror(p) end
	return p
end

-- Slide, copied from reference 2 (a baseball slide), long and low: torso laid back about 65 degrees and
-- twisted toward the bent leg, head up looking ahead; lead (left) leg dead straight out in front with the
-- toes up; right leg bent with the knee up and out to the side, foot flat; left hand down on the floor
-- beside the hip; right arm raised up and back beside the head.
function Poses.slide()
	-- Reference 2: laid back, right leg straight out in front, left leg splayed out to the side with a
	-- soft knee, right hand down on the floor beside the hip, left arm thrown up and out.
	local p = Poses.new()
	set(p, "Root", 1.15, 0, 0)
	set(p, "Waist", 0.1, 0.15, -0.05)
	set(p, "RHip", 0.42, 0, 0.05)
	set(p, "RKnee", -0.05)
	set(p, "RAnkle", 0.3)
	set(p, "LHip", 0.5, 0, -0.45)
	set(p, "LKnee", -0.4)
	set(p, "LAnkle", 0.25)
	set(p, "RShoulder", -1.05, 0, 0.45)
	set(p, "RElbow", 0.15)
	set(p, "LShoulder", 1.9, 0, -0.95)
	set(p, "LElbow", 0.4)
	p.RootPos.y = -0.65
	p.Neck.x = -0.95
	p.Neck.y = -0.1
	return p
end

-- Dash lean. dx, dz: dash direction in character space (forward is dz = -1).
function Poses.dash(dx, dz)
	local fwd, back, side = Poses.new(), Poses.new(), Poses.new()
	-- forward: dive lean, legs trailing, arms swept back
	set(fwd, "Root", -0.2)
	set(fwd, "Waist", -0.45)
	set(fwd, "RHip", -0.15)
	set(fwd, "LHip", 0.45)
	set(fwd, "RKnee", -0.9)
	set(fwd, "LKnee", -0.6)
	set(fwd, "RShoulder", -0.8, 0, 0.35)
	set(fwd, "LShoulder", -0.8, 0, -0.35)
	set(fwd, "RElbow", 0.35)
	set(fwd, "LElbow", 0.35)
	-- backward: lean back, arms forward
	set(back, "Root", 0.3)
	set(back, "Waist", 0.1)
	set(back, "RHip", 0.55)
	set(back, "LHip", 0.15)
	set(back, "RKnee", -0.7)
	set(back, "LKnee", -0.5)
	set(back, "RShoulder", 0.9, 0, 0.3)
	set(back, "LShoulder", 0.9, 0, -0.3)
	set(back, "RElbow", 0.5)
	set(back, "LElbow", 0.5)
	-- sideways (to the right): lean into it, trailing leg crosses
	set(side, "Root", -0.08, 0, -0.38)
	set(side, "Waist", -0.1, 0, -0.1)
	set(side, "RHip", 0.1, 0, 0.45)
	set(side, "LHip", 0.2, 0, 0.25)
	set(side, "RKnee", -0.4)
	set(side, "LKnee", -0.9)
	set(side, "RShoulder", 0.2, 0, 0.35)
	set(side, "LShoulder", 0.3, 0, -1.0)
	set(side, "RElbow", 0.6)
	set(side, "LElbow", 0.4)
	local list = {}
	if dz < 0 then table.insert(list, { fwd, -dz }) end
	if dz > 0 then table.insert(list, { back, dz }) end
	if dx > 0 then table.insert(list, { side, dx }) end
	if dx < 0 then table.insert(list, { Poses.mirror(side), -dx }) end
	if #list == 0 then table.insert(list, { fwd, 1 }) end
	local p = Poses.blend(list)
	stabiliseHead(p, 0.6)
	return p
end

-- Landing crouch. k: depth 0..1 (the animator drives it up and back down).
function Poses.land(kind, k)
	local p = Poses.new()
	if kind == "Heavy" then
		-- hero landing: front knee up, back knee low, one hand down
		set(p, "RHip", 1.35 * k, 0, 0.1 * k)
		set(p, "RKnee", -2.05 * k)
		set(p, "RAnkle", 0.5 * k)
		set(p, "LHip", -0.15 * k, 0, -0.15 * k)
		set(p, "LKnee", -1.95 * k)
		set(p, "LAnkle", -0.4 * k)
		set(p, "Root", -0.15 * k)
		set(p, "Waist", -0.5 * k)
		set(p, "RShoulder", 0.95 * k, 0, 0.3 * k)
		set(p, "RElbow", 0.2 * k)
		set(p, "LShoulder", -0.6 * k, 0, -0.9 * k)
		set(p, "LElbow", 0.5 * k)
		p.RootPos.y = -1.5 * k
		p.Neck.x = 0.45 * k
		return p
	end
	local depth = (kind == "Medium") and 1 or 0.55
	set(p, "RHip", 0.82 * depth * k, 0, 0.05 * k)
	set(p, "LHip", 0.78 * depth * k, 0, -0.05 * k)
	set(p, "RKnee", -1.6 * depth * k)
	set(p, "LKnee", -1.55 * depth * k)
	set(p, "RAnkle", 0.62 * depth * k)
	set(p, "LAnkle", 0.6 * depth * k)
	set(p, "Root", -0.08 * depth * k)
	set(p, "Waist", -0.32 * depth * k)
	set(p, "RShoulder", 0.35 * depth * k, 0, 0.6 * depth * k)
	set(p, "LShoulder", 0.35 * depth * k, 0, -0.6 * depth * k)
	set(p, "RElbow", 0.5 * k)
	set(p, "LElbow", 0.5 * k)
	p.RootPos.y = -0.88 * depth * k
	p.Neck.x = 0.25 * depth * k
	return p
end

local function smoothstep(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- Forward roll over t01 in 0..1: one full forward turn, tucked, low to the ground.
function Poses.roll(t01)
	local e = smoothstep(t01)
	local bell = sin(math.clamp(t01, 0, 1) * math.pi)
	local p = Poses.lerp(Poses.new(), Poses.tuck(), bell)
	p.RootPos.y = -1.25 * bell
	p.RootSpin.x = -TAU * e
	return p
end

-- Vault over a low ledge: hands down on it, legs swing over to the left.
function Poses.mantle(t01)
	local bell = sin(math.clamp(t01, 0, 1) * math.pi)
	local q = Poses.new()
	set(q, "RShoulder", 1.25, 0, 0.2)
	set(q, "LShoulder", 1.15, 0, -0.15)
	set(q, "RElbow", 0.3)
	set(q, "LElbow", 0.35)
	set(q, "RHip", 1.3, 0, -0.35)
	set(q, "LHip", 1.2, 0, -0.45)
	set(q, "RKnee", -1.7)
	set(q, "LKnee", -1.9)
	set(q, "Root", -0.3, 0, 0.3)
	set(q, "Waist", -0.25)
	q.RootPos.y = 0.3
	return Poses.lerp(Poses.new(), q, bell)
end

-- ---------------------------------------------------------------- foot contact
-- Leg geometry in studs (pelvis pivot frame). The Roblox animator measures the real rig and passes its
-- own values; these defaults match the preview renderer.
Poses.DEFAULT_RIG = { hipX = 0.5, hipY = -0.2, thigh = 1.05, shin = 0.95, sole = 0.27, toe = 0.6, heel = 0.5 }

local function rot(x, y, z)
	-- CFrame.Angles(x, y, z) = Rx * Ry * Rz as a 3x3 row-major matrix
	local cx, sx, cy, sy, cz, sz = cos(x), sin(x), cos(y), sin(y), cos(z), sin(z)
	return {
		cy * cz, -cy * sz, sy,
		sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy,
		-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy,
	}
end
local function mul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function apply(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z
end

-- Height of one foot's lowest sole point above where it rests in the neutral standing pose (studs).
local function footLow(pose, side, rig)
	local hipJ, kneeJ, ankleJ = side .. "Hip", side .. "Knee", side .. "Ankle"
	local sx = (side == "R") and rig.hipX or -rig.hipX
	local r = pose.Root
	local m0 = rot(r.x, r.y, r.z)
	local hx, hy, hz = apply(m0, sx, rig.hipY, 0)
	local h = pose[hipJ]
	local m1 = mul(m0, rot(h.x, h.y, h.z))
	local kx, ky, kz = apply(m1, 0, -rig.thigh, 0)
	local k = pose[kneeJ]
	local m2 = mul(m1, rot(k.x, k.y, k.z))
	local ax, ay, az = apply(m2, 0, -rig.shin, 0)
	local a = pose[ankleJ]
	local m3 = mul(m2, rot(a.x, a.y, a.z))
	local low = math.huge
	for _, zz in { -rig.toe, rig.heel } do
		local _, py = apply(m3, 0, -rig.sole, zz)
		low = math.min(low, hy + ky + ay + py)
	end
	local neutral = rig.hipY - rig.thigh - rig.shin - rig.sole
	local _ = hx + hz + kx + kz + ax + az
	return low - neutral
end

-- Lowest foot height (after RootPos) relative to the ground in the neutral pose: > 0 floating, < 0 sinking.
function Poses.lowestFoot(pose, rig)
	rig = rig or Poses.DEFAULT_RIG
	return math.min(footLow(pose, "R", rig), footLow(pose, "L", rig)) + pose.RootPos.y
end

return Poses
