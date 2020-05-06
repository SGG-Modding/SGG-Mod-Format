if ModUtil.Hades and not ModUtilHades then
	
	ModUtil.RegisterMod("ModUtilHades")
	ModUtilHades = ModUtil.Hades
	
	-- Screen Handling
	
	OnAnyLoad{ function() 
		if ModUtil.UnfreezeLoop then return end
		ModUtil.UnfreezeLoop = true
		thread( function()
			while ModUtil.UnfreezeLoop do
				wait(15)
				if (not AreScreensActive()) and (not IsInputAllowed({})) then
					UnfreezePlayerUnit()
					DisableShopGamepadCursor()
				end
			end
		end)
	end}

	-- Menu Handling

	function ModUtil.Hades.CloseMenu( screen, button )
		CloseScreen(GetAllIds(screen.Components), 0.1)
		ModUtil.Anchors.Menu[screen.Name] = nil
		screen.KeepOpen = false
		OnScreenClosed({ Flag = screen.Name })
		SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
		SetConfigOption({ Name = "UseOcclusion", Value = true })
		if TableLength(ModUtil.Anchors.Menu) == 0 then
			UnfreezePlayerUnit()
			DisableShopGamepadCursor()
		end
		if ModUtil.Anchors.CloseFuncs[screen.Name] then
			ModUtil.Anchors.CloseFuncs[screen.Name]( screen, button )
			ModUtil.Anchors.CloseFuncs[screen.Name]=nil
		end
	end

	function ModUtil.Hades.OpenMenu( group, closeFunc, openFunc )
		if ModUtil.Anchors.Menu[group] then
			ModUtil.Hades.CloseMenu(ModUtil.Anchors.Menu[group])
		end
		if closeFunc then ModUtil.Anchors.CloseFuncs[group]=closeFunc end
		
		local screen = { Name = group, Components = {} }
		local components = screen.Components
		ModUtil.Anchors.Menu[group] = screen
		
		OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
		SetConfigOption({ Name = "UseOcclusion", Value = false })
		
		components.Background = CreateScreenComponent({ Name = "BlankObstacle", Group = group })
		
		if openFunc then openFunc(screen) end
		
		return screen
	end
	
	function ModUtil.Hades.DimMenu( screen )
		if not screen then return end
		if not screen.Components.BackgroundDim then
			screen.Components.BackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = screen.Name })
			SetScale({ Id = screen.Components.BackgroundDim.Id, Fraction = 4 })
		end
		SetColor({ Id = screen.Components.BackgroundDim.Id, Color = {0.090, 0.090, 0.090, 0.8} })
	end
	
	function ModUtil.Hades.UndimMenu( screen )
		if not screen then return end
		if not screen.Components.BackgroundDim then return end
		SetColor({ Id = screen.Components.BackgroundDim.Id, Color = {0.090, 0.090, 0.090, 0} })
	end
	
	function ModUtil.Hades.PostOpenMenu( group )
		local screen = ModUtil.Anchors.Menu[group]
		FreezePlayerUnit()
		EnableShopGamepadCursor()
		thread(HandleWASDInput, screen)
		HandleScreenInput(screen)
		return screen
	end

	-- Debug Printing

	function ModUtil.Hades.PrintDisplay( text , delay, color )
		if type(text) ~= "string" then
			text = ModUtil.ToString(text)
		end
		text = " "..text.." "
		if color == nil then
			color = Color.Yellow
		end
		if delay == nil then
			delay = 5
		end
		if ModUtil.Anchors.PrintDisplay then
			Destroy({Ids = ModUtil.Anchors.PrintDisplay.Id})
		end
		ModUtil.Anchors.PrintDisplay = CreateScreenComponent({Name = "BlankObstacle", Group = "PrintDisplay", X = ScreenCenterX, Y = 40 })
		CreateTextBox({ Id = ModUtil.Anchors.PrintDisplay.Id, Text = text, FontSize = 22, Color = color, Font = "UbuntuMonoBold"})
		
		if delay > 0 then
			thread(function()
				wait(delay)
				Destroy({Ids = ModUtil.Anchors.PrintDisplay.Id})
				ModUtil.Anchors.PrintDisplay = nil
			end)
		end
	end

	function ModUtil.Hades.PrintOverhead(text, delay, color, dest)
		if type(text) ~= "string" then
			text = ModUtil.ToString(text)
		end
		text = " "..text.." "
		if dest == nil then
			dest = CurrentRun.Hero.ObjectId
		end
		if color == nil then
			color = Color.Yellow
		end
		if delay == nil then
			delay = 5
		end
		Destroy({Ids = ModUtil.Anchors.PrintOverhead})
		ModUtil.Anchors.PrintOverhead = SpawnObstacle({ Name = "BlankObstacle", Group = "Events", DestinationId = dest })
		Attach({ Id = ModUtil.Anchors.PrintOverhead, DestinationId = dest })
		CreateTextBox({ Id = ModUtil.Anchors.PrintOverhead, Text = text, FontSize = 32, OffsetX = 0, OffsetY = -150, Color = color, Font = "AlegreyaSansSCBold", Justification = "Center" })
		if delay > 0 then
			thread(function()
				wait(delay)
				Destroy({Ids = ModUtil.Anchors.PrintOverhead})
				ModUtil.Anchors.PrintOverhead = nil
			end)
		end
	end

	local function ClosePrintStack()
		if ModUtil.Anchors.PrintStack then
			ModUtil.Anchors.PrintStack.CullEnabled = false
			PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
			ModUtil.Anchors.PrintStack.KeepOpen = false
			
			CloseScreen(GetAllIds(ModUtil.Anchors.PrintStack.Components),0)
			ModUtil.Anchors.PrintStack = nil
		end
	end
	
	OnAnyLoad{ ClosePrintStack }

	local function OrderPrintStack(screen,components)
		
		for k,v in pairs(screen.CullPrintStack) do
			if v.obj then
				Destroy({ Ids = v.obj.Id })
				components["TextStack_" .. v.tid] = nil
				v.obj = nil
				screen.TextStack[v.tid]=nil
			end
		end
		screen.CullPrintStack = {}
		
		for k,v in pairs(screen.TextStack) do
			components["TextStack_" .. k] = nil
			Destroy({Ids = v.obj.Id})
		end
		
		screen.TextStack = CollapseTable(screen.TextStack)
		for i,v in pairs(screen.TextStack) do
			v.tid = i
		end
		if #screen.TextStack == 0 then
			return ClosePrintStack()
		end
		
		local Ymul = 9
		local Ygap = 30
		local Yoff = 260
		local n =#screen.TextStack
		
		if n then
			for k=n,math.max(1,n-Ymul+1),-1 do
				v = screen.TextStack[k]
				if v then
					local data = v.data
					screen.TextStack[k].obj = CreateScreenComponent({ Name = "rectangle01", Group = "PrintStack", X = -1000, Y = -1000})
					local textStack = screen.TextStack[k].obj
					components["TextStack_" .. k] = textStack
					SetScaleX({Id = textStack.Id, Fraction = 1.55})
					SetScaleY({Id = textStack.Id, Fraction = 0.085})
					SetColor({ Id = textStack.Id, Color = data.Bgcol })
					CreateTextBox({ Id = textStack.Id, Text = data.Text, FontSize = 15, OffsetX = 0, OffsetY = 0, Color = data.Color, Font = "UbuntuMonoBold", Justification = "Center" })
					Attach({ Id = textStack.Id, DestinationId = components.Background.Id, OffsetX = 220, OffsetY = -Yoff })
					Yoff = Yoff - Ygap
				end
			end
		end
		
	end
	
	function ModUtil.Hades.PrintStack( text, delay, color, bgcol, sound)
		if type(text) ~= "string" then
			text = ModUtil.ToString(text)
		end
		text = " "..text.." "
		if color == nil then
			color = {1,1,1,1}
		end
		if bgcol == nil then
			bgcol = {0,0,0,0}
		end
		if sound == nil then
			sound = "/Leftovers/SFX/AuraOff"
		end
		if delay == nil then
			delay = 4
		end
		local first = false
		if not ModUtil.Anchors.PrintStack then
			first = true
			ModUtil.Anchors.PrintStack = { Components = {} }
		end
		local screen = ModUtil.Anchors.PrintStack
		local components = screen.Components
		
		if first then 
			PlaySound({ Name = "/SFX/Menu Sounds/DialoguePanelOutMenu" })
			components.Background = CreateScreenComponent({ Name = "BlankObstacle", Group = "PrintStack", X = ScreenCenterX, Y = 2*ScreenCenterY})
			components.Backing = CreateScreenComponent({ Name = "TraitTray_Center", Group = "PrintStack"})
			Attach({ Id = components.Backing.Id, DestinationId = components.Background.Id, OffsetX = -180, OffsetY = -150 })
			SetColor({ Id = components.Backing.Id, Color = {0.590, 0.555, 0.657, 0.8} })
			SetScaleX({Id = components.Backing.Id, Fraction = 6.25})
			SetScaleY({Id = components.Backing.Id, Fraction = 0.60})
			screen.KeepOpen = true
			screen.TextStack = {}
			screen.CullPrintStack = {}
			screen.MaxStacks = 32
			
			thread( function()
				while screen do
					wait(0.5)
					if screen.CullEnabled then
						if screen.CullPrintStack[1] then
							OrderPrintStack(screen,components)
						end
					end
				end
			end)
			
		end
		
		screen.CullEnabled = false
		
		local n =#screen.TextStack + 1
		if n > screen.MaxStacks then
			for i,v in ipairs(screen.TextStack) do
				if i > n-screen.MaxStacks then break end
				Destroy({ Ids = v.obj.Id })
				v.obj = nil
				components["TextStack_" .. v.tid] = nil
				screen.TextStack[v.tid] = nil
			end
		end
		
		local newText = {}
		newText.obj = CreateScreenComponent({ Name = "rectangle01", Group = "PrintStack"})
		newText.data = {Text = text, Color = color, Bgcol = bgcol}
		SetColor({ Id = newText.obj.Id, Color = {0,0,0,0}})
		table.insert(screen.TextStack, newText)
		
		PlaySound({ Name = sound })
		
		OrderPrintStack(screen,components)
		
		thread( function()
			wait(delay)
			if newText.obj then
				table.insert(screen.CullPrintStack,newText)
			end
		end)
		
		screen.CullEnabled = true
		
	end
	
	-- Custom Menus
	
	function ModUtil.Hades.NewMenuYesNo( group, closeFunc, openFunc, yesFunc, noFunc, title, body, yesText, noText, icon, iconScale)
		
		if not group or group == "" then group = "MenuYesNo" end
		if not yesFunc or not noFunc then return end
		if not icon then icon = "AmmoPack" end
		if not iconScale then iconScale = 1 end
		if not yesText then yesText = "Yes" end
		if not noText then noText = "No" end
		if not body then body = "Make a choice..." end
		if not title then title = group end
		
		local screen = ModUtil.Hades.OpenMenu( group, closeFunc, openFunc )
		local components = screen.Components
		
		PlaySound({ Name = "/SFX/Menu Sounds/GodBoonInteract" })
		
		components.LeftPart = CreateScreenComponent({ Name = "TraitTrayBackground", Group = group, X = 1030, Y = 424})
		components.MiddlePart = CreateScreenComponent({ Name = "TraitTray_Center", Group = group, X = 660, Y = 464 })
		components.RightPart = CreateScreenComponent({ Name = "TraitTray_Right", Group = group, X = 1270, Y = 438 })
		SetScaleY({Id = components.LeftPart.Id, Fraction = 0.8})
		SetScaleY({Id = components.MiddlePart.Id, Fraction = 0.8})
		SetScaleY({Id = components.RightPart.Id, Fraction = 0.8})
		SetScaleX({Id = components.MiddlePart.Id, Fraction = 5})
		

		CreateTextBox({ Id = components.Background.Id, Text = " "..title.." ", FontSize = 34,
		OffsetX = 0, OffsetY = -225, Color = Color.White, Font = "SpectralSCLight",
		ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 1}, Justification = "Center" })
		CreateTextBox({ Id = components.Background.Id, Text = " "..body.." ", FontSize = 19,
		OffsetX = 0, OffsetY = -175, Width = 840, Color = Color.SubTitle, Font = "CrimsonTextItalic",
		ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 1}, Justification = "Center" })

		components.Icon = CreateScreenComponent({ Name = "BlankObstacle", Group = group })
		Attach({ Id = components.Icon.Id, DestinationId = components.Background.Id, OffsetX = 0, OffsetY = -50})
		SetAnimation({ Name = icon, DestinationId = components.Icon.Id, Scale = iconScale })

		ModUtil.NewTable(ModUtil.Anchors.Menu[group], "Funcs")
		ModUtil.Anchors.Menu[group].Funcs={
			Yes = function(screen, button)
					local ret = yesFunc(screen,button)
					ModUtil.Hades.CloseMenuYesNo(screen,button)
					return ret
				end, 
			No = function(screen, button)
					local ret = noFunc(screen,button)
					ModUtil.Hades.CloseMenuYesNo(screen,button)
					return ret
				end,
		}
		ModUtil.GlobaliseFuncs( ModUtil.Anchors.Menu[group].Funcs, "ModUtil.Anchors.Menu."..group..".Funcs" )

		components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Scale = 0.7, Group = group })
		Attach({ Id = components.CloseButton.Id, DestinationId = components.Background.Id, OffsetX = 0, OffsetY = ScreenCenterY - 315 })
		components.CloseButton.OnPressedFunctionName = ModUtil.JoinPath("ModUtil.Hades.CloseMenuYesNo")
		components.CloseButton.ControlHotkey = "Cancel"

		components.YesButton = CreateScreenComponent({ Name = "BoonSlot1", Group = group, Scale = 0.35, })
		components.YesButton.OnPressedFunctionName = ModUtil.JoinPath("ModUtil.Anchors.Menu."..group..".Funcs.Yes")
		SetScaleX({Id = components.YesButton.Id, Fraction = 0.75})
		SetScaleY({Id = components.YesButton.Id, Fraction = 1.15})
		Attach({ Id = components.YesButton.Id, DestinationId = components.Background.Id, OffsetX = -150, OffsetY = 75 })
		CreateTextBox({ Id = components.YesButton.Id, Text = " "..yesText.." ",
			FontSize = 28, OffsetX = 0, OffsetY = 0, Width = 720, Color = Color.LimeGreen, Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center"
		})
		
		components.NoButton = CreateScreenComponent({ Name = "BoonSlot1", Group = group, Scale = 0.35, })
		components.NoButton.OnPressedFunctionName = ModUtil.JoinPath("ModUtil.Anchors.Menu."..group..".Funcs.No")
		SetScaleX({Id = components.NoButton.Id, Fraction = 0.75})
		SetScaleY({Id = components.NoButton.Id, Fraction = 1.15})
		Attach({ Id = components.NoButton.Id, DestinationId = components.Background.Id, OffsetX = 150, OffsetY = 75 })
		CreateTextBox({ Id = components.NoButton.Id, Text = noText,
			FontSize = 26, OffsetX = 0, OffsetY = 0, Width = 720, Color = Color.Red, Font = "AlegreyaSansSCLight",
			ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center"
		})
		
		return ModUtil.Hades.PostOpenMenu( group )
	end
	
	function ModUtil.Hades.CloseMenuYesNo( screen, button )
		PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
		_G[ModUtil.JoinPath("ModUtil.Anchors.Menu."..screen.Name..".Funcs.Yes")]=nil
		_G[ModUtil.JoinPath("ModUtil.Anchors.Menu."..screen.Name..".Funcs.No")]=nil
		ModUtil.Hades.CloseMenu( screen, button )
	end
	
ModUtil.GlobaliseModFuncs( ModUtil )
	
end