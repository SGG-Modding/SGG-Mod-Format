if ModUtil.Pyre then 
	
	if CampaignStartup then
		ModUtil.Pyre.Gamemode = "Campaign"
		ModUtil.Pyre.Campaign = {}
	else
		ModUtil.Pyre.Gamemode = "Versus"
		ModUtil.Pyre.Versus = {}
	end
	
end