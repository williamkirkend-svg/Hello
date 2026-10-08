-- Cursed Dodgeball movement tunables. Every number in movement-design.md lives here and nowhere else.
-- Speeds in studs/s, accelerations in studs/s^2, times in seconds, angles in degrees unless noted.
-- Original parkour values (owner reverted the toned-down arena pass on 8 Oct 2026).
local C = {}

-- Speed and momentum
C.JogSpeed = 16
C.SprintSpeed = 26
C.HardCap = 36
C.SprintRamp = 14 -- studs/s^2 while ramping from jog to sprint
C.SprintRelease = 20 -- studs/s^2 back down to jog when sprint is released
C.OverspeedDecayGround = 4
C.OverspeedDecayAir = 1.5
C.GroundAccel = 90
C.GroundDecel = 70
C.AirAccel = 35
C.HardTurnAngle = 110
C.HardTurnKeep = 0.6
C.HardTurnMinSpeed = 8
C.BoostSlide = 5
C.BoostWallJump = 3
C.BoostWallRun = 2

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
C.DoubleJumpScale = 1.0 -- fraction of a normal jump's launch speed (full height)
C.DoubleJumps = 1
C.DoubleJumpFlip = true -- a front flip with a tuck
C.DoubleJumpFlipTime = 0.45

-- Wall run (natural)
C.WallRunMinSpeed = 14
C.WallRunReach = 2.5
C.WallRunMinHeight = 6
C.WallRunMaxAngle = 60 -- travel within this many degrees of parallel
C.WallRunMaxNormalY = 0.3 -- surface normal Y below this counts as a wall
C.WallRunLift = 6
C.WallRunGravity = 0.06 -- fraction of gravity: a full 1.6 s run drops about 3 studs
C.WallRunMaxSink = 5
C.WallRunMaxTime = 1.6
C.WallRunStick = 2
C.WallRunRegrabLockout = 0.35

-- Wall jump
C.WallJumpAway = 28
C.WallJumpUp = 46
C.WallJumpKeep = 0.8

-- Slide
C.SlideMinSpeed = 18
C.SlideFriction = 10
C.SlideMaxTime = 1.1
C.SlideEndSpeed = 12
C.SlideHipDrop = 1.2

-- Dash (the dodge)
C.DashDistance = 8
C.DashSeconds = 0.2
C.DashCooldown = 0.8
C.AirDashesPerJump = 1

-- Landing (fall speed thresholds, studs/s downward)
C.LandMedium = 40
C.LandHeavy = 75
C.LandRollMinSpeed = 14
C.LandLightTime = 0.12
C.LandMediumTime = 0.25
C.LandHeavyTime = 0.4
C.LandRollTime = 0.5
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
C.FovMax = 84
C.FovKickDash = 8
C.FovKickWallJump = 6
C.FovKickDoubleJump = 3
C.WallRunRoll = 2.5 -- degrees
C.HeavyLandBump = 0.3

-- VFX
C.SpeedLinesStart = 22
C.SpeedLinesMaxAlpha = 0.6
C.WindStreakStart = 20
C.LimbTrailStart = 24

-- Networking
C.StateSendRate = 15 -- per second
C.ServerSpeedLimit = 40 -- sanity check: sustained horizontal speed above this is corrected

return C
