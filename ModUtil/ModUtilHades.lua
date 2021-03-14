
ModUtil.RegisterMod( "Hades", ModUtil )

ModUtil.MapSetTable( ModUtil.Hades, {
	PrintStackHeight = 10,
	PrintStackCapacity = 80
} )

ModUtil.Anchors.PrintOverhead = {}

-- Screen Handling

OnAnyLoad{ function() 
	if ModUtil.Hades.UnfreezeLoop then return end
	ModUtil.Hades.UnfreezeLoop = true
	thread( function()
		while ModUtil.Hades.UnfreezeLoop do
			wait(15)
			if ModUtil.SafeGet(CurrentRun,{'Hero','FreezeInputKeys'}) then
				if (not AreScreensActive()) and (not IsInputAllowed({})) then
					UnfreezePlayerUnit()
					DisableShopGamepadCursor()
				end
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
	if TableLength(ModUtil.Anchors.Menu) == 0 then
		SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
		SetConfigOption({ Name = "UseOcclusion", Value = true })
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

function ModUtil.Hades.PostOpenMenu( screen )
	if TableLength(ModUtil.Anchors.Menu) == 1 then
		SetConfigOption({ Name = "FreeFormSelectWrapY", Value = true })
		SetConfigOption({ Name = "UseOcclusion", Value = false })
		FreezePlayerUnit()
		EnableShopGamepadCursor()
	end
	thread(HandleWASDInput, screen)
	HandleScreenInput(screen)
	return screen
end

function ModUtil.Hades.GetMenuScreen( group )
	return ModUtil.Anchors.Menu[group]
end

-- Debug Printing

function ModUtil.Hades.PrintDisplay( text , delay, color )
	if type(text) ~= "string" then
		text = tostring(text)
	end
	text = " "..text.." "
	if color == nil then
		color = Color.Yellow
	end
	if delay == nil then
		delay = 5
	end
	if ModUtil.Anchors.PrintDisplay then
		Destroy({Ids = {ModUtil.Anchors.PrintDisplay.Id}})
	end
	ModUtil.Anchors.PrintDisplay = CreateScreenComponent({Name = "BlankObstacle", Group = "PrintDisplay", X = ScreenCenterX, Y = 40 })
	CreateTextBox({ Id = ModUtil.Anchors.PrintDisplay.Id, Text = text, FontSize = 22, Color = color, Font = "UbuntuMonoBold"})
	
	if delay > 0 then
		thread(function()
			wait(delay)
			Destroy({Ids = {ModUtil.Anchors.PrintDisplay.Id}})
			ModUtil.Anchors.PrintDisplay = nil
		end)
	end
end

function ModUtil.Hades.PrintOverhead(text, delay, color, dest)
	if type(text) ~= "string" then
		text = tostring(text)
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
	Destroy({Ids = {ModUtil.Anchors.PrintOverhead[dest]}})
	local id = SpawnObstacle({ Name = "BlankObstacle", Group = "PrintOverhead", DestinationId = dest })
	ModUtil.Anchors.PrintOverhead[dest] = id
	Attach({ Id = id, DestinationId = dest })
	CreateTextBox({ Id = id, Text = text, FontSize = 32, OffsetX = 0, OffsetY = -150, Color = color, Font = "AlegreyaSansSCBold", Justification = "Center" })
	if delay > 0 then
		thread(function()
			wait(delay)
			if ModUtil.Anchors.PrintOverhead[dest] then
				Destroy({Ids = {id}})
				ModUtil.Anchors.PrintOverhead[dest] = nil
			end
		end)
	end
end

local function ClosePrintStack()
	if ModUtil.Anchors.PrintStack then
		ModUtil.Anchors.PrintStack.CullEnabled = false
		PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
		ModUtil.Anchors.PrintStack.KeepOpen = false
		
		CloseScreen(GetAllIds(ModUtil.Anchors.PrintStack.Components),0)
		ModUtil.Anchors.CloseFuncs["PrintStack"] = nil
		ModUtil.Anchors.PrintStack = nil
	end
end

local function OrderPrintStack(screen,components)
	
	if screen.CullPrintStack then 
		local v = screen.TextStack[1]
		if v.obj then
			Destroy({Ids = {v.obj.Id}})
			components["TextStack_" .. v.tid] = nil
			v.obj = nil
			screen.TextStack[v.tid]=nil
		end
		thread( function()
			local v = screen.TextStack[2]
			if v then
				wait(v.data.Delay)
				if v.obj then
					screen.CullPrintStack = true
				end
			end
		end)
	else
		thread( function()
			local v = screen.TextStack[1]
			if v then 
				wait(v.data.Delay)
				if v.obj then
					screen.CullPrintStack = true
				end
			end
		end)
	end
	screen.CullPrintStack = false
	
	for k,v in pairs(screen.TextStack) do
		components["TextStack_" .. k] = nil
		Destroy({Ids = {v.obj.Id}})
	end
	
	screen.TextStack = CollapseTable(screen.TextStack)
	for i,v in pairs(screen.TextStack) do
		v.tid = i
	end
	if #screen.TextStack == 0 then
		return ClosePrintStack()
	end
	
	local Ymul = screen.StackHeight+1
	local Ygap = 30
	local Yoff = 26*screen.StackHeight+22
	local n =#screen.TextStack
	
	if n then
		for k=1,math.min(n,Ymul) do
			v = screen.TextStack[k]
			if v then
				local data = v.data
				screen.TextStack[k].obj = CreateScreenComponent({ Name = "rectangle01", Group = "PrintStack", X = -1000, Y = -1000})
				local textStack = screen.TextStack[k].obj
				components["TextStack_" .. k] = textStack
				SetScaleX({Id = textStack.Id, Fraction = 10/6})
				SetScaleY({Id = textStack.Id, Fraction = 0.1})
				SetColor({ Id = textStack.Id, Color = data.Bgcol })
				CreateTextBox({ Id = textStack.Id, Text = data.Text, FontSize = data.FontSize, OffsetX = 0, OffsetY = 0, Color = data.Color, Font = data.Font, Justification = "Center" })
				Attach({ Id = textStack.Id, DestinationId = components.Background.Id, OffsetX = 220, OffsetY = -Yoff })
				Yoff = Yoff - Ygap
			end
		end
	end
	
end

function ModUtil.Hades.PrintStack( text, delay, color, bgcol, fontsize, font, sound )		
	if color == nil then color = {1,1,1,1} end
	if bgcol == nil then bgcol = {0.590, 0.555, 0.657,0.125} end
	if fontsize == nil then fontsize = 13 end
	if font == nil then font = "UbuntuMonoBold" end
	if sound == nil then sound = "/Leftovers/SFX/AuraOff" end
	if delay == nil then delay = 3 end
	
	if type(text) ~= "string" then 
		text = tostring(text)
	end
	text = " "..text.." "
	
	local first = false
	if not ModUtil.Anchors.PrintStack then
		first = true
		ModUtil.Anchors.PrintStack = { Components = {} }
		ModUtil.Anchors.CloseFuncs["PrintStack"] = ClosePrintStack
	end
	local screen = ModUtil.Anchors.PrintStack
	local components = screen.Components
	
	if first then 
	
		screen.KeepOpen = true
		screen.TextStack = {}
		screen.CullPrintStack = false
		screen.MaxStacks = ModUtil.Hades.PrintStackCapacity
		screen.StackHeight = ModUtil.Hades.PrintStackHeight
		PlaySound({ Name = "/SFX/Menu Sounds/DialoguePanelOutMenu" })
		components.Background = CreateScreenComponent({ Name = "BlankObstacle", Group = "PrintStack", X = ScreenCenterX, Y = 2*ScreenCenterY})
		components.Backing = CreateScreenComponent({ Name = "TraitTray_Center", Group = "PrintStack"})
		Attach({ Id = components.Backing.Id, DestinationId = components.Background.Id, OffsetX = -180, OffsetY = 0 })
		SetColor({ Id = components.Backing.Id, Color = {0.590, 0.555, 0.657, 0.8} })
		SetScaleX({Id = components.Backing.Id, Fraction = 6.25})
		SetScaleY({Id = components.Backing.Id, Fraction = 6/55*(2+screen.StackHeight)})
		
		thread( function()
			while screen do
				wait(0.5)
				if screen.CullEnabled then
					if screen.CullPrintStack then
						OrderPrintStack(screen,components)
					end
				end
			end
		end)
		
	end

	if #screen.TextStack >= screen.MaxStacks then return end
	
	screen.CullEnabled = false
	
	local newText = {}
	newText.obj = CreateScreenComponent({ Name = "rectangle01", Group = "PrintStack"})
	newText.data = {Delay = delay, Text = text, Color = color, Bgcol = bgcol, Font = font, FontSize = fontsize}
	SetColor({ Id = newText.obj.Id, Color = {0,0,0,0}})
	table.insert(screen.TextStack, newText)
	
	PlaySound({ Name = sound })
	
	OrderPrintStack(screen,components)
	
	screen.CullEnabled = true
	
end

function ModUtil.Hades.PrintStackChunks( text, linespan, ... )
	if not linespan then linespan = 90 end
	for _,s in ipairs( ModUtil.ChunkText( text, linespan,ModUtil.Hades.PrintStackCapacity ) ) do
		ModUtil.Hades.PrintStack( s, ... )
	end
end

-- Custom Menus

function ModUtil.Hades.NewMenuYesNo( group, closeFunc, openFunc, yesFunc, noFunc, title, body, yesText, noText, icon, iconScale)
	
	if not group or group == "" then group = "MenuYesNo" end
	if not yesFunc then yesFunc = function( ) end end
	if not noFunc then noFunc = function( ) end end
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
				if not yesFunc(screen,button) then
					ModUtil.Hades.CloseMenuYesNo(screen,button)
				end
			end, 
		No = function(screen, button)
				if not noFunc(screen,button) then
					ModUtil.Hades.CloseMenuYesNo(screen,button)
				end
			end,
	}

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Scale = 0.7, Group = group })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.Background.Id, OffsetX = 0, OffsetY = ScreenCenterY - 315 })
	components.CloseButton.OnPressedFunctionName = "ModUtil.Hades.CloseMenuYesNo"
	components.CloseButton.ControlHotkey = "Cancel"

	components.YesButton = CreateScreenComponent({ Name = "BoonSlot1", Group = group, Scale = 0.35, })
	components.YesButton.OnPressedFunctionName = "ModUtil.Anchors.Menu."..group..".Funcs.Yes"
	SetScaleX({Id = components.YesButton.Id, Fraction = 0.75})
	SetScaleY({Id = components.YesButton.Id, Fraction = 1.15})
	Attach({ Id = components.YesButton.Id, DestinationId = components.Background.Id, OffsetX = -150, OffsetY = 75 })
	CreateTextBox({ Id = components.YesButton.Id, Text = " "..yesText.." ",
		FontSize = 28, OffsetX = 0, OffsetY = 0, Width = 720, Color = Color.LimeGreen, Font = "AlegreyaSansSCLight",
		ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center"
	})
	
	components.NoButton = CreateScreenComponent({ Name = "BoonSlot1", Group = group, Scale = 0.35, })
	components.NoButton.OnPressedFunctionName = "ModUtil.Anchors.Menu."..group..".Funcs.No"
	SetScaleX({Id = components.NoButton.Id, Fraction = 0.75})
	SetScaleY({Id = components.NoButton.Id, Fraction = 1.15})
	Attach({ Id = components.NoButton.Id, DestinationId = components.Background.Id, OffsetX = 150, OffsetY = 75 })
	CreateTextBox({ Id = components.NoButton.Id, Text = noText,
		FontSize = 26, OffsetX = 0, OffsetY = 0, Width = 720, Color = Color.Red, Font = "AlegreyaSansSCLight",
		ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center"
	})
	
	return ModUtil.Hades.PostOpenMenu( screen )
end

function ModUtil.Hades.CloseMenuYesNo( screen, button )
	PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
	ModUtil.Hades.CloseMenu( screen, button )
end

-- Misc

function ModUtil.Hades.RandomElement( tableArg, rng )
	local Collapsed = CollapseTable( tableArg )
	return Collapsed[RandomInt( 1, #Collapsed, rng )]
end