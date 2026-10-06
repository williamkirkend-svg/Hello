--!strict
-- CelebrationFloat: lifts the LOCAL player's character off the ground, holds a
-- "commanding" pose (arms raised in a V, head up, slow turn, gentle bob) and
-- sets them back down. The character is client-owned physics, so what this
-- does replicates to everyone without any network code.
--
-- Poses are written to Motor6D.Transform on RunService.Stepped, after the
-- Animator has written its frame, so no uploaded animation is needed.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.VFXKit)

local Float = {}

export type Handle = {
	Stop: (self: Handle) -> (),
	Height: (self: Handle) -> number,
}

-- Rotate `joint` about Part0's local axes by `rot` (a pure rotation CFrame),
-- regardless of how the joint's C0 is oriented (works for R6 and R15).
local function jointRotate(joint: Motor6D, rot: CFrame)
	local c0rot = joint.C0 - joint.C0.Position
	joint.Transform = c0rot:Inverse() * rot * c0rot
end

local function findJoint(character: Model, names: { string }): Motor6D?
	for _, name in ipairs(names) do
		local j = character:FindFirstChild(name, true)
		if j and j:IsA("Motor6D") then
			return j
		end
	end
	return nil
end

function Float.Start(character: Model, duration: number, tier: number): Handle?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return nil
	end

	local rightShoulder = findJoint(character, { "RightShoulder", "Right Shoulder" })
	local leftShoulder = findJoint(character, { "LeftShoulder", "Left Shoulder" })
	local neck = findJoint(character, { "Neck" })

	local maxHeight = if tier >= 4 then 6.0 elseif tier >= 3 then 4.2 else 0
	local riseEnd = duration * 0.3
	local fallStart = duration * 0.86

	local baseCF = hrp.CFrame
	local basePos = baseCF.Position
	local baseYaw = select(2, baseCF:ToOrientation())
	local t = 0
	local alive = true
	local height = 0

	local wasPlatform = hum.PlatformStand
	hum.PlatformStand = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	local stepConn: RBXScriptConnection
	local poseConn: RBXScriptConnection

	local function poseWeight(): number
		local inW = Kit.Ease.OutCubic(Kit.Span(t, 0.05, 0.5))
		local outW = 1 - Kit.Ease.InCubic(Kit.Span(t, fallStart, duration))
		return math.min(inW, outW)
	end

	stepConn = RunService.RenderStepped:Connect(function(dt: number)
		if not alive then
			return
		end
		t += dt
		-- height profile: punchy rise with overshoot, hover with bob, soft landing
		local rise = Kit.Ease.OutBack(Kit.Span(t, 0, riseEnd), 1.2)
		local fall = Kit.Ease.InCubic(Kit.Span(t, fallStart, duration))
		local bob = math.sin(t * 2.4) * 0.35 * rise
		height = maxHeight * rise * (1 - fall) + bob * (1 - fall)

		local spin = (t - riseEnd) * 0.45 -- slow cinematic turn once airborne
		spin = if t > riseEnd then spin else 0
		local lean = math.rad(-6) * rise * (1 - fall) -- slight back lean, chest open

		hrp.CFrame = CFrame.new(basePos + Vector3.new(0, height, 0))
			* CFrame.fromOrientation(0, baseYaw + spin, 0)
			* CFrame.Angles(lean, 0, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)

	poseConn = RunService.Stepped:Connect(function()
		if not alive then
			return
		end
		local w = poseWeight()
		if maxHeight <= 0 then
			w *= 0.35 -- lower tiers: a small cheer, feet stay down
		end
		local raise = math.rad(155) * w
		local flare = math.rad(-18) * w -- arms slightly back
		local pulse = math.sin(t * 5.0) * math.rad(4) * w
		if rightShoulder then
			jointRotate(rightShoulder, CFrame.Angles(flare, 0, raise + pulse))
		end
		if leftShoulder then
			jointRotate(leftShoulder, CFrame.Angles(flare, 0, -(raise + pulse)))
		end
		if neck then
			jointRotate(neck, CFrame.Angles(math.rad(22) * w, 0, 0))
		end
	end)

	local handle = {}

	function handle.Stop(_self: Handle)
		if not alive then
			return
		end
		alive = false
		stepConn:Disconnect()
		poseConn:Disconnect()
		if rightShoulder then
			rightShoulder.Transform = CFrame.identity
		end
		if leftShoulder then
			leftShoulder.Transform = CFrame.identity
		end
		if neck then
			neck.Transform = CFrame.identity
		end
		if hrp.Parent then
			hrp.CFrame = CFrame.new(basePos) * CFrame.fromOrientation(0, baseYaw, 0)
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
		hum.PlatformStand = wasPlatform
	end

	function handle.Height(_self: Handle): number
		return height
	end

	return (handle :: any) :: Handle
end

return Float
