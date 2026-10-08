-- Cursed Dodgeball movement tunables. Every number in movement-design.md lives here and nowhere else.
-- Speeds in studs/s, accelerations in studs/s^2, times in seconds, angles in degrees unless noted.
-- Arena values: toned down from the references so the court stays a readable PvP space.
local C = {}

-- Speed and momentum
C.JogSpeed = 16
C.SprintSpeed = 23
C.HardCap = 28
C.SprintRamp = 12 -- studs/s^2 while ramping from jog to sprint
C.SprintRelease = 20 -- studs/s^2 back down to jog when sprint is released
C.OverspeedDecayGround = 5
C.OverspeedDecayAir = 2
C.GroundAccel = 90
C.GroundDecel = 70
C.AirAccel = 35
C.HardTurnAngle = 110
C.HardTurnKeep = 0.6
C.HardTurnMinSpeed = 8
C.BoostSlide = 3
C.BoostWallJump = 2
C.BoostWallRun = 1

-- Stamina
C.StaminaDrainSeconds = 4
C.StaminaRefillSeconds = 3
C.StaminaRefillDelay = 0.4
C.DashCost = 0.25

-- Jumping
C.Gravity = 196.2
C.JumpHeight = 7.2
C.FallGravityMult = 1.3
C.JumpCutMult = 1.8 -- gravity while rising with jump released: short hops
C.CoyoteTime = 0.12
C.JumpBuffer = 0.12
C.DoubleJumpScale = 0.8 -- fraction of a normal jump's launch speed
C.DoubleJumps = 1

-- Wall run (natural)
C.WallRunMinSpeed = 14
C.WallRunReach = 2.5
C.WallRunMinHeight = 6
C.WallRunMaxAngle = 60 -- travel within this many degrees of parallel
C.WallRunMaxNormalY = 0.3 -- surface normal Y below this counts as a wall
C.WallRunLift = 6
C.WallRunGravity = 0.15
C.WallRunMaxSink = 12
C.WallRunMaxTime = 1.0
C.WallRunStick = 2
C.WallRunRegrabLockout = 0.35

-- Wall jump
C.WallJumpAway = 22
C.WallJumpUp = 40
C.WallJumpKeep = 0.75

-- Slide
C.SlideMinSpeed = 18
C.SlideFriction = 12
C.SlideMaxTime = 0.9
C.SlideEndSpeed = 12
C.SlideHipDrop = 1.1

-- Dash (the dodge)
C.DashDistance = 8
C.DashSeconds = 0.2
C.DashCooldown = 0.8
C.AirDashesPerJump = 1

-- Landing (fall speed thresholds, studs/s downward)
C.LandMedium = 35
C.LandHeavy = 60
C.LandRollMinSpeed = 14
C.LandLightTime = 0.12
C.LandMediumTime = 0.22
C.LandHeavyTime = 0.35
C.LandRollTime = 0.4
C.LandHeavySlow = 0.5 -- speed multiplier during a heavy landing

-- Mantle
C.MantleMaxHeight = 3.5
C.MantleTime = 0.3

-- Facing
C.TurnRate = 720 -- degrees per second
C.BankMax = 0.3 -- radians of lean into turns

-- Camera
C.ShoulderX = 1.75
C.ShoulderY = 0.6
C.ShoulderSwapTime = 0.3
C.ZoomMin = 8
C.ZoomMax = 14
C.FovBase = 70
C.FovMax = 78
C.FovKickDash = 4
C.FovKickWallJump = 3
C.FovKickDoubleJump = 2
C.WallRunRoll = 2.5 -- degrees
C.HeavyLandBump = 0.3

-- VFX
C.SpeedLinesStart = 21
C.SpeedLinesMaxAlpha = 0.35
C.WindStreakStart = 19
C.LimbTrailStart = 22

-- Networking
C.StateSendRate = 15 -- per second
C.ServerSpeedLimit = 40 -- sanity check: sustained horizontal speed above this is corrected

return C
