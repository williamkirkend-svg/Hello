--!strict
-- CelebrationCamera: a short cinematic for the LOCAL player only.
-- Pulls back from wherever the camera already is (no snap), orbits slowly
-- around the floating character, punches FOV and shakes on the peak, then
-- eases back to the player's own camera and returns control.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.VFXKit)

local Camera = {}

export type Handle = {
	Stop: (self: Handle) -> (),
	Peak: (self: Handle) -> (),
}

export type Options = {
	Duration: number,
	Distance: number?,
	Height: number?,
	Sweep: number?, -- radians of orbit over the hold
	PeakAt: number?, -- seconds; when the big flash lands
}

function Camera.Start(character: Model, opts: Options): Handle?
	local cam = workspace.CurrentCamera
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not hrp then
		return nil
	end

	local duration = opts.Duration
	local distance = opts.Distance or 13
	local height = opts.Height or 3.5
	local sweep = opts.Sweep or math.rad(70)
	local peakAt = opts.PeakAt or duration * 0.3

	local savedType = cam.CameraType
	local savedFOV = cam.FieldOfView
	local startCF = cam.CFrame

	-- Begin the orbit from the camera's current bearing so there is no cut.
	local rel = startCF.Position - hrp.Position
	local startAngle = math.atan2(rel.X, rel.Z)
	local startDist = math.max(Vector3.new(rel.X, 0, rel.Z).Magnitude, 4)
	local startHeight = rel.Y

	cam.CameraType = Enum.CameraType.Scriptable

	local t = 0
	local alive = true
	local shakeT = -1
	local fovPunch = 0
	local conn: RBXScriptConnection

	conn = RunService.RenderStepped:Connect(function(dt: number)
		if not alive then
			return
		end
		t += dt
		local focus = hrp.Position + Vector3.new(0, 1.5, 0)

		-- ease from the live camera into the orbit over the first 0.6 s
		local inW = Kit.Ease.InOutSine(Kit.Span(t, 0, 0.6))
		local prog = Kit.Span(t, 0.2, duration * 0.9)
		local angle = startAngle + Kit.Ease.InOutSine(prog) * sweep
		local dist = Kit.Lerp(startDist, distance, inW)
		local h = Kit.Lerp(startHeight, height, inW)

		-- slow push-in during the hold, so the shot never feels static
		dist -= Kit.Ease.InOutSine(prog) * 2.5

		local pos = focus + Vector3.new(math.sin(angle) * dist, h, math.cos(angle) * dist)
		local cf = CFrame.lookAt(pos, focus)

		if shakeT >= 0 then
			shakeT += dt
			local offset, roll = Kit.Shake(shakeT, 0.55, 0.9)
			cf = cf * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(roll * 2))
			fovPunch = Kit.Lerp(fovPunch, 0, math.min(dt * 6, 1))
		end

		cam.CFrame = cf
		cam.FieldOfView = Kit.Lerp(savedFOV, 62, inW) + fovPunch
	end)

	local handle = {}

	function handle.Peak(_self: Handle)
		shakeT = 0
		fovPunch = 22
	end

	function handle.Stop(_self: Handle)
		if not alive then
			return
		end
		alive = false
		conn:Disconnect()
		-- glide back to a sane third-person spot behind the player, then hand control back
		local focus = hrp.Position + Vector3.new(0, 1.5, 0)
		local back = CFrame.lookAt(focus + hrp.CFrame.LookVector * -startDist + Vector3.new(0, math.max(startHeight, 2), 0), focus)
		local tw = TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			CFrame = back,
			FieldOfView = savedFOV,
		})
		tw:Play()
		tw.Completed:Once(function()
			cam.CameraType = savedType
			cam.FieldOfView = savedFOV
		end)
	end

	-- auto-peak if the effect never calls it
	task.delay(peakAt, function()
		if alive and shakeT < 0 then
			handle:Peak()
		end
	end)

	return (handle :: any) :: Handle
end

return Camera
