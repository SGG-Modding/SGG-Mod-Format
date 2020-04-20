-- IMPORT @ DEFAULT
-- PRIORITY 150

--[[ Installation Instructions:
	Place this file in /Content/Mods/modMagicEdits/Scripts
	Add 'Import "../Mods/modMagicEdits/Scripts/modMagicEdits.lua"' to the bottom of RoomManager.lua
	Configure by changing values in the config table below
	Load/reload a save
--]]

--[[
Mod: Magic Edits
Author: MagicGonads
Touched By: TurboCop
		Collection of small configurable edits with no particular theme
		Proof of concept for this mod format
-]]

--[[ Future Ideas
	- Increase upgrade density (replace resources?)
	- No health loss on chaos chamber entrance
	- Make chaos debuff chamber numbers really small or zero / instantly remove them
	- Make Charon "chambers" numbers really large / make them permanent in a proper way
	- Keys instead of heat for heat shortcuts
]]

modMagicEdits = {}
SaveIgnores["modMagicEdits"] = true

local config = -- (set to nil or false to disable any of them) 
{
	UnlockEveryCodexEntry = false,	-- Unlock every codex entry ... (will affect your save permanently!)
	AllowRespecMirror = false,		-- Always able to respec at the mirror and swap upgrades (will affect your save permanently!)
	GatherBonus = { 				-- Multipliers on resources gained
		Enabled = false,
		Global = 3,			
		MetaPoints = 50,	-- Darkness
		GiftPoints = 5,		-- Nectar
		LockKeys = 5,		-- Chthonic Keys
		Gems = 20,			-- Gemstones
	},
	PurchaseCost = {
		Enabled = false,
		purchaseCostMultiplier = 0,
	},	-- Global multiplier of all purchase costs (except using darkness on mirror)
	ChooseMultipleUpgrades = {
		Enabled = false,
		ChooseMultipleUpgradesValue = 1,
	},	-- Choose multiple upgrades at any given choice (multiplier of available number)
	ExtraRarity = {
		Enabled = false,
		ExtraRarityValue = 0.65,
	},	-- Global boost to rarity (100% best rarity if 1 or more, 0 unchanged)
	ExtraMoney = {
		Enabled = false,
		ExtraMoneyValue = 5,
	},	-- Global multiplier of charon coins gained
	AlwaysSeeChamberCount = true,	-- Always see chamber depth in the top right during runs
	AlwaysUseSpecialDoors = false,	-- Can always open special chamber doors (will still cost whatever it costs)
	PlayerDamageMult = {
		Enabled = false,
		PlayerDamageMultValue = 0.5,
	},	-- Multiply damage the player recieves
	EnemyDamageMult = {
		Enabled = false,
		EnemyDamageMultValue = 1.5,
	},	-- Multiply damage enemies recieve
	CanAlwaysExitRoom = false,		-- Exit chambers early by interacting with the exit doors
	
}

modMagicEdits.config = config

if config.UnlockEveryCodexEntry then
	local function doUnlockEveryCodexEntry()
		if CodexStatus then
			CodexStatus.Enabled = true
			for chapterName, chapterData in pairs(Codex) do
				for entryName, entryData in pairs(Codex[chapterName].Entries) do
					UnlockCodexEntry(chapterName, entryName, 1, true )
				end
			end
		end
		doUnlockEveryCodexEntry = function() end
	end
	OnAnyLoad{ doUnlockEveryCodexEntry }
end

if config.AllowRespecMirror then
	OnAnyLoad{
		function()
			GameState.Flags.SwapMetaupgradesEnabled = true
		end
	}
end

if config.GatherBonus ~= nil and config.GatherBonus.Enabled then
	local baseAddResource = AddResource
	function AddResource( name, amount, source, args )
		if source ~= "MetaPointCapRefund" then
			if amount then
				if config.GatherBonus[name] then
					return baseAddResource( name, config.GatherBonus[name]*amount, source, args )
				elseif config.GatherBonus.Global then
					return baseAddResource( name, config.GatherBonus.Global*amount, source, args )
				end
			end
		end
		baseAddResource( name, amount, source, args )
	end
end

if config.PurchaseCost ~= nil and config.PurchaseCost.Enabled then
	local baseHasResource = HasResource
	function HasResource( name, amount )
		if name ~= "MetaPoints" then
			if amount then
				return baseHasResource( name, config.PurchaseCost.purchaseCostMultiplier*amount )
			end
		end
		return baseHasResource( name, amount )
	end
	
	local baseSpendResource = SpendResource
	function SpendResource( name, amount, source, args )
		if amount then
			return baseSpendResource( name, config.PurchaseCost*amount, source, args ) 
		end
		return baseSpendResource( name, amount, source, args ) 
	end

	local baseSpendMoney = SpendMoney
	function SpendMoney( amount, source )
		if amount then
			return baseSpendMoney( config.PurchaseCost*amount, source )
		end
		return baseSpendMoney( amount, source )
	end
end

if config.ChooseMultipleUpgrades ~= nil and config.ChooseMultipleUpgrades.Enabled then
	if config.ChooseMultipleUpgrades >= 0 then
	
		local baseCloseUpgradeChoiceScreen = CloseUpgradeChoiceScreen
		function CloseUpgradeChoiceScreen( screen, button )
			CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = CurrentRun.Hero.UpgradeChoicesSinceMenuOpened - 1
			if CurrentRun.Hero.UpgradeChoicesSinceMenuOpened < 1 then
				baseCloseUpgradeChoiceScreen( screen, button )
			end
		end

		local baseCreateBoonLootButtons = CreateBoonLootButtons
		function CreateBoonLootButtons( lootData )
			if lootData.UpgradeOptions == nil then
				SetTraitsOnLoot( lootData )
			end
			if IsEmpty( lootData.UpgradeOptions ) then
				table.insert(lootData.UpgradeOptions, { ItemName = "FallbackMoneyDrop", Type = "Consumable", Rarity = "Common" })
			end
			CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = TableLength(lootData.UpgradeOptions)
			if CurrentRun.Hero.UpgradeChoicesSinceMenuOpened then
				CurrentRun.Hero.UpgradeChoicesSinceMenuOpened=CurrentRun.Hero.UpgradeChoicesSinceMenuOpened*config.ChooseMultipleUpgradesValue
			else
				CurrentRun.Hero.UpgradeChoicesSinceMenuOpened = 1
			end
			return baseCreateBoonLootButtons( lootData )
		end 
	end
end

if config.ExtraRarity ~= nil and config.ExtraRarity.Enabled then

	local baseSetTraitsOnLoot = SetTraitsOnLoot
	function SetTraitsOnLoot( lootData )
		if lootData.RarityChances.Legendary and config.ExtraRarity.ExtraRarityValue < 1 then
			lootData.RarityChances.Legendary = lootData.RarityChances.Legendary*(1-config.ExtraRarity.ExtraRarityValue) + config.ExtraRarity.ExtraRarityValue
		else
			lootData.RarityChances.Legendary = config.ExtraRarity
		end
		if lootData.RarityChances.Heroic and config.ExtraRarity.ExtraRarityValue < 1 then
			lootData.RarityChances.Heroic = lootData.RarityChances.Heroic*(1-config.ExtraRarity.ExtraRarityValue) + config.ExtraRarity.ExtraRarityValue
		else
			lootData.RarityChances.Heroic = config.ExtraRarity.ExtraRarityValue
		end
		if lootData.RarityChances.Epic and config.ExtraRarity.ExtraRarityValue < 1 then
			lootData.RarityChances.Epic = lootData.RarityChances.Epic*(1-config.ExtraRarity.ExtraRarityValue) + config.ExtraRarity.ExtraRarityValue
		else
			lootData.RarityChances.Epic = config.ExtraRarity.ExtraRarityValue
		end
		if lootData.RarityChances.Rare and config.ExtraRarity.ExtraRarityValue < 1 then
			lootData.RarityChances.Rare = lootData.RarityChances.Rare*(1-config.ExtraRarity.ExtraRarityValue) + config.ExtraRarity.ExtraRarityValue
		else
			lootData.RarityChances.Rare = config.ExtraRarity.ExtraRarityValue
		end
		if lootData.RarityChances.Common and config.ExtraRarity.ExtraRarityValue < 1 then
			lootData.RarityChances.Common = lootData.RarityChances.Common*(1-config.ExtraRarity.ExtraRarityValue) + config.ExtraRarity.ExtraRarityValue
		else
			lootData.RarityChances.Common = config.ExtraRarity.ExtraRarityValue
		end
		baseSetTraitsOnLoot( lootData )
	end
end

if config.ExtraMoney ~= nil and config.ExtraMoney.Enabled then
	local baseAddMoney = AddMoney
	function AddMoney( amount, source )
		if amount then
			return baseAddMoney( config.ExtraMoney.ExtraMoneyValue*amount, source )
		end
		return baseAddMoney( amount, source )
	end
end

if config.AlwaysSeeChamberCount then
	local baseShowHealthUI = ShowHealthUI
	function ShowHealthUI()
		ShowDepthCounter()
		baseShowHealthUI()
	end
end

if config.AlwaysUseSpecialDoors then
	local baseCheckSpecialDoorRequirement = CheckSpecialDoorRequirement
	function CheckSpecialDoorRequirement( door )
		baseCheckSpecialDoorRequirement( door )
		return nil
	end
end

if config.PlayerDamageMult ~= nil and config.PlayerDamageMult.Enabled then
	local baseDamage = Damage
	function Damage( victim, triggerArgs )
		if triggerArgs.DamageAmount and victim == CurrentRun.Hero then
			triggerArgs.DamageAmount = triggerArgs.DamageAmount * config.PlayerDamageMult.PlayerDamageMultValue
		end
		baseDamage( victim, triggerArgs )
	end
end
if config.EnemyDamageMult ~= nil and config.EnemyDamageMult.Enabled then
	local baseDamageEnemy = DamageEnemy
	function DamageEnemy( victim, triggerArgs )
		if triggerArgs.DamageAmount then
			triggerArgs.DamageAmount = triggerArgs.DamageAmount * config.EnemyDamageMult.EnemyDamageMultValue
		end
		baseDamageEnemy( victim, triggerArgs )
	end
end

if config.CanAlwaysExitRoom then
	local baseCheckRoomExitsReady = CheckRoomExitsReady
	function CheckRoomExitsReady( currentRoom )
		baseCheckRoomExitsReady( currentRoom )
		return true
	end

	local baseAttemptUseDoor = AttemptUseDoor
	function AttemptUseDoor( door )
		if not door.Room then
			DoUnlockRoomExits( CurrentRun, CurrentRoom )
		else
			door.ReadyToUse = true
			baseAttemptUseDoor( door )
		end
	end
end