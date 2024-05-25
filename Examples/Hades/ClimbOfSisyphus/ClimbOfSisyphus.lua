ModUtil.Mod.Register("ClimbOfSisyphus")

local config = { 
	TestMode = false,
	BaseFalls = 0,
	BaseGods = 4,
	MaxGodRate = 1,
	PlayerDamageRate = 0.05,
	PlayerDamageLimit = 10,
	PlayerDamageBase = 1,
	EnemyDamageRate = 0.2,
	EnemyDamageLimit = 0.02,
	EnemyDamageBase = 1,
	RarityRate = 0.1,
	ExchangeRate = 0.15,
	EncounterModificationEnabled = true,
	EncounterDifficultyRate = 2.35,
	EncounterMinWaveRate = 0.65,
	EncounterMaxWaveRate = 1.25,
	EncounterEnemyCapRate = 0.65,
	EncounterTypesRate = 0.20
}	
ClimbOfSisyphus.Config = config

local function falloff( x )
	return x / math.sqrt( 3 + x * x )
end

local function sfalloff( x, r, f, t )
	return f - ( f - t ) * falloff( x * r )
end

local function lerp( x, y, t, d )
	if x and y then
		return x * ( 1 - t ) + t * y
	end
	return d
end

local function maxInterpolate( x, t )
	if x and t < 1 then
		return x * ( 1 - t ) + t
	end
	return t
end

OnAnyLoad{ function( )
	if not CurrentRun then return end
	if not CurrentRun.TotalFalls then
		CurrentRun.TotalFalls = config.BaseFalls
		CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
	end
end }

function ClimbOfSisyphus.SkipToEnd( skipFight )
	if skipFight then
		ForceNextEncounter = "Empty"
	end
	return LeaveRoomWithNoDoor( nil, { NextMap = "D_Boss01" } )
end

function ClimbOfSisyphus.ShowLevelIndicator( )
	if ClimbOfSisyphus.LevelIndicator then
		Destroy{ Ids = ClimbOfSisyphus.LevelIndicator.Id }
	end
	CurrentRun.TotalFalls = CurrentRun.TotalFalls or config.BaseFalls
	if CurrentRun.TotalFalls > 0 then
		ClimbOfSisyphus.LevelIndicator = CreateScreenComponent{ Name = "BlankObstacle", Group = "LevelIndicator", X = 2*ScreenCenterX-55, Y = 110 }
		CreateTextBox{ Id = ClimbOfSisyphus.LevelIndicator.Id, Text = tostring( CurrentRun.TotalFalls ), OffsetX = -40, FontSize = 22, Color = color, Font = "AlegreyaSansSCExtraBold" }
		SetAnimation{ Name = "EasyModeIcon", DestinationId = ClimbOfSisyphus.LevelIndicator.Id, Scale = 1 }
	end
end

function ClimbOfSisyphus.EndFallFunc( currentRun, exitDoor )
	AddInputBlock{ Name = "LeaveRoomPresentation" }
	ToggleControl{ Names = { "AdvancedTooltip" }, Enabled = false }

	HideCombatUI( )
	LeaveRoomAudio( currentRun, exitDoor )
	wait( 0.1 )

	AllowShout = false

	RemoveInputBlock{ Name = "LeaveRoomPresentation" }
	ToggleControl{ Names = { "AdvancedTooltip" }, Enabled = true }
	StartNewRunPresentation( currentRun )
end

function ClimbOfSisyphus.RunFall( currentRun, door )

	currentRun.TotalFalls = currentRun.TotalFalls + 1
	currentRun.MetaDepth = GetBiomeDepth( currentRun )
	currentRun.NumRerolls = currentRun.NumRerolls + GetNumMetaUpgrades( "RerollMetaUpgrade" ) + GetNumMetaUpgrades( "RerollPanelMetaUpgrade" )
	
    currentRun.BiomeRoomCountCache = { }
    currentRun.RoomCountCache = { }
    currentRun.RoomHistory = { }
    currentRun.EncountersCompletedCache = { }
    currentRun.EncountersOccuredCache = { }
    currentRun.EncountersOccuredBiomedCache = { }
	currentRun.EncountersDepthCache = { }
	
	currentRun.DamageRecord = {}
	currentRun.HealthRecord = {}
	currentRun.ConsumableRecord = {}
	currentRun.ActualHealthRecord = {}
	currentRun.BlockTimerFlags = {}
	currentRun.WeaponsFiredRecord = {}
	
	currentRun.RoomCreations = { }
	--currentRun.LootTypeHistory = {}
	currentRun.NPCInteractions = {}
	currentRun.AnimationState = {}
	currentRun.EventState = {}
	currentRun.ActivationRecord = {}
	currentRun.SpeechRecord = {}
	currentRun.TextLinesRecord = {}
	currentRun.TriggerRecord = {}
	currentRun.UseRecord = {}
	currentRun.GiftRecord = {}
	currentRun.HintRecord = {}
	currentRun.EnemyUpgrades = {}
	currentRun.BlockedEncounters = {}
	currentRun.InvulnerableFlags = {}
	currentRun.PhasingFlags = {}
	currentRun.MoneySpent = 0
	currentRun.MoneyRecord = {}
	currentRun.ActiveObjectives = {}
	--currentRun.RunDepthCache = 1
	--currentRun.GameplayTime = 0
	currentRun.BiomeTime = 0
	currentRun.ThanatosSpawns = 0
	currentRun.SupportAINames = {}
	currentRun.ClosedDoors = {}
	currentRun.CompletedStyxWings = 0
	
	UpdateRunHistoryCache( currentRun )
	
	door.Room = CreateRoom( RoomData["RoomOpening"] )
	door.ExitFunctionName = ClimbOfSisyphus.EndFallFunc
	door.Room.EntranceDirection = nil
	currentRun.CurrentRoom.ExitFunctionName = nil
	currentRun.CurrentRoom.ExitDirection = nil
	currentRun.CurrentRoom.SkipLoadNextMap = false
end

ModUtil.Path.Wrap( "IsEncounterEligible", function( base, currentRun, room, encounterData )
	if room.ForcedReward == "Story" and encounterData.EncounterType == "NonCombat" then return true end
	return base( currentRun, room, encounterData )
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "RunShopGeneration", function( base, currentRoom, ... )
	if currentRoom.Name == "RoomOpening" or currentRoom.Name == "D_Boss01" then
		currentRoom.Flipped = false
	end
	return base( currentRoom, ... )
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "LeaveRoom", function( base, currentRun, door )
	if currentRun.CurrentRoom.EntranceFunctionName == "RoomEntranceHades" then
		local screen = ModUtil.Hades.NewMenuYesNo(
			"ClimbOfSisyphusExitMenu", 
			function( )
				base( currentRun, door )
			end, 
			function( ) end,
			function( )
				ClimbOfSisyphus.RunFall( currentRun, door )
			end,
			function( ) end,
			"Endless Calling",
			"Go back to Tartarus to climb once more?",
			" Fall ",
			" Escape ",
			"EasyModeIcon", 2.25
		)
	else
		base( currentRun, door )
	end
end, ClimbOfSisyphus )

ModUtil.Path.Override( "ReachedMaxGods", function( excludedGods )
	if not CurrentRun then return end
	if not CurrentRun.TotalFalls then
		CurrentRun.TotalFalls = config.BaseFalls
		CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
	end

	excludedGods = excludedGods or { }
	local maxLootTypes = config.BaseGods + config.MaxGodRate * CurrentRun.TotalFalls
	local gods = ShallowCopyTable( excludedGods )
	for i, godName in pairs( GetInteractedGodsThisRun( ) ) do
		if not Contains( gods, godName ) then
			table.insert( gods, godName )
		end
	end
	return TableLength( gods ) >= maxLootTypes
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "Damage", function( base, victim, triggerArgs )
	if victim == CurrentRun.Hero then
		victim.CannotDieFromDamage = config.TestMode
		triggerArgs.DamageAmount = triggerArgs.DamageAmount * sfalloff( CurrentRun.TotalFalls, config.PlayerDamageRate, config.PlayerDamageBase, config.PlayerDamageLimit )
	end
	return base( victim, triggerArgs )
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "DamageEnemy", function( base, victim, triggerArgs )
	if config.TestMode then
		victim.Health = 0
	end
	triggerArgs.DamageAmount = triggerArgs.DamageAmount * sfalloff( CurrentRun.TotalFalls, config.EnemyDamageRate, config.PlayerDamageBase, config.EnemyDamageLimit )
	return base( victim, triggerArgs )
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "GetBiomeDepth", function( base, currentRun, ... )
	if currentRun.MetaDepth then
		return currentRun.MetaDepth + base( currentRun, ...)
	end
	return base( currentRun )
end, ClimbOfSisyphus )

ModUtil.Path.Wrap( "ShowHealthUI", function( base )
	if not CurrentRun.EndingMoney then
		ClimbOfSisyphus.ShowLevelIndicator( )
	end
	return base( )
end, ClimbOfSisyphus )

if config.EncounterModificationEnabled then
	ModUtil.Path.Wrap( "GenerateEncounter", function( base, currentRun, room, encounter )
		if encounter.EncounterType ~= "Spawned" then
			if not CurrentRun.TotalFalls then
				CurrentRun.TotalFalls = config.BaseFalls
				CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
			end

			encounter.DifficultyModifier = ( encounter.DifficultyModifier or 0 ) + config.EncounterDifficultyRate * CurrentRun.TotalFalls
			if encounter.ActiveEnemyCapDepthRamp then
				encounter.ActiveEnemyCapDepthRamp = encounter.ActiveEnemyCapDepthRamp + config.EncounterDifficultyRate * CurrentRun.TotalFalls
			end
			if encounter.ActiveEnemyCapBase then
				encounter.ActiveEnemyCapBase = encounter.ActiveEnemyCapBase + config.EncounterEnemyCapRate * CurrentRun.TotalFalls
			end
			if encounter.ActiveEnemyCapMax then
				encounter.ActiveEnemyCapMax = encounter.ActiveEnemyCapMax + config.EncounterEnemyCapRate * CurrentRun.TotalFalls
			end
			
			local waveCap = #WaveDifficultyPatterns
			encounter.MinWaves = lerp( ( encounter.MinWaves or 1 ), waveCap, falloff( config.EncounterMinWaveRate * CurrentRun.TotalFalls ) )
			encounter.MaxWaves = lerp( ( encounter.MaxWaves or 1 ), waveCap, falloff( config.EncounterMaxWaveRate * CurrentRun.TotalFalls ) )
			if encounter.MinWaves > encounter.MaxWaves then encounter.MinWaves = encounter.MaxWaves end

			if encounter.MaxTypesCap then
				encounter.MaxTypes = lerp( ( encounter.MaxTypes or 1 ), encounter.MaxTypesCap, falloff( config.EncounterTypesRate * CurrentRun.TotalFalls ) )
			else
				encounter.MaxTypes = ( encounter.MaxTypes or 1 ) + config.EncounterTypesRate * CurrentRun.TotalFalls
			end
			if encounter.MaxEliteTypes then
				encounter.MaxEliteTypes = encounter.MaxEliteTypes + config.EncounterTypesRate * CurrentRun.TotalFalls
			end
		end
		
		return base( currentRun, room, encounter )
	end, ClimbOfSisyphus )
end

ModUtil.Path.Wrap( "SetTraitsOnLoot", function( base, lootData, args )
	local extraRarity = falloff( config.RarityRate * CurrentRun.TotalFalls )
	local extraReplace = falloff( config.ExchangeRate * CurrentRun.TotalFalls )
	local oldRarityChances = lootData.RarityChances
	local oldReplaceChance = CurrentRun.Hero.BoonData.ReplaceChance
	lootData.RarityChances = ShallowCopyTable( oldRarityChances )
	lootData.RarityChances.Legendary = maxInterpolate( lootData.RarityChances.Legendary, extraRarity )
	lootData.RarityChances.Heroic = maxInterpolate( lootData.RarityChances.Heroic, extraRarity )
	lootData.RarityChances.Epic = maxInterpolate( lootData.RarityChances.Epic, extraRarity )
	lootData.RarityChances.Rare = maxInterpolate( lootData.RarityChances.Rare, extraRarity )
	lootData.RarityChances.Common = maxInterpolate( lootData.RarityChances.Common, extraRarity )
	CurrentRun.Hero.BoonData.ReplaceChance = maxInterpolate( oldReplaceChance, extraReplace )
	base( lootData, args )
	lootData.RarityChances = oldRarityChances
	CurrentRun.Hero.BoonData.ReplaceChance = oldReplaceChance
end, ClimbOfSisyphus )