-- IMPORT @ DEFAULT

ModUtil.RegisterMod("BottleFountain")

local config = {
	debug = false,
	StartBottles = {1,1,1},
	NectarCost = 1,
}
BottleFountain.config = config

function BottleFountain.SetupBottles()
	if CurrentRun.FountainBottles == nil then CurrentRun.FountainBottles = config.StartBottles end
end

function BottleFountain.HasBottles( amount )
	BottleFountain.SetupBottles()
	return #CurrentRun.FountainBottles >= amount
end

function BottleFountain.ConsumeBottle( amount )
	BottleFountain.SetupBottles()
	for i = 1, amount do
		BottleFountain.DoHeal(table.remove(CurrentRun.FountainBottles))
	end
	if config.debug then ModUtil.Hades.PrintStack("Bottles "..#CurrentRun.FountainBottles) end
end

function BottleFountain.CollectBottle( amount, healFraction )
	BottleFountain.SetupBottles()
	for i = 1, amount do
		table.insert(CurrentRun.FountainBottles,healFraction)
	end
	if config.debug then ModUtil.Hades.PrintStack("Bottles "..#CurrentRun.FountainBottles) end
end

function BottleFountain.DoHeal( healFraction )
	healFraction = healFraction * CalculateHealingMultiplier()
	Heal( CurrentRun.Hero, { HealFraction = healFraction, SourceName = "BottleFountain" } )
	thread(UpdateHealthUI)
end

ModUtil.WrapBaseFunction( "BeginOpeningCodex", function(baseFunc, ... )
	if not CanOpenCodex() and not AreScreensActive() and IsInputAllowed({}) then
		if CurrentRun.Hero.MaxHealth > CurrentRun.Hero.Health then
			wait(0.2)
			BottleFountain.SetupBottles()
			if BottleFountain.HasBottles( 1 ) then
				BottleFountain.ConsumeBottle( 1 )
			end
			wait(0.2)
		end
	end
	return baseFunc(...)
end, BottleFountain)

ModUtil.WrapBaseFunction( "Heal", function(baseFunc, victim, triggerArgs)
	if victim == CurrentRun.Hero then
		if triggerArgs.SourceName == "HealthFountain" and triggerArgs.HealFraction ~= 0 and HasResource( "GiftPoints", config.NectarCost ) then
			local bottleChose = false
			local screen = ModUtil.Hades.NewMenuYesNo( 
				"BottleFountainGet", 
				function()
					if bottleChose then return end
					baseFunc(victim, triggerArgs)
					thread(UpdateHealthUI)
				end,
				ModUtil.Hades.DimMenu,
				function()
					SpendResource( "GiftPoints", config.NectarCost, "BottleFountain" )
					BottleFountain.CollectBottle( 1, triggerArgs.HealFraction / CalculateHealingMultiplier() )
					bottleChose = true
				end,
				function() end,
				"Bottled Fountain Vigor",
				"Bottle up at the cost of nectar or drink now?",
				"Bottle Up",
				"Drink",
				"GiftIcon",1.25
			)
			return
		end
	end
	return baseFunc(victim, triggerArgs)
end, BottleFountain)