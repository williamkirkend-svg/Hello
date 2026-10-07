-- Cursed Dodgeball: every tunable number lives here (see DESIGN.md). Pure data, no Roblox requires.
local Config = {}

Config.Players = {
	Max = 20, -- launch server size
	Min = 6, -- minimum to start a show
	SmallShowBelow = 6, -- below this many at show start the show collapses to two rounds
}

Config.Show = {
	Intermission = 20,
	Replay = 8,
	Crowning = 15,
	Rounds = {
		{ Cap = 90, CutTo = 8 },
		{ Cap = 60, CutTo = 4 },
		{ Cap = 45, CutTo = 1 }, -- the final: last one standing
	},
	SmallRounds = {
		{ Cap = 60, CutTo = 3 },
		{ Cap = 45, CutTo = 1 },
	},
	FloodSpeed = 2, -- studs per second the paint edge moves inward at the buzzer
	GhostThrows = 1, -- plain-ball throws a Ghost gets per round
}

Config.Court = {
	Rounds = {
		{ Length = 70, Width = 50 },
		{ Length = 48, Width = 36 },
		{ Length = 30, Width = 24 },
	},
	CentreCircle = 10,
	PitDepth = 8,
	RingWidth = 6,
	StandRows = 5,
	RowRise = 1.5,
	RowDepth = 3,
	KerbHeight = 1,
	BallRollBack = 2, -- seconds before a ball outside the kerb rolls back in
}

Config.Throw = {
	QuickSpeed = 60,
	ChargedSpeed = 110,
	ChargeTime = 0.8,
	HoldLimit = 8,
	Cooldown = 0.3,
	MaxOriginError = 6, -- studs between the client's claimed origin and the server's position
	Gravity = 12, -- studs per second squared applied to lobbed (long) throws
	LobDistance = 30, -- throws longer than this arc under gravity
	HitRadius = 2.5,
	PickupRadius = 3,
}

Config.Catch = {
	QuickWindow = 0.25,
	ChargedWindow = 0.15,
	ShieldSeconds = 3,
}

Config.Movement = {
	RunSpeed = 16,
	SprintMultiplier = 1.5,
	StaminaDrainSeconds = 4,
	StaminaRefillSeconds = 3,
	DodgeDistance = 8,
	DodgeSeconds = 0.2,
	DodgeCost = 0.25,
	DodgeCooldown = 0.8,
	AirDodgesPerJump = 1,
}

Config.Balls = {
	Rounds = {
		{ Total = 8, Plain = 4, Cursed = 4 }, -- 3 drawn + 1 Wildcard
		{ Total = 6, Plain = 1, Cursed = 5 },
		{ Total = 4, Plain = 0, Cursed = 4 },
	},
	MachineInterval = 20, -- seconds between replacement cursed balls in rounds 1 and 2
}

Config.Targeting = {
	MaxRange = 90,
	MaxAngle = math.rad(60),
}

return Config
