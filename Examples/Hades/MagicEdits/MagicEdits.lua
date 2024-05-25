--[[
Mod: Magic Edits
Author: MagicGonads
		Collection of small configurable edits with no particular theme
		Proof of concept for this mod format
-]]

ModUtil.Mod.Register("MagicEdits")

local config = -- (set to nil or false to disable any of them) 
{
	AlwaysSeeChamberCount = true,	-- Always see chamber depth in the top right during runs
	AlwaysUseSpecialDoors = true,	-- Can always open special chamber doors (will still cost whatever it costs)
	CanAlwaysExitRoom = true,		-- Exit chambers early by interacting with the exit doors
	UnlockEveryCodexEntry = false,	-- Unlock every codex entry ... (will affect your save permanently!)
	AllowRespecMirror = false,		-- Always able to respec at the mirror and swap upgrades (will affect your save permanently!)
	UnlimitedGodsPerRun = true,		-- Any unlocked god can appear in the same run
	ChooseMultipleUpgrades = 1,		-- Choose multiple upgrades at any given choice (to always choose all options once put '...' instead (quotes included))
	PlayerDamageMult = 0.5,			-- Multiply damage the player recieves
	EnemyDamageMult = 1.5,			-- Multiply damage enemies recieve
	ExtraMoney = 5,					-- Global multiplier of charon coins gained
	MoneyCost = 0,					-- Global Multiplier of coin prices
	PurchaseCost = {				-- Multiplier of purchase costs (except using darkness on mirror)
		Global = 0,			
		GiftPoints = 1,		-- Nectar
		LockKeys = 0,		-- Chthonic Keys
		Gems = 0,			-- Gemstones
	},	
	GatherBonus = { 				-- Multipliers on resources gained
		Global = 3,			
		MetaPoints = 50,	-- Darkness
		GiftPoints = 5,		-- Nectar
		LockKeys = 5,		-- Chthonic Keys
		Gems = 20,			-- Gemstones
	},
	ExtraRarity = {					-- boosts to rarity (100% best rarity if 1 or more, 0 unchanged)
		Legendary = 0.65,
		Heroic = 0.65,
		Epic = 0.65,
		Rare = 0.65,
		Common = 0.65,
	}
}

local function generateFunction( value )
	if type(value) == "string" then
		return load( "local _ENV = { }; return " .. value )
	end
	return function() return value end
end

MagicEdits.Config = setmetatable( { }, { 
    __index = config,
    __newindex = function( _, key, value )
        config[ key ] = value
        if key == "ChooseMultipleUpgrades" then
            config.ChooseMultipleUpgradesFunction = generateFunction( value )
        end
    end
} )

MagicEdits.Config.ChooseMultipleUpgrades = config.ChooseMultipleUpgrades

ModUtil.Path.Wrap( "IncrementTableValue", function( base, tbl, key, amount, ... )
    if tbl and tbl == ModUtil.PathGet( "GameState.KeepsakeChambers" ) then
        DebugPrint{ Text = "(INFO) AdjustKeepsakeProgress: Adjusted keepsake progress for " .. key .. " as: " .. AdjustKeepsakeProgress.Config.Adjustment }
        return base( tbl, key, AdjustKeepsakeProgress.AdjustmentFunction( amount or 1 ) )
    end
    return base( tbl, key, amount, ... )
end, AdjustKeepsakeProgress )

if config.UnlockEveryCodexEntry then
	ModUtil.LoadOnce( function()
		if CodexStatus then
			CodexStatus.Enabled = true
			for chapterName, chapterData in pairs(Codex) do
				for entryName, entryData in pairs(Codex[chapterName].Entries) do
					UnlockCodexEntry(chapterName, entryName, 1, true )
				end
			end
		end
	end)
end

if config.AllowRespecMirror then
	OnAnyLoad{
		function()
			GameState.Flags.SwapMetaupgradesEnabled = true
		end
	}
end

if config.GatherBonus then
	ModUtil.Path.Wrap("AddResource", function( base, name, amount, source, args )
		if source ~= "MetaPointCapRefund" then
			if amount then
				if config.GatherBonus[name] then
					return base( name, config.GatherBonus[name]*amount, source, args )
				elseif config.GatherBonus.Global then
					return base( name, config.GatherBonus.Global*amount, source, args )
				end
			end
		end
		base( name, amount, source, args )
	end, MagicEdits)
end

if config.PurchaseCost then
	ModUtil.Path.Wrap( "HasResource", function( base, name, amount )
		if name ~= "MetaPoints" then
			if amount then
				if config.PurchaseCost[name] then
					return base( name, config.PurchaseCost[name]*amount)
				elseif config.PurchaseCost.Global then
					return base( name, config.PurchaseCost.Global*amount)
				end
			end
		end
		return base( name, amount )
	end, MagicEdits)
	
	ModUtil.Path.Wrap( "SpendResource", function( base, name, amount, source, args )
		if amount then
			if config.PurchaseCost[name] then
				return base( name, config.PurchaseCost[name]*amount, source, args)
			elseif config.PurchaseCost.Global then
				return base( name, config.PurchaseCost.Global*amount, source, args)
			end
		end
		return base( name, amount )
	end, MagicEdits)
end

if config.MoneyCost then
	ModUtil.Path.Wrap( "SpendMoney", function(base, amount, source )
		if amount then
			return base( config.MoneyCost*amount, source )
		end
		return base( amount, source )
	end, MagicEdits)
end

if config.ChooseMultipleUpgrades then
	ModUtil.Path.Wrap( "CloseUpgradeChoiceScreen", function( base, screen, button )
		CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = CurrentRun.Hero.UpgradeChoicesSinceMenuOpened - 1
		if CurrentRun.Hero.UpgradeChoicesSinceMenuOpened < 1 then
			base( screen, button )
		end
	end, MagicEdits)

	ModUtil.Path.Wrap( "CreateBoonLootButtons", function( base, lootData)
		if lootData.UpgradeOptions == nil then
			SetTraitsOnLoot( lootData )
		end
		if IsEmpty( lootData.UpgradeOptions ) then
			table.insert(lootData.UpgradeOptions, { ItemName = "FallbackMoneyDrop", Type = "Consumable", Rarity = "Common" })
		end
		CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = TableLength(lootData.UpgradeOptions)
		if CurrentRun.Hero.UpgradeChoicesSinceMenuOpened then
			CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = config.ChooseMultipleUpgradesFunction( CurrentRun.Hero.UpgradeChoicesSinceMenuOpened )
		else
			CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = 1
		end
		return base( lootData )
	end, MagicEdits)
end

if config.ExtraRarity then

	ModUtil.Path.Wrap( "SetTraitsOnLoot", function( base, lootData )
		if lootData.RarityChances.Legendary and config.ExtraRarity.Legendary < 1 then
			lootData.RarityChances.Legendary = lootData.RarityChances.Legendary*(1-config.ExtraRarity.Legendary) + config.ExtraRarity.Legendary
		else
			lootData.RarityChances.Legendary = config.ExtraRarity.Legendary
		end
		if lootData.RarityChances.Heroic and config.ExtraRarity.Heroic < 1 then
			lootData.RarityChances.Heroic = lootData.RarityChances.Heroic*(1-config.ExtraRarity.Heroic) + config.ExtraRarity.Heroic
		else
			lootData.RarityChances.Heroic = config.ExtraRarity.Heroic
		end
		if lootData.RarityChances.Epic and config.ExtraRarity.Epic < 1 then
			lootData.RarityChances.Epic = lootData.RarityChances.Epic*(1-config.ExtraRarity.Epic) + config.ExtraRarity.Epic
		else
			lootData.RarityChances.Epic = config.ExtraRarity.Epic
		end
		if lootData.RarityChances.Rare and config.ExtraRarity.Rare < 1 then
			lootData.RarityChances.Rare = lootData.RarityChances.Rare*(1-config.ExtraRarity.Rare) + config.ExtraRarity.Rare
		else
			lootData.RarityChances.Rare = config.ExtraRarity.Rare
		end
		if lootData.RarityChances.Common and config.ExtraRarity.Common < 1 then
			lootData.RarityChances.Common = lootData.RarityChances.Common*(1-config.ExtraRarity.Common) + config.ExtraRarity.Common
		else
			lootData.RarityChances.Common = config.ExtraRarity.Common
		end
		base( lootData )
	end, MagicEdits)
end

if config.ExtraMoney then
	ModUtil.Path.Wrap( "AddMoney", function( base, amount, source )
		if amount then
			return base( config.ExtraMoney*amount, source )
		end
		return base( amount, source )
	end, MagicEdits)
end

if config.AlwaysSeeChamberCount then
	ModUtil.Path.Wrap( "ShowHealthUI", function( base )
		ShowDepthCounter()
		base()
	end, MagicEdits)
end

if config.AlwaysUseSpecialDoors then
	ModUtil.Path.Wrap( "CheckSpecialDoorRequirement", function( base, door )
		base( door )
		return nil
	end, MagicEdits)
end

if config.PlayerDamageMult then
	ModUtil.Path.Wrap( "Damage", function( base, victim, triggerArgs )
		if triggerArgs.DamageAmount and victim == CurrentRun.Hero then
			triggerArgs.DamageAmount = triggerArgs.DamageAmount * config.PlayerDamageMult
		end
		base( victim, triggerArgs )
	end, MagicEdits)
end
if config.EnemyDamageMult then
	ModUtil.Path.Wrap( "DamageEnemy", function( base, victim, triggerArgs )
		if triggerArgs.DamageAmount then
			triggerArgs.DamageAmount = triggerArgs.DamageAmount * config.EnemyDamageMult
		end
		base( victim, triggerArgs )
	end, MagicEdits)
end

if config.CanAlwaysExitRoom then
	ModUtil.Path.Wrap( "CheckRoomExitsReady", function( base, currentRoom )
		base( currentRoom )
		return true
	end, MagicEdits)

	ModUtil.Path.Wrap( "AttemptUseDoor", function( base, door )
		if not door.Room then
			DoUnlockRoomExits( CurrentRun, CurrentRoom )
		else
			door.ReadyToUse = true
			base( door )
		end
	end, MagicEdits)
end

if config.UnlimitedGodsPerRun then
	ModUtil.BaseOverride("ReachedMaxGods",function( excludedGods )
		return false
	end, MagicEdits)
end
