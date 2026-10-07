-- Cursed Dodgeball bootstrap: build the grey-box arena, start the show loop, start the balls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("CursedDodgeball"):WaitForChild("Config"))
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local ShowServer = require(script.Parent:WaitForChild("ShowServer"))
local BallServer = require(script.Parent:WaitForChild("BallServer"))

local arena = ArenaBuilder.build(Config)
ShowServer.start(Config, arena)
BallServer.start(Config, ShowServer)
print("[CursedDodgeball] ready: " .. Config.Players.Max .. "-player show loop")
