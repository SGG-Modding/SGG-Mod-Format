ModUtil.RegisterMod( "GodAmongFish" )

local config = {
	PerfectInterval = 4,
	GoodInterval = 6,
	WayLateInterval = 8,
	MaxFakeDunks = 0,
	FishingPointChance = 1,
	RequiredMinRoomsSinceFishingPoint = 1,
	ClearFishingPointRequirements = true,
	GiveUnlimitedSkeletalLure = true,
	GiveHugeCatch = true
}

ModUtil.LoadOnce( function()
	ModUtil.MapSetTable( FishingData, {
		NumFakeDunks = { Max = config.MaxFakeDunks },
		PerfectInterval = config.PerfectInterval,
		GoodInterval = config.GoodInterval,
		WayLateInterval = config.WayLateInterval,
	})
	for k,v in pairs(RoomSetData) do
		local room = ModUtil.SafeGet( RoomSetData, {k,"FishingPointChance"})
		if room then
			if config.ClearFishingPointRequirements then
				ModUtil.SafeSet( v, {"FishingPointRequirements"}, {} )
			end
			ModUtil.MapSetTable( v, {
				FishingPointChance = config.FishingPointChance,
				FishingPointRequirements = {
					RequiredMinRoomsSinceFishingPoint = config.RequiredMinRoomsSinceFishingPoint,
				},
			})
			OverwriteTableKeys( RoomData, v )
		end
	end
end)

ModUtil.WrapBaseFunction( "StartNewRun", function( StartNewRun, ... )
	local ret = StartNewRun( ... )
	if config.GiveUnlimitedSkeletalLure then
		local traitData = GetProcessedTraitData({ Unit = ret.Hero, TraitName = "TemporaryForcedFishingPointTrait", Rarity = "Common" })
		traitData.RemainingUses = math.inf
		TraitData[traitData.Name].RemainingUses = traitData.RemainingUses
		AddTraitToHero({ TraitData = traitData })
	end
	if config.GiveHugeCatch then
		AddTraitToHero({ TraitData = GetProcessedTraitData({ Unit = ret.Hero, TraitName = "FishingTrait", Rarity = "Legendary" }) })
	end
	return ret
end, "GodAmongFish")