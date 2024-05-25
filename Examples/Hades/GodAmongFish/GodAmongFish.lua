ModUtil.Mod.Register( "GodAmongFish" )

local config = {
	PerfectInterval = 4,
	GoodInterval = 6,
	WayLateInterval = 8,
	MaxFakeDunks = 0,
	FishingPointChance = 1,
	RequiredMinRoomsSinceFishingPoint = 1,
	ClearFishingPointRequirements = true,
	GiveUnlimitedSkeletalLure = false,
	GiveHugeCatch = false
}

ModUtil.LoadOnce( function( )
	ModUtil.Table.Merge( FishingData, {
		NumFakeDunks = { Max = config.MaxFakeDunks },
		PerfectInterval = config.PerfectInterval,
		GoodInterval = config.GoodInterval,
		WayLateInterval = config.WayLateInterval,
	})
	for k, v in pairs( RoomData ) do
		if v[ "FishingPointChance" ] then
			if config.ClearFishingPointRequirements then
				v["FishingPointRequirements"] = { }
			end
			ModUtil.Table.Merge( v, {
				FishingPointChance = config.FishingPointChance,
				FishingPointRequirements = {
					RequiredMinRoomsSinceFishingPoint = config.RequiredMinRoomsSinceFishingPoint,
				},
			} )
		end
	end
end)

ModUtil.Path.Wrap( "StartNewRun", function( StartNewRun, ... )
	local currentRun = StartNewRun( ... )
	if config.GiveUnlimitedSkeletalLure then
		local traitData = GetProcessedTraitData{ Unit = currentRun.Hero, TraitName = "TemporaryForcedFishingPointTrait", Rarity = "Common" }
		traitData.RemainingUses = math.inf
		TraitData[traitData.Name].RemainingUses = traitData.RemainingUses
		AddTraitToHero{ TraitData = traitData }
	end
	if config.GiveHugeCatch then
		AddTraitToHero{ TraitData = GetProcessedTraitData{ Unit = currentRun.Hero, TraitName = "FishingTrait", Rarity = "Legendary" } }
	end
	return currentRun
end, "GodAmongFish" )