-- StarterPlayerScripts.GameSounds: everything that makes a sound without a patch to the live scripts (Oct 7 2026).
-- Music, ambience and the fountain; random animal calls from animals near you; herd joins (the Herd attribute);
-- footsteps by floor material for every character; hover / click / open / close / tab for every button and panel;
-- selling (the Sold event); quest flashes; the Music / SFX / Ambience settings panel. The lasso loop itself (charge,
-- zones, throw, reveal, tug, catch, bag) is one-line SoundKit calls inside FarmLassoClient: see docs/sound-install.md.
-- Each block below is independent and pcall-guarded so one missing object never silences the rest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FL = ReplicatedStorage:WaitForChild("FarmLasso")
local Snd = require(FL:WaitForChild("SoundKit"))
local Cues = Snd.Cues

local function guard(name, fn)
	local ok, err = pcall(fn)
	if not ok then warn("[GameSounds] " .. name .. ": " .. tostring(err)) end
end
local function letters(s)
	return (tostring(s):gsub("[^%a]", "")):lower()
end

---------------------------------------------------------------- species -> cue
local speciesCue, speciesByLast = {}, {}
for _, sp in Cues.Species or {} do
	speciesCue[letters(sp)] = "Animal" .. sp
	local last = sp:match("(%u%l*)$") or sp
	speciesByLast[last:lower()] = "Animal" .. sp
end
-- the cue for a species key ("Chick", "Puddle Duck", "PuddleDuck", "Spotted Pig" ...)
-- strict = exact or last-word matches only (world scanning: a "PigPen" must not oink)
local function animalCue(key, strict)
	local k = letters(key)
	if speciesCue[k] then return speciesCue[k] end
	for last, cue in speciesByLast do
		if k:sub(-#last) == last then return cue end
	end
	if not strict then
		for name, cue in speciesCue do
			if k:find(name, 1, true) then return cue end
		end
	end
	return "AnimalGeneric"
end
local function speciesPitch(key)
	local k = letters(key)
	if k == "chick" then return 1.6 end
	return nil
end
-- play a species call from a part / position. o: Volume, Pitch (x), Short (true = the hooked reaction, cut to .4 s)
local function animalCall(key, at, o)
	o = o or {}
	local cue = animalCue(key)
	local function go()
		local h = Snd.Play(cue, {At = at, Volume = o.Volume, Pitch = (speciesPitch(key) or 1) * (o.Pitch or 1)})
		if h and o.Short then task.delay(.4, function() h:Stop(.08) end) end
		return h
	end
	if o.Delay then task.delay(o.Delay, go) return nil end
	return go()
end

---------------------------------------------------------------- settings (volumes), saved through the server when it listens
guard("settings", function()
	local DEFAULTS = {Music = 1, SFX = 1, Ambience = 1}
	local function load()
		local raw = player:GetAttribute("SoundVolumes")
		if type(raw) == "string" and raw ~= "" then
			local ok, tbl = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(tbl) == "table" then Snd.LoadVolumes(tbl) return end
		end
		Snd.LoadVolumes(DEFAULTS)
	end
	load()
	player:GetAttributeChangedSignal("SoundVolumes"):Connect(load)
	-- send changes to the server (RemoteEvent FarmLasso.SoundSettings, optional), at most once a second
	local pending = false
	Snd.OnVolumeChanged(function()
		if pending then return end
		pending = true
		task.delay(1, function()
			pending = false
			local remote = FL:FindFirstChild("SoundSettings")
			if remote and remote:IsA("RemoteEvent") then remote:FireServer(Snd.Volumes()) end
		end)
	end)
end)

---------------------------------------------------------------- music and ambience
guard("music", function()
	task.delay(1.5, function()
		Snd.Loop("MusicCountry")
		Snd.Loop("AmbBirds")
		local wind = Snd.Loop("AmbWind")
		if wind then
			task.spawn(function()
				while not wind.Done do
					wind:Set(.3 + math.random() * .7)
					task.wait(6 + math.random() * 8)
				end
			end)
		end
	end)
	-- the fountain: Config.Fountain (Position / CFrame / Vector3) or a part named Fountain in the village
	task.delay(3, function()
		local pos
		local okC, Config = pcall(require, FL:FindFirstChild("Config") or FL)
		local f = okC and type(Config) == "table" and Config.Fountain
		if typeof(f) == "Vector3" then pos = f
		elseif typeof(f) == "CFrame" then pos = f.Position
		elseif type(f) == "table" then
			local p = f.Position or f.Pos or f.Center or f.Centre
			if typeof(p) == "Vector3" then pos = p elseif typeof(p) == "CFrame" then pos = p.Position end
		end
		if not pos then
			local world = workspace:FindFirstChild("FarmLassoWorld")
			local village = world and world:FindFirstChild("VintageVillage")
			local root = village or world
			if root then
				for _, d in root:GetDescendants() do
					if d.Name:lower():find("fountain") and (d:IsA("BasePart") or d:IsA("Model")) then
						pos = d:IsA("Model") and d:GetPivot().Position or d.Position
						break
					end
				end
			end
		end
		if pos then Snd.Loop("AmbFountain", {At = pos}) end
	end)
end)

---------------------------------------------------------------- animals: random calls nearby, herd joins
guard("animals", function()
	local animals = {} -- Model -> species cue
	local function consider(inst)
		if not inst:IsA("Model") or inst:FindFirstChildOfClass("Humanoid") then return end
		local k = letters(inst.Name)
		if k == "" then return end
		local cue = animalCue(inst.Name, true)
		if cue == "AnimalGeneric" and not inst:GetAttribute("Species") then return end
		animals[inst] = inst:GetAttribute("Species") or inst.Name
	end
	local roots = {}
	local world = workspace:FindFirstChild("FarmLassoWorld")
	table.insert(roots, world or workspace)
	for _, root in roots do
		for _, d in root:GetDescendants() do consider(d) end
		root.DescendantAdded:Connect(consider)
		root.DescendantRemoving:Connect(function(d) animals[d] = nil end)
	end
	task.spawn(function()
		while true do
			task.wait(8 + math.random() * 12)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local near = {}
				for m, key in animals do
					if m.Parent then
						local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
						if p and (p.Position - hrp.Position).Magnitude < 60 then table.insert(near, {p, key}) end
					end
				end
				if #near > 0 then
					local pick = near[math.random(1, #near)]
					animalCall(pick[2], pick[1], {Volume = .3 + math.random() * .15})
				end
			end
		end
	end)
	-- herd joins: the Herd attribute ("Chick:3,Pig:1") on the player or the character
	local counts = {}
	local function parse(raw)
		local out = {}
		for key, n in tostring(raw or ""):gmatch("([^,:]+):(%d+)") do out[key] = tonumber(n) end
		return out
	end
	local function onHerd(raw, first)
		local new = parse(raw)
		if not first then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			for key, n in new do
				if n > (counts[key] or 0) then
					Snd.Play("HerdJoin", {Delay = .05})
					animalCall(key, hrp, {Volume = .8, Delay = .25})
					break
				end
			end
		end
		counts = new
	end
	local function watch(inst, first)
		onHerd(inst:GetAttribute("Herd"), first)
		inst:GetAttributeChangedSignal("Herd"):Connect(function() onHerd(inst:GetAttribute("Herd"), false) end)
	end
	watch(player, true)
	local function onChar(char) watch(char, true) end
	if player.Character then onChar(player.Character) end
	player.CharacterAdded:Connect(onChar)
end)

---------------------------------------------------------------- footsteps for every character
guard("footsteps", function()
	local GRASS = {Grass = true, LeafyGrass = true}
	local DIRT = {Ground = true, Mud = true, Sand = true, Snow = true, Fabric = true, Salt = true}
	local STONE = {Cobblestone = true, Slate = true, Concrete = true, Brick = true, Rock = true, Pebble = true, Marble = true,
		Basalt = true, Granite = true, Limestone = true, Pavement = true, Asphalt = true, Metal = true, CorrodedMetal = true,
		DiamondPlate = true, Foil = true, Glass = true, Ice = true, Glacier = true, SmoothPlastic = true, Plastic = true, Neon = true}
	local WOOD = {Wood = true, WoodPlanks = true, Cardboard = true}
	local function stepCue(material)
		local n = material.Name
		if GRASS[n] then return "StepGrass" end
		if WOOD[n] then return "StepWood" end
		if STONE[n] then return "StepStone" end
		if DIRT[n] then return "StepDirt" end
		return "StepDirt"
	end
	local walkers = {} -- character -> state
	local function track(char, isLocal)
		local hum = char:WaitForChild("Humanoid", 10)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if not hum or not hrp then return end
		local st = {Hum = hum, Hrp = hrp, Local = isLocal, Dist = 0, Vol = isLocal and 1 or .5}
		walkers[char] = st
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed and hum.FloorMaterial ~= Enum.Material.Air then
				Snd.Play(stepCue(hum.FloorMaterial), {At = hrp, Volume = st.Vol * 1.4, Pitch = .85})
				st.Dist = 0
			end
		end)
		char.AncestryChanged:Connect(function() if not char:IsDescendantOf(workspace) then walkers[char] = nil end end)
	end
	local function onPlayer(pl)
		local isLocal = pl == player
		if pl.Character then task.spawn(track, pl.Character, isLocal) end
		pl.CharacterAdded:Connect(function(c) track(c, isLocal) end)
	end
	for _, pl in Players:GetPlayers() do onPlayer(pl) end
	Players.PlayerAdded:Connect(onPlayer)
	local STRIDE = 3.6
	local me
	RunService.Heartbeat:Connect(function(dt)
		local myChar = player.Character
		me = myChar and myChar:FindFirstChild("HumanoidRootPart")
		for char, st in walkers do
			local hum, hrp = st.Hum, st.Hrp
			if hum.Parent and hrp.Parent and hum.FloorMaterial ~= Enum.Material.Air and hum.Health > 0 then
				if st.Local or (me and (hrp.Position - me.Position).Magnitude < 60) then
					local v = hrp.AssemblyLinearVelocity
					local speed = Vector3.new(v.X, 0, v.Z).Magnitude
					if speed > 2 then
						st.Dist += speed * dt
						if st.Dist >= STRIDE then
							st.Dist -= STRIDE
							local fast = math.clamp(speed / 16, .7, 1.4)
							Snd.Play(stepCue(hum.FloorMaterial), {At = hrp, Volume = st.Vol * math.clamp(speed / 16, .5, 1.2), Pitch = .9 + .15 * fast,
								Cooldown = .08})
						end
					else
						st.Dist = STRIDE * .7
					end
				end
			end
		end
	end)
end)

---------------------------------------------------------------- menus: every button and panel
guard("menus", function()
	local gui = player:WaitForChild("PlayerGui")
	local hooked = setmetatable({}, {__mode = "k"})
	local function textOf(b)
		if b:IsA("TextButton") then return b.Text end
		local l = b:FindFirstChildWhichIsA("TextLabel", true)
		return l and l.Text or ""
	end
	local function isTab(b)
		local p = b.Parent
		if not p then return false end
		local hint = (p.Name:lower():find("tab") or b.Name:lower():find("tab")) ~= nil
		if not hint then return false end
		local n = 0
		for _, s in p:GetChildren() do if s:IsA("GuiButton") then n += 1 end end
		return n >= 2
	end
	local function classify(b)
		local t = textOf(b):lower():gsub("^%s+", ""):gsub("%s+$", "")
		local n = b.Name:lower()
		if t == "x" or t == "close" or n:find("close") or (n == "x") then return "PanelClose" end
		if t:find("^need") or t:find("locked") or t == "soon" then return "NoCoins" end
		if t:find("^buy") or t:find("purchase") then return "Buy" end
		if t:find("^claim") then return "QuestComplete" end
		if t == "equipped" or t:find("^equipped") then return "UIClick" end
		if t:find("^equip") then return "Equip" end
		if t:find("^accept") or t:find("^start") then return "QuestAccept" end
		if isTab(b) then return "TabSwitch" end
		return "UIClick"
	end
	local function hookButton(b)
		if hooked[b] then return end
		hooked[b] = true
		if not Snd.Mobile then
			b.MouseEnter:Connect(function()
				if b.Active and b.Visible and b.AbsoluteSize.X > 0 then Snd.Play("UIHover") end
			end)
		end
		b.Activated:Connect(function() Snd.Play(classify(b)) end)
	end
	-- panels: a frame that covers 15 percent of the screen or more, directly under a ScreenGui, toggling Visible
	local function area(f)
		local s = f.AbsoluteSize
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		return (s.X * s.Y) / math.max(1, vs.X * vs.Y)
	end
	local function hookPanel(f)
		if hooked[f] then return end
		hooked[f] = true
		f:GetPropertyChangedSignal("Visible"):Connect(function()
			if area(f) < .15 and not f.Visible then return end
			task.defer(function()
				if area(f) < .15 then return end
				Snd.Play(f.Visible and "PanelOpen" or "PanelClose")
			end)
		end)
	end
	local function hookScreen(sg)
		if hooked[sg] then return end
		hooked[sg] = true
		sg:GetPropertyChangedSignal("Enabled"):Connect(function()
			local big = false
			for _, c in sg:GetChildren() do if c:IsA("GuiObject") and c.Visible and area(c) >= .15 then big = true break end end
			if big then Snd.Play(sg.Enabled and "PanelOpen" or "PanelClose") end
		end)
	end
	local function consider(d)
		local root = d:FindFirstAncestorOfClass("ScreenGui")
		if root and root:GetAttribute("NoUISounds") then return end -- our own settings panel plays its own
		if d:IsA("GuiButton") then hookButton(d)
		elseif d:IsA("ScreenGui") then hookScreen(d)
		elseif d:IsA("Frame") and d.Parent and d.Parent:IsA("ScreenGui") then hookPanel(d) end
	end
	for _, d in gui:GetDescendants() do consider(d) end
	gui.DescendantAdded:Connect(consider)
end)

---------------------------------------------------------------- selling and quests (events the live scripts already fire)
guard("events", function()
	local function sell()
		Snd.Play("SellShower")
		Snd.Play("SellDing", {Delay = 1.1})
		Snd.Duck("Music", .5, 2.2, .8)
	end
	local seen = {}
	local function hookRemote(r)
		if seen[r] or not r:IsA("RemoteEvent") then return end
		seen[r] = true
		if r.Name == "Sold" then
			r.OnClientEvent:Connect(sell)
		elseif r.Name == "Event" or r.Name == "Remote" or r.Name == "Client" then
			-- a multiplexed remote: (kind, data)
			r.OnClientEvent:Connect(function(kind)
				if kind == "Sold" then sell() end
			end)
		end
	end
	local function hookBindable(b)
		if seen[b] or not b:IsA("BindableEvent") then return end
		seen[b] = true
		if b.Name == "QuestFlash" then b.Event:Connect(function() Snd.Play("QuestTick") end) end
	end
	for _, d in ReplicatedStorage:GetDescendants() do hookRemote(d) hookBindable(d) end
	ReplicatedStorage.DescendantAdded:Connect(function(d) hookRemote(d) hookBindable(d) end)
end)

---------------------------------------------------------------- the settings panel (Music / SFX / Ambience sliders)
guard("panel", function()
	local gui = player:WaitForChild("PlayerGui")
	local FONT = Enum.Font.FredokaOne
	local sg = Instance.new("ScreenGui")
	sg.Name = "SoundSettings"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 50
	sg.IgnoreGuiInset = false
	sg:SetAttribute("NoUISounds", true)
	local function stroke(o, thick)
		local s = Instance.new("UIStroke")
		s.Thickness = thick or 3
		s.Color = Color3.new(1, 1, 1)
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = o
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = o
	end
	-- the toggle: a small note button (move it with the ScreenGui attribute ButtonPosition)
	local btn = Instance.new("TextButton")
	btn.Name = "SoundButton"
	btn.Size = UDim2.fromOffset(44, 44)
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = sg:GetAttribute("ButtonPosition") or UDim2.new(0, 12, 1, -12)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	btn.BackgroundTransparency = .15
	btn.Text = "♪"
	btn.Font = FONT
	btn.TextSize = 26
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = sg
	stroke(btn)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(260, 196)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -66)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	panel.BackgroundTransparency = .12
	panel.Visible = false
	panel.Parent = sg
	stroke(panel)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.Text = "SOUND"
	title.Font = FONT
	title.TextSize = 24
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.Parent = panel
	local rows = {{"Music", "MUSIC"}, {"SFX", "EFFECTS"}, {"Ambience", "AMBIENCE"}}
	local dragging
	for i, row in rows do
		local name, label = row[1], row[2]
		local y = 36 + (i - 1) * 50
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -24, 0, 18)
		l.Position = UDim2.fromOffset(12, y)
		l.BackgroundTransparency = 1
		l.Text = label
		l.Font = FONT
		l.TextSize = 16
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(230, 230, 236)
		l.Parent = panel
		local pct = l:Clone()
		pct.TextXAlignment = Enum.TextXAlignment.Right
		pct.Parent = panel
		local bar = Instance.new("TextButton")
		bar.Name = name
		bar.Text = ""
		bar.AutoButtonColor = false
		bar.Size = UDim2.new(1, -24, 0, 18)
		bar.Position = UDim2.fromOffset(12, y + 22)
		bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		bar.Parent = panel
		stroke(bar, 2)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = name == "Music" and Color3.fromRGB(255, 196, 60) or name == "SFX" and Color3.fromRGB(80, 200, 255) or Color3.fromRGB(120, 230, 120)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 12)
		fc.Parent = fill
		local function show(v)
			fill.Size = UDim2.new(v, 0, 1, 0)
			pct.Text = math.floor(v * 100 + .5) .. "%"
		end
		show(Snd.GetVolume(name))
		Snd.OnVolumeChanged(function(n, v) if n == name then show(v) end end)
		local function setFrom(x)
			local v = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
			v = math.floor(v * 20 + .5) / 20
			Snd.SetVolume(name, v)
		end
		bar.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
				dragging = setFrom
				setFrom(io.Position.X)
			end
		end)
		bar.MouseButton1Up:Connect(function()
			if name == "Music" then Snd.Play("UIClick") elseif name == "SFX" then Snd.Play("CatchPop") else Snd.Play("UIClick", {Group = "Ambience"}) end
		end)
	end
	UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then dragging(io.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = nil end
	end)
	btn.Activated:Connect(function()
		panel.Visible = not panel.Visible
		Snd.Play(panel.Visible and "PanelOpen" or "PanelClose")
	end)
	sg.Parent = gui
end)

Snd.Preload()
