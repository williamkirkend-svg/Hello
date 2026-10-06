-- CelebrationFX.AuraMeshData: per-mesh pivot offsets and stand-in sizes for the Aura mesh pack (generated from
-- blender/aura_pack_pivots.json by scripts/gen_mesh_data.py; edit the JSON or the script, not this file).
-- Roblox centres an imported MeshPart on its bounding box. Pivots[name] is the bounding-box centre measured from
-- the mesh's authored origin, in Roblox axes (Blender x, y, z -> Roblox x, z, -y), at scale 1. AuraKit.Place adds it
-- back so a wing root, a crack root or a petal base lands where the show puts it.
-- Fallback[name] is the Part size AuraKit uses when the mesh is not imported.
local V = Vector3.new
return {
	Pivots = {
		-- v1 pack (ReplicatedStorage.FarmLasso.ClaudeCelebrationPreview.VFXMeshes), still used by the shows
		GalaxyArm = V(0.636, 0, 1.607),
		Wing = V(3.38, 1.458, 0),
		BoltA = V(-0.205, -4.969, 0),
		BoltB = V(-0.184, -4.923, 0.062),
		BeamColumn = V(0, 0.5, 0),
		GodRay = V(0, 0.5, 0),
		Slash = V(0, 0, 0.676),
		ShardA = V(0, 0.6, 0),
		ShardB = V(0, 0.25, 0),
		-- v2 pack, nominal values (replaced by the measured ones from blender/aura_pack_pivots.json)
		WingUpper = V(2, 0, 0), WingFore = V(2, 0, 0), WingPrimaries = V(2.5, 0, 0), WingUpperL = V(-2, 0, 0), WingForeL = V(-2, 0, 0), WingPrimariesL = V(-2.5, 0, 0),
		Feather = V(0, 0.6, 0), WingSilhouette = V(3.5, 0, 0), FlamePetal = V(0, 0, -2.25), RiftLip = V(0, 4.5, 0), ClockHand = V(0, 0, -2.5), ClockHandShort = V(0, 0, -1.7),
		CrackA = V(0, 0, -3), CrackB = V(0, 0, -3), CrackC = V(0, 0, -3), GrassClump = V(0, 0.6, 0), HaloCrystal = V(0, -0.9, 0), CherryTrunk = V(0, 5, 0),
		LotusPetal = V(0, 0, -1.2), IceSpike = V(0, 1.5, 0), IceSpikeCluster = V(0, 1.75, 0), GhostWisp = V(0, -0.8, 0),
	},
	Fallback = {
		WingUpper = {4, .25, 1.4}, WingFore = {4, .25, 1.6}, WingPrimaries = {5, .25, 2.4}, WingUpperL = {4, .25, 1.4}, WingForeL = {4, .25, 1.6}, WingPrimariesL = {5, .25, 2.4},
		Feather = {.4, 1.2, .05}, WingSilhouette = {7, 3.3, .1}, FlamePetalFan = {9, .08, 9}, FlamePetal = {1.1, .06, 4.5}, SunDisc = {16, .1, 16},
		ScorchRing = {6.4, .08, 6.4}, ShardChunk = {1, 1.2, .8}, ShardSliver = {.2, 2, .5}, RiftLip = {1.2, 9, .3}, RiftVoid = {5, 9, .1}, GhostWisp = {1.2, 2.6, 1.2},
		ClockRing = {12, .15, 12}, ClockHand = {.3, .1, 5}, ClockHandShort = {.3, .1, 3.4}, TickSigil = {12, .06, 12}, Numeral = {.8, .1, 1.2}, GlassShard = {.6, 2.2, .06},
		Hourglass = {.8, 1.6, .8}, CrackA = {.3, .08, 6}, CrackB = {.3, .08, 6}, CrackC = {.3, .08, 6}, Cobble = {.9, .6, .8}, GrassClump = {1, 1.2, 1}, HayStraw = {.1, .1, 1.5},
		CloudLobe = {6, 3, 4}, LightningBull = {4, 2.5, .08}, TornadoRing = {6, .1, 6}, Coin = {.7, .08, .7}, RibbonTwist = {1, 10, 1}, StarPoint = {1.4, .08, 1.4},
		PlanetRinged = {4.2, 1.8, 4.2}, LassoLoop = {6.3, .3, 6.3}, Constellation = {5.4, .4, 5.4}, LightStep = {2.4, .1, 1}, HaloCrystal = {.5, 1.8, .5}, PrismCrystal = {.9, 2.2, .9},
		Gem = {.6, .6, .6}, CherryTrunk = {1.4, 10, 1.4}, Canopy = {7, 4, 7}, Lotus = {4.8, .9, 4.8}, FlowerCrown = {1.6, .3, 1.6}, LotusPetal = {.9, .5, 2.4},
		SpikeCrown = {5.6, 1.7, 5.6}, IceSpike = {.6, 3, .6}, IceSpikeCluster = {2.4, 3.5, 2.4}, AccretionDisc = {14, .1, 14}, LensSphere = {2, 2, 2}, PortalFrame = {5, 7, .1},
	},
}
