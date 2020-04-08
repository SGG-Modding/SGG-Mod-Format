-- IMPORT @ DEFAULT

ModUtil.RegisterMod("BottleFountain")

local config = {
	debug = false,
	StartBottles = {},
}

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
	if IsScreenOpen("BottleFountainUse") then return baseFunc(...) end
	BottleFountain.SetupBottles()
	if BottleFountain.HasBottles( 1 ) then
		local screen = ModUtil.Hades.NewMenuYesNo( 
			"BottleFountainUse", 
			nil,
			ModUtil.Hades.DimMenu,
			function()
				BottleFountain.ConsumeBottle( 1 )
			end,
			function()
				thread(function()
					wait(0.05)
					OpenCodexScreen()
				end)
			end,
			"Bottled Fountain Vigor",
			"Drink a bottle or open Codex?",
			"Drink".." ("..#CurrentRun.FountainBottles..")",
			"Codex",
			"GiftIcon",1.25
		)
		return false
	end
	return baseFunc(...)
end, BottleFountain)

ModUtil.WrapBaseFunction( "Heal", function(baseFunc, victim, triggerArgs)
	if victim == CurrentRun.Hero then
		if triggerArgs.SourceName == "HealthFountain" and triggerArgs.HealFraction ~= 0 and HasResource( "GiftPoints", 1 ) then
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
					SpendResource( "GiftPoints", 1, "BottleFountain" )
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