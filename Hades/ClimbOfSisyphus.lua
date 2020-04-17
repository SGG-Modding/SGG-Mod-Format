-- IMPORT @ DEFAULT

ModUtil.RegisterMod("ClimbOfSisyphus")

local config = { 
	BaseGods = 4,
	MaxGodRate = 1,
	PlayerDamageMult = 1.20,
	EnemyDamageMult = 0.80,
}	
ClimbOfSisyphus.config = config

OnAnyLoad{function()
	if not CurrentRun then return end
	if not CurrentRun.TotalFalls then
		CurrentRun.TotalFalls = 0
		CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
	end
end}

function ClimbOfSisyphus.EndFallFunc( currentRun, exitDoor)
	AddInputBlock({ Name = "LeaveRoomPresentation" })
	ToggleControl({ Names = { "AdvancedTooltip", }, Enabled = false })

	HideCombatUI()
	LeaveRoomAudio( currentRun, exitDoor )
	wait(0.1)

	AllowShout = false

	RemoveInputBlock({ Name = "LeaveRoomPresentation" })
	ToggleControl({ Names = { "AdvancedTooltip", }, Enabled = true })
end
ModUtil.GlobalisePath("ClimbOfSisyphus.EndFallFunc")

function ClimbOfSisyphus.RunFall( currentRun, door )
	CurrentRun.RoomCreations = {}
    CurrentRun.BlockedEncounters = {}
    CurrentRun.ClosedDoors = {}
    CurrentRun.CompletedStyxWings = 0
    CurrentRun.BiomeRoomCountCache = {}
    CurrentRun.RoomCountCache = {}
    CurrentRun.RoomHistory = {}
    CurrentRun.EncountersCompletedCache = {}
    CurrentRun.EncountersOccuredCache = {}
    CurrentRun.EncountersOccuredBiomedCache = {}
	UpdateRunHistoryCache( currentRun )
	door.Room = CreateRoom( RoomData["RoomOpening"] )
	door.ExitFunctionName = ModUtil.JoinPath("ClimbOfSisyphus.EndFallFunc")
	door.Room.EntranceDirection = false
	currentRun.CurrentRoom.ExitFunctionName = nil
	currentRun.CurrentRoom.ExitDirection = door.Room.EntranceDirection
	currentRun.CurrentRoom.SkipLoadNextMap = false
	CurrentRun.TotalFalls = CurrentRun.TotalFalls + 1
	CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
end

ModUtil.WrapBaseFunction("RunShopGeneration",function(baseFunc,currentRoom,...)
	if currentRoom.Name == "RoomOpening" then
		currentRoom.Flipped = false
	end
	baseFunc(currentRoom,...)
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("LeaveRoom",function(baseFunc,currentRun,door)
	if currentRun.CurrentRoom.EntranceFunctionName == "RoomEntranceHades" then
		local screen = ModUtil.Hades.NewMenuYesNo(
			"ClimbOfSisyphusExitMenu", 
			function()
				baseFunc(currentRun,door)
			end, 
			function() end,
			function()
				ClimbOfSisyphus.RunFall( currentRun, door )
			end,
			function() end,
			"Endless Calling",
			"Go back to Tartarus to climb once more?",
			" Fall ",
			" Escape ",
			"EasyModeIcon",2.25
		)
	else
		baseFunc(currentRun,door)
	end
end, ClimbOfSisyphus)

ModUtil.BaseOverride("ReachedMaxGods",function(baseFunc,excludedGods)
	excludedGods = excludedGods or {}
	local maxLootTypes = config.BaseGods + config.MaxGodRate * CurrentRun.TotalFalls
	local gods = ShallowCopyTable( excludedGods )
	for i, godName in pairs(GetInteractedGodsThisRun()) do
		if not Contains( gods, godName ) then
			table.insert( gods, godName )
		end
	end
	return TableLength( gods ) >= maxLootTypes
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("Damage", function(baseFunc, victim, triggerArgs)
	if triggerArgs.DamageAmount and victim == CurrentRun.Hero then
		triggerArgs.DamageAmount = triggerArgs.DamageAmount * math.pow(config.PlayerDamageMult,CurrentRun.TotalFalls)
	end
	baseFunc( victim, triggerArgs )
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("DamageEnemy", function(baseFunc, victim, triggerArgs)
	if triggerArgs.DamageAmount then
		triggerArgs.DamageAmount = triggerArgs.DamageAmount * math.pow(config.EnemyDamageMult,CurrentRun.TotalFalls)
	end
	baseFunc( victim, triggerArgs )
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("GetBiomeDepth", function(baseFunc, currentRun, ...)
	if currentRun.MetaDepth then
		return currentRun.MetaDepth + baseFunc( currentRun, ...)
	end
	return baseFunc( currentRun )
end, ClimbOfSisyphus)
