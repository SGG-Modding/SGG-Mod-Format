ModUtil.RegisterMod( "GodAmongFish" )

local config = {
	PerfectInterval = 4,
	GoodInterval = 6,
	WayLateInterval = 8,
	MaxFakeDunks = 0,
	FishingPointChance = 1,
	RequiredMinRoomsSinceFishingPoint = 1,
}

ModUtil.LoadOnce( function()
	ModUtil.MapSetTable( FishingData, {
		NumFakeDunks = { Max = config.MaxFakeDunks },
		PerfectInterval = config.PerfectInterval,
		GoodInterval = config.GoodInterval,
		WayLateInterval = config.WayLateInterval,
	})
	for k,v in pairs(RoomSetData) do
		local c = "Base"..k
		if k == "Base" then
			c = "BaseRoom"
		end
		local room = ModUtil.SafeGet( RoomData, {c,"FishingPointChance"})
		if room then
			ModUtil.SafeSet( RoomData, {c,"FishingPointRequirements","RequiredCosmetics"}, {} )
			ModUtil.MapSetTable( RoomData , {
				[c]={
						FishingPointChance = config.FishingPointChance,
						FishingPointRequirements = {
							RequiredMinRoomsSinceFishingPoint = config.RequiredMinRoomsSinceFishingPoint,
						},
					}
			})
		end
		OverwriteTableKeys( RoomData, RoomSetData[k] )
	end
end)