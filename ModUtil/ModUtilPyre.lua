if ModUtil.Pyre and not ModUtilPyre then
	
	ModUtil.RegisterMod("ModUtilPyre")
	ModUtilPyre = ModUtil.Pyre
	
	if CampaignStartup then
		ModUtil.Pyre.Gamemode = "Campaign"
		ModUtil.Pyre.Campaign = {}
	else
		ModUtil.Pyre.Gamemode = "Versus"
		ModUtil.Pyre.Versus = {}
	end
	
end