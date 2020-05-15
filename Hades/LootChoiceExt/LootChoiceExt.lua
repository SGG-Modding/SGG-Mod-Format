ModUtil.RegisterMod("LootChoiceExt")

local config = {
	MinLootChoices = 3,
	MaxLootChoices = 5
}
LootChoiceExt.config = config

function LootChoiceExt.DecideLootChoices()
	-- Mods should wrap or override this function but not the others
	return RandomInt( config.MinLootChoices, config.MaxLootChoices )
end

ModUtil.BaseOverride("GetTotalLootChoices", function()
	return LootChoiceExt.DecideLootChoices()
end, LootChoiceExt)

ModUtil.BaseOverride("CalcNumLootChoices", function()
	local numChoices = GetTotalLootChoices() - GetNumMetaUpgrades("ReducedLootChoicesShrineUpgrade")
	return numChoices
end, LootChoiceExt)

ModUtil.BaseOverride("CreateBoonLootButtons", function( lootData )

	local components = ScreenAnchors.ChoiceScreen.Components
	local upgradeName = lootData.Name
	local upgradeChoiceData = LootData[upgradeName]
	local upgradeOptions = lootData.UpgradeOptions
	if upgradeOptions == nil then
		SetTraitsOnLoot( lootData )
		upgradeOptions = lootData.UpgradeOptions
	end

	if not lootData.StackNum then
		lootData.StackNum = 1
	end
	lootData.StackNum = lootData.StackNum + GetTotalHeroTraitValue("PomLevelBonus")
	local tooltipData = {}

	local itemLocationY = 370
	local itemLocationX = ScreenCenterX - 355
	local firstOption = true
	local buttonOffsetX = 350

	if true then

		if IsEmpty( upgradeOptions ) then
			table.insert(upgradeOptions, { ItemName = "FallbackMoneyDrop", Type = "Consumable", Rarity = "Common" })
		end

		local blockedIndexes = {}
		for i = 1, TableLength(upgradeOptions) do
			table.insert( blockedIndexes, i )
		end
		for i = 1, CalcNumLootChoices() do
			RemoveRandomValue( blockedIndexes )
		end

		-- Sort traits in the following order: Melee, Secondary, Rush, Range
		table.sort(upgradeOptions, function (x, y)
			local slotToInt = function( slot )
				if slot ~= nil then
					local slotType = slot.Slot

					if slotType == "Melee" then
						return 0
					elseif slotType == "Secondary" then
						return 1
					elseif slotType == "Ranged" then
						return 2
					elseif slotType == "Rush" then
						return 3
					elseif slotType == "Shout" then
						return 4
					end
				end
				return 99
			end
			return slotToInt(TraitData[x.ItemName]) < slotToInt(TraitData[y.ItemName])
		end)

		if TableLength( upgradeOptions ) > 1 then
			-- Only create the "Choose One" textbox if there's something to choose
			CreateTextBox({ Id = components.ShopBackground.Id, Text = "UpgradeChoiceMenu_SubTitle",
				FontSize = 30,
				OffsetX = -435, OffsetY = -318,
				Color = Color.White,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left"
			})
		end
	end
	
	local excess = math.max(3,#upgradeOptions)-3
	itemLocationY = itemLocationY-12.5*excess
	local squashY = 3/(3+excess)
	local fsquashT1 = 0 if excess < 3 then fsquashT1 = 1 end
	
	for itemIndex, itemData in ipairs( upgradeOptions ) do
		local squashT1 = fsquashT1
		
		local itemBackingKey = "Backing"..itemIndex
		components[itemBackingKey] = CreateScreenComponent({ Name = "TraitBacking", Group = "Combat_Menu", X = ScreenCenterX, Y = itemLocationY })
		SetScaleY({ Id = components[itemBackingKey].Id, Fraction = 1.25*squashY })
		local upgradeData = nil
		local upgradeTitle = nil
		local upgradeDescription = nil
		if itemData.Type == "Trait" then
			upgradeData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, Rarity = itemData.Rarity })
			local traitNum = GetTraitCount(CurrentRun.Hero, upgradeData)
			if HeroHasTrait(itemData.ItemName) then
				upgradeTitle = "TraitLevel_Upgrade"
				upgradeData.Title = upgradeData.Name
			else
				upgradeTitle = upgradeData.Name

				upgradeData.Title = upgradeData.Name .."_Initial"
				if not HasDisplayName({ Text = upgradeData.Title }) then
					upgradeData.Title = upgradeData.Name
				end
			end

			if itemData.TraitToReplace ~= nil then
				upgradeData.TraitToReplace = itemData.TraitToReplace
				upgradeData.OldRarity = itemData.OldRarity
				local existingNum = GetTraitNameCount( CurrentRun.Hero, upgradeData.TraitToReplace )
				tooltipData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, FakeStackNum = existingNum, RarityMultiplier = upgradeData.RarityMultiplier})
				if existingNum > 1 then
					upgradeTitle = "TraitLevel_Exchange"
					tooltipData.Title = upgradeData.Name
					tooltipData.Level = existingNum
				end
			elseif lootData.StackOnly then
				tooltipData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, FakeStackNum = lootData.StackNum, RarityMultiplier = upgradeData.RarityMultiplier})
				tooltipData.OldLevel = traitNum;
				tooltipData.NewLevel = traitNum + lootData.StackNum;
				tooltipData.Title = upgradeData.Name
			else
				tooltipData = upgradeData
			end
			SetTraitTextData( tooltipData )
			upgradeDescription = GetTraitTooltip( tooltipData , { Default = upgradeData.Title })

		elseif itemData.Type == "Consumable" then
			-- TODO(Dexter) Determinism

			upgradeData = GetRampedConsumableData(ConsumableData[itemData.ItemName], itemData.Rarity)
			upgradeTitle = upgradeData.Name
			upgradeDescription = upgradeTitle

			if upgradeData.UseFunctionArgs ~= nil then
				if upgradeData.UseFunctionName ~= nil and upgradeData.UseFunctionArgs.TraitName ~= nil then
					local traitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = upgradeData.UseFunctionArgs.TraitName, Rarity = itemData.Rarity })
					SetTraitTextData( traitData )
					upgradeData.UseFunctionArgs.TraitName = nil
					upgradeData.UseFunctionArgs.TraitData = traitData
					tooltipData = MergeTables( tooltipData, traitData )
				elseif upgradeData.UseFunctionNames ~= nil then
					local hasTraits = false
					for i, args in pairs(upgradeData.UseFunctionArgs) do
						if args.TraitName ~= nil then
							hasTraits = true
							local processedTraitData =  GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = args.TraitName, Rarity = itemData.Rarity })
							SetTraitTextData( processedTraitData )
							tooltipData = MergeTables( tooltipData, processedTraitData )
							upgradeData.UseFunctionArgs[i].TraitName = nil
							upgradeData.UseFunctionArgs[i].TraitData = processedTraitData
						end
					end
					if not hasTraits then
						tooltipData = upgradeData
					end
				end
			else
				tooltipData = upgradeData
			end
		elseif itemData.Type == "TransformingTrait" then
			local blessingData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.ItemName, Rarity = itemData.Rarity })
			local curseData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.SecondaryItemName, Rarity = itemData.Rarity })
			curseData.OnExpire =
			{
				TraitData = blessingData
			}
			upgradeTitle = "ChaosCombo_"..curseData.Name.."_"..blessingData.Name
			blessingData.Title = "ChaosBlessingFormat"

			SetTraitTextData( blessingData )
			SetTraitTextData( curseData )
			blessingData.TrayName = blessingData.Name.."_Tray"

			tooltipData = MergeTables( tooltipData, blessingData )
			tooltipData = MergeTables( tooltipData, curseData )
			tooltipData.Blessing = itemData.ItemName
			tooltipData.Curse = itemData.SecondaryItemName

			upgradeDescription = blessingData.Title
			upgradeData = DeepCopyTable( curseData )
			upgradeData.Icon = blessingData.Icon

			local extractedData = GetExtractData( blessingData )
			for i, value in pairs(extractedData) do
				local key = value.ExtractAs
				if key then
					upgradeData[key] = blessingData[key]
				end
			end
		end

		-- Setting button graphic based on boon type
		local purchaseButtonKey = "PurchaseButton"..itemIndex


		local iconOffsetX = -323
		local iconOffsetY = -2*squashY
		local exchangeIconPrefix = nil
		local overlayLayer = "Combat_Menu_Overlay"

		components[purchaseButtonKey] = CreateScreenComponent({ Name = "BoonSlot"..RandomInt(1,3), Group = "Combat_Menu", Scale = 1, X = itemLocationX + buttonOffsetX, Y = itemLocationY })
		SetScaleY({Id = components[purchaseButtonKey].Id, Fraction = squashY})
		if upgradeData.CustomRarityColor then
			components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 15, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
			SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = upgradeData.CustomRarityColor })
			SetScaleY({Id = components[purchaseButtonKey.."Patch"].Id, Fraction = squashY})
		elseif itemData.Rarity ~= "Common" then
			components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 15, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
			SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = Color["BoonPatch" .. itemData.Rarity] })
			SetScaleY({Id = components[purchaseButtonKey.."Patch"].Id, Fraction = squashY})
		end
		if Contains( blockedIndexes, itemIndex ) then
			itemData.Blocked = true
			overlayLayer = "Combat_Menu"
			UseableOff({ Id = components[purchaseButtonKey].Id })
			ModifyTextBox({ Ids = components[purchaseButtonKey].Id, BlockTooltip = true })
			CreateTextBox({ Id = components[purchaseButtonKey].Id,
			Text = "ReducedLootChoicesKeyword",
			OffsetX = textOffset, OffsetY = -30*squashY,
			Color = Color.Transparent,
			Width = 615,
			})
			thread( TraitLockedPresentation, { Components = components, Id = purchaseButtonKey, OffsetX = itemLocationX + buttonOffsetX, OffsetY = iconOffsetY + itemLocationY } )
		end

		if upgradeData.Icon ~= nil then
			components[purchaseButtonKey.."Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Icon"].Id, Name = upgradeData.Icon .. "_Large" })
			SetScaleY({Id = components[purchaseButtonKey.."Icon"].Id, Fraction = squashY})
			SetScaleX({Id = components[purchaseButtonKey.."Icon"].Id, Fraction = squashY})
		end

		local locScaleModifiers =
		{
			LangRuScaleModifier = 0.75,
			LangCnScaleModifier = 0.80,
			LangKoScaleModifier = 0.8,
			LangPlScaleModifier = 0.75,
			LangFrScaleModifier = 0.8,
			LangDeScaleModifier = 0.8,
			LangItScaleModifier = 0.8,
			LangPtBrScaleModifier = 0.9,
			LangEsScaleModifier = 0.8,
		}

		if upgradeData.TraitToReplace ~= nil then
			squashT1 = math.pow(3/5,1-fsquashT1)
			local yOffset = 70*squashY*squashT1
			local xOffset = 700
			local blockedIconOffset = 0
			local textOffset = xOffset * -1 + 110
			if Contains( blockedIndexes, itemIndex ) then
				blockedIconOffset = -20*squashY
			end

			components[purchaseButtonKey.."ExchangeIcon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = overlayLayer, X = iconOffsetX + itemLocationX + buttonOffsetX + xOffset, Y = iconOffsetY + itemLocationY + yOffset + blockedIconOffset})
			SetAnimation({ DestinationId = components[purchaseButtonKey.."ExchangeIcon"].Id, Name = TraitData[upgradeData.TraitToReplace].Icon .. "_Small" })
			SetScaleY({Id = components[purchaseButtonKey.."ExchangeIcon"].Id, Fraction = squashY})
			SetScaleX({Id = components[purchaseButtonKey.."ExchangeIcon"].Id, Fraction = squashY})

			components[purchaseButtonKey.."ExchangeIconFrame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = overlayLayer, X = iconOffsetX + itemLocationX + buttonOffsetX + xOffset, Y = iconOffsetY + itemLocationY + yOffset + blockedIconOffset})
			SetAnimation({ DestinationId = components[purchaseButtonKey.."ExchangeIconFrame"].Id, Name = "BoonIcon_Frame_".. itemData.OldRarity})
			SetScaleY({Id = components[purchaseButtonKey.."ExchangeIconFrame"].Id, Fraction = squashY})
			SetScaleX({Id = components[purchaseButtonKey.."ExchangeIconFrame"].Id, Fraction = squashY})

			exchangeIconPrefix = "{!Icons.TraitExchange} "

			CreateTextBox(MergeTables({
				Id = components[purchaseButtonKey.."ExchangeIcon"].Id,
				Text = "ReplaceTraitPrefix",
				OffsetX = textOffset, OffsetY = -12*squashY*squashT1 - blockedIconOffset,
				FontSize = 20,
				Color = {160, 160, 160, 255},
				Width = 615,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "Top",
			}, locScaleModifiers))

			CreateTextBox(MergeTables({
				Id = components[purchaseButtonKey.."ExchangeIcon"].Id,
				Text = itemData.TraitToReplace,
				OffsetX = textOffset + 150, OffsetY = -12*squashY*squashT1 - blockedIconOffset,
				FontSize = 20,
				Color = Color["BoonPatch" .. itemData.OldRarity],
				Width = 615,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				VerticalJustification = "Top",
			}, locScaleModifiers))

		end

		components[purchaseButtonKey.."Frame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
		SetScaleY({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
		SetScaleX({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
		if upgradeData.Frame then
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Boon_Menu_".. upgradeData.Frame})
			SetScaleY({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
			SetScaleX({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
		else
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Boon_Menu_".. itemData.Rarity})
			SetScaleY({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
			SetScaleX({Id = components[purchaseButtonKey.."Frame"].Id, Fraction = squashY})
		end
		-- Button data setup
		components[purchaseButtonKey].OnPressedFunctionName = "HandleUpgradeChoiceSelection"
		components[purchaseButtonKey].Data = upgradeData
		components[purchaseButtonKey].UpgradeName = upgradeName
		components[purchaseButtonKey].Type = itemData.Type
		components[purchaseButtonKey].LootData = lootData
		components[purchaseButtonKey].LootColor = upgradeChoiceData.LootColor
		components[purchaseButtonKey].BoonGetColor = upgradeChoiceData.BoonGetColor

		components[components[purchaseButtonKey].Id] = purchaseButtonKey
		-- Creates upgrade slot text
		SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 640 })
		local selectionString = "UpgradeChoiceMenu_PermanentItem"
		local selectionStringColor = Color.Black

		if itemData.Type == "Trait" then
			local traitData = TraitData[itemData.ItemName]
			if traitData.Slot ~= nil then
				selectionString = "UpgradeChoiceMenu_"..traitData.Slot
			end
		elseif itemData.Type == "Consumable" then
			selectionString = upgradeData.UpgradeChoiceText or "UpgradeChoiceMenu_PermanentItem"
		end

		local textOffset = 135 - buttonOffsetX
		local exchangeIconOffset = 0
		local lineSpacing = 8*squashY
		local text = "Boon_"..tostring(itemData.Rarity)
		local overlayLayer = ""
		if upgradeData.CustomRarityName then
			text = upgradeData.CustomRarityName
		end
		local color = Color["BoonPatch" .. itemData.Rarity ]
		if upgradeData.CustomRarityColor then
			color = upgradeData.CustomRarityColor
		end

		CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = text  ,
			FontSize = 25,
			OffsetX = textOffset + 600, OffsetY = -60*squashY*squashT1,
			Width = 720,
			Color = color,
			Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
			Justification = "Right"
		})
		if exchangeIconPrefix then
			CreateTextBox({ Id = components[purchaseButtonKey].Id,
				Text = exchangeIconPrefix ,
				FontSize = 25,
				OffsetX = textOffset, OffsetY = -55*squashY*squashT1,
				Color = color,
				Font = "AlegreyaSansSCLight",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				LuaKey = "TooltipData", LuaValue = tooltipData,
			})
			exchangeIconOffset = 40
			if upgradeData.Slot == "Shout" then
				lineSpacing = 4
			end
		end
		CreateTextBox({ Id = components[purchaseButtonKey].Id,
			Text = upgradeTitle,
			FontSize = 25,
			OffsetX = textOffset + exchangeIconOffset, OffsetY = -55*squashY*squashT1,
			Color = color,
			Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
			Justification = "Left",
			LuaKey = "TooltipData", LuaValue = tooltipData,
		})

		CreateTextBoxWithFormat(MergeTables({ Id = components[purchaseButtonKey].Id,
			Text = upgradeDescription,
			OffsetX = textOffset+2*ScreenCenterX*(1-fsquashT1), OffsetY = -30*squashY,
			Width = 615,
			Justification = "Left",
			VerticalJustification = "Top",
			LineSpacingBottom = lineSpacing,
			UseDescription = true,
			LuaKey = "TooltipData", LuaValue = tooltipData,
			Format = "BaseFormat",
			VariableAutoFormat = "BoldFormatGraft",
			TextSymbolScale = 0.8*squashY,
		}, locScaleModifiers))

		local needsQuestIcon = false
		if not GameState.TraitsTaken[upgradeData.Name] and HasActiveQuestForTrait( upgradeData.Name ) then
			needsQuestIcon = true
		elseif itemData.ItemName ~= nil and not GameState.TraitsTaken[itemData.ItemName] and HasActiveQuestForTrait( itemData.ItemName ) then
			needsQuestIcon = true
		end

		if needsQuestIcon then
			components[purchaseButtonKey.."QuestIcon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + 112, Y = itemLocationY - 55*squashY*squashT1 })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."QuestIcon"].Id, Name = "QuestItemFound" })
			-- Silent toolip
			CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "TraitQuestItem", Color = Color.Transparent, LuaKey = "TooltipData", LuaValue = tooltipData, })
		end

		if upgradeData.LimitedTime then
			-- Silent toolip
			CreateTextBox({ Id = components[purchaseButtonKey].Id, TextSymbolScale = 0, Text = "SeasonalItem", Color = Color.Transparent, LuaKey = "TooltipData", LuaValue = tooltipData, })
		end

		if firstOption then
			TeleportCursor({ OffsetX = itemLocationX + buttonOffsetX, OffsetY = itemLocationY, ForceUseCheck = true, })
			firstOption = false
		end

		itemLocationY = itemLocationY + 220*squashY
	end

	if true then
		if IsMetaUpgradeActive("RerollPanelMetaUpgrade") then
			local cost = -1
			if lootData.BlockReroll then
				cost = -1
			elseif lootData.Name == "WeaponUpgrade" then
				cost = RerollCosts.Hammer
			else
				cost = RerollCosts.Boon
			end
			local baseCost = cost 

			local name = "RerollPanelMetaUpgrade_ShortTotal"
			local tooltip = "MetaUpgradeRerollHint"
			if cost >= 0 then

				local increment = 0
				if CurrentRun.CurrentRoom.SpentRerolls then
					increment = CurrentRun.CurrentRoom.SpentRerolls[lootData.ObjectId] or 0
				end
				cost = cost + increment
			else
				name = "RerollPanel_Blocked"
				tooltip = "MetaUpgradeRerollBlockedHint"
			end
			local color = Color.White
			if CurrentRun.NumRerolls < cost or cost < 0 then
				color = Color.CostUnaffordable
			end

			if baseCost > 0 then
				components["RerollPanel"] = CreateScreenComponent({ Name = "ShopRerollButton", Scale = 1.0, Group = "Combat_Menu" })
				Attach({ Id = components["RerollPanel"].Id, DestinationId = components.ShopBackground.Id, OffsetX = 0, OffsetY = 410 })
				components["RerollPanel"].OnPressedFunctionName = "AttemptPanelReroll"
				components["RerollPanel"].RerollFunctionName = "RerollBoonLoot"
				components["RerollPanel"].RerollColor = lootData.LootColor
				components["RerollPanel"].RerollId = lootData.ObjectId

				components["RerollPanel"].Cost = cost

				CreateTextBox({ Id = components["RerollPanel"].Id, Text = name, OffsetX = 28, OffsetY = -5,
				ShadowColor = {0,0,0,1}, ShadowOffset={0,3}, OutlineThickness = 3, OutlineColor = {0,0,0,1},
				FontSize = 28, Color = color, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
				SetInteractProperty({ DestinationId = components["RerollPanel"].Id, Property = "TooltipOffsetX", Value = 350 })
				CreateTextBox({ Id = components["RerollPanel"].Id, Text = tooltip, FontSize = 1, Color = Color.Transparent, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
			end
		end
	end
end, LootChoiceExt)
