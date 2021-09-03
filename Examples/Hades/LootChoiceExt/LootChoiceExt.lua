ModUtil.RegisterMod("LootChoiceExt")

local config = {
	MinExtraLootChoices = 1,
	MaxExtraLootChoices = 2
}
LootChoiceExt.config = config

local baseChoices = GetTotalLootChoices()

-- Other mods should override this value
LootChoiceExt.Choices = baseChoices

LootChoiceExt.GetBaseChoices = function( )
	return baseChoices
end

OnAnyLoad{ function()
	LootChoiceExt.LastLootChoices = LootChoiceExt.Choices + RandomInt( config.MinExtraLootChoices, config.MaxExtraLootChoices )
end}

ModUtil.Path.Override("GetTotalLootChoices", function( )
	return LootChoiceExt.LastLootChoices
end, LootChoiceExt)

ModUtil.Path.Override("CalcNumLootChoices", function( )
	local numChoices = LootChoiceExt.LastLootChoices - GetNumMetaUpgrades("ReducedLootChoicesShrineUpgrade")
	return numChoices
end, LootChoiceExt)

ModUtil.Path.Context.Wrap("CreateBoonLootButtons", function( )
	local data = { }
	local active = false
	local first = true

	ModUtil.Path.Wrap("ipairs", function( base, tbl )
		if not active then
			local locals = ModUtil.Locals.Stacked( )
			if tbl == locals.upgradeOptions then
				active = true
				
				data.upgrade = locals.upgradeData
				data.blocked = locals.blockedIndexes
				data.options = tbl
				data.length = #tbl
				local excess = math.max( 3,data.length )-3
				locals.itemLocationY = locals.itemLocationY-12.5*excess
				data.squashY = 3/(3+excess)
				data.iconScaling = (excess == 0) and 0.85 or 1
			end
		end
		return base( tbl )
	end, LootChoiceExt )
	
	ModUtil.Path.Wrap( "SetScale", function( base, args )
		if active then
			args.Fraction = data.iconScaling
			SetScaleY(args)
			args.Fraction = data.iconScaling*data.squashY
			return SetScaleX(args)
		end
		return base( args )
	end, LootChoiceExt)

	ModUtil.Path.Wrap( "SetScaleY", function( base, args )
		if active then
			args.Fraction = args.Fraction*data.squashY
		end
		return base( args )
	end, LootChoiceExt)
	
	ModUtil.Path.Wrap( "CreateTextBox", function( base, args )
		if active then
			if args.OffsetY then
				args.OffsetY = args.OffsetY*data.squashY
			end
			if data.upgrade and args.Text == data.upgrade.CustomRarityName then 
				ModUtil.Locals.Stacked( ).lineSpacing = 8*data.squashY
			end
		end
		return base( args )
	end, LootChoiceExt )
	
	ModUtil.Path.Wrap( "CreateScreenComponent", function( base, args )
		if active and args.Group == "Combat_Menu" then
			local locals = ModUtil.Locals.Stacked( )
			if args.Name == "TraitBacking" then
				if first then
					first = false
				else
					locals.itemLocationY = locals.itemLocationY + 220*(data.squashY-1)
					args.Y = locals.itemLocationY
				end
			end
			if args.Name == "BoonSlot"..locals.itemIndex then
				locals.iconOffsetY = -2*data.squashY
				args.Name = "BoonSlot"..RandomInt( 1, 3 )
			end
		end
		local component = base( args )
		SetScaleY({Id = component.Id, Fraction = 1})
		return component
	end, LootChoiceExt )
	
	ModUtil.Path.Wrap("IsMetaUpgradeSelected", function( base, arg )
		if active and arg == "RerollPanelMetaUpgrade" then
			active = false
		end
		return base( arg )
	end, LootChoiceExt )
	
end, LootChoiceExt)

ModUtil.Path.Override("DestroyBoonLootButtons", function( lootData )
	local components = ScreenAnchors.ChoiceScreen.Components
	local toDestroy = {}
	for index = 1, GetTotalLootChoices() do
		local destroyIndexes = {
			"PurchaseButton"..index,
			"PurchaseButton"..index.. "Lock",
			"PurchaseButton"..index.. "Icon",
			"PurchaseButton"..index.. "ExchangeIcon",
			"PurchaseButton"..index.. "ExchangeIconFrame",
			"PurchaseButton"..index.. "QuestIcon",
			"Backing"..index,
			"PurchaseButton"..index.. "Frame",
			"PurchaseButton"..index.. "Patch"
		}
		for i, indexName in pairs( destroyIndexes ) do
			if components[indexName] then
				table.insert(toDestroy, components[indexName].Id)
				components[indexName] = nil
			end
		end
	end
	if components["RerollPanel"] then
		table.insert(toDestroy, components["RerollPanel"].Id)
		components["RerollPanel"] = nil
	end
	if ScreenAnchors.ChoiceScreen.SacrificedTraitId then
		table.insert(toDestroy, ScreenAnchors.ChoiceScreen.SacrificedTraitId )
		ScreenAnchors.ChoiceScreen.SacrificedTraitId = nil
	end
	if ScreenAnchors.ChoiceScreen.SacrificedFrameId then
		table.insert(toDestroy, ScreenAnchors.ChoiceScreen.SacrificedFrameId )
		ScreenAnchors.ChoiceScreen.SacrificedFrameId = nil
	end
	if ScreenAnchors.ChoiceScreen.ActivateSwapId then
		table.insert(toDestroy, ScreenAnchors.ChoiceScreen.ActivateSwapId )
		ScreenAnchors.ChoiceScreen.ActivateSwapId = nil
	end
	Destroy({ Ids = toDestroy })
end, LootChoiceExt)
