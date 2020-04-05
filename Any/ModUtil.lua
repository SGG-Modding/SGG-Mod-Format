-- IMPORT @ DEFAULT
-- PRIORITY 0

--[[
Mod: Mod Utility
Author: MagicGonads 

	Library to allow mods to be more compatible with eachother
	To include in your mod you must tell the user that they require this mod.
	
	Use the mod importer to import this mod to ensure it is loaded in the right position.
	
	Or if you want add (before other mods) to the BOTTOM of DEFAULT
	"Import "../Mods/ModUtil/Scripts/ModUtil.lua""
	
	Mods can also manually import it by adding the statement to their script
]]

if not ModUtil then

	ModUtil = {
		modName = "ModUtil",
		AutoCollapse = true,
		WrapCallbacks = {},
		Mods = {},
		ModOverrides = {},
		Anchors = {Menu={},CloseFuncs={}},
		GlobalConnector = "__",
	}
	SaveIgnores["ModUtil"]=true

	local gameHints = {
		Hades=SetupHeroObject,
		Pyre=CommenceDraft,
		Transistor=GlobalTest,
	}
	for game,hint in pairs(gameHints) do
		ModUtil.Game = game
		ModUtil[game] = {}
		break
	end

	function ModUtil.RegisterMod( modName, parent )
		if not parent then
			parent = _G
			SaveIgnores[modName]=true
		end
		if not parent[modName] then
			parent[modName] = {}
			table.insert(ModUtil.Mods,parent[modName])
		end
		parent[modName].modName = modName
		parent[modName].modParent = modParent
		return parent[modName]
	end

	local FuncsToLoad = {}
	function ModUtil.LoadFuncs( triggerArgs )
		for k,v in pairs(FuncsToLoad) do
			v(triggerArgs)
		end
		FuncsToLoad = {}
	end
	OnAnyLoad{ModUtil.LoadFuncs}

	function ModUtil.LoadOnce( triggerFunction )
		table.insert( FuncsToLoad, triggerFunction )
	end

	local MarkedForCollapse = {}
	function ModUtil.CollapseMarked()
		for k,v in pairs(MarkedForCollapse) do
			k = CollapseTable(k)
		end
		MarkedForCollapse = {}
	end
	OnAnyLoad{ModUtil.CollapseMarked}

	function ModUtil.ForceClosed( triggerArgs )
		for k,v in pairs(ModUtil.Anchors.CloseFuncs) do
			v( nil, nil, triggerArgs )
		end
		ModUtil.Anchors.CloseFuncs = {}
		ModUtil.Anchors.Menu = {}
	end
	OnAnyLoad{ModUtil.ForceClosed}

	function ModUtil.RandomColor(rng)
		local Color_Collapsed = CollapseTable(Color)
		return Color_Collapsed[RandomInt(1, #Color_Collapsed, rng)]
	end

	function ModUtil.InvertTable( Table )
		local inverseTable = {}
		for key,value in ipairs(tableArg) do
			inverseTable[value]=key
		end
		return inverseTable
	end

	function ModUtil.ToString(o)
		--https://stackoverflow.com/a/27028488
		if type(o) == 'table' then
			local s = '{ '
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. ModUtil.ToString(v) .. ','
			end
			return s .. '} '
		else
			return tostring(o)
		end
	end

	function ModUtil.IsUnKeyed( Table )
		if type(Table) == "table" then
			local lk = 0
			for k, v in pairs(Table) do
				if type(k) ~= "number" then
					return false
				end
				if lk ~= k+1 then
					return false
				end
			end
			return true
		end
		return false
	end

	function ModUtil.AutoIsUnKeyed( Table )
		if ModUtil.AutoCollapse then
			if not MarkedForCollapse[Table] then
				return ModUtil.IsUnKeyed( Table )
			else
				return false
			end
		end
		return false
	end

	function ModUtil.NewTable( Table, key )
		if type(Table) ~= "table" then return end
		if Table[key] == nil then
			Table[key] = {}
		end
	end

	function ModUtil.SafeGet( Table, IndexArray )
		local n = #IndexArray
		local node = Table
		for k, i in ipairs(IndexArray) do
			if type(node) ~= "table" then
				return nil
			end
			node = node[i]
		end
		return node
	end
	
	function ModUtil.MarkForCollapse( Table, IndexArray )
		MarkedForCollapse[ModUtil.SafeGet(Table, IndexArray)] = true
	end

	function ModUtil.SafeSet( Table, IndexArray, Value )
		if IsEmpty(IndexArray) then
			return -- can't set the input argument
		end
		local n = #IndexArray
		local node = Table
		for k, i in ipairs(IndexArray) do
			if type(node) ~= "table" then
				return false
			end
			if k == n then
				local unkeyed = ModUtil.AutoIsUnKeyed( InTable )
				node[i] = Value
				if Value == nil and unkeyed then
					ModUtil.MarkForCollapse( node )
				end
				return true
			end
			node = node[i]
		end
	end

	function ModUtil.MapNilTable( InTable, NilTable )
		local unkeyed = ModUtil.AutoIsUnKeyed( InTable )
		for NilKey, NilVal in pairs(NilTable) do
			local InVal = InTable[NilKey]
			if type(NilVal) == "table" and type(InVal) == "table" then
				ModUtil.MapNilTable( InVal, NilVal )
			else
				InTable[NilKey] = nil
				if unkeyed then 
					ModUtil.MarkForCollapse(InTable)
				end
			end
		end
	end

	function ModUtil.MapSetTable( InTable, SetTable )
		local unkeyed = ModUtil.AutoIsUnKeyed( InTable )
		for SetKey, SetVal in pairs(SetTable) do
			local InVal = InTable[SetKey]
			if type(SetVal) == "table" and type(InVal) == "table" then
				ModUtil.MapSetTable( InVal, SetVal )
			else
				InTable[SetKey] = SetVal
				if type(SetKey) ~= "number" and unkeyed then
					ModUtil.MarkForCollapse(InTable)
				end
			end
		end
	end

	function ModUtil.JoinIndexArrays( A, B )
		local C = {}
		local j = 0
		for i,v in ipairs(A) do
			C[i]=v
			j = i
		end
		for i,v in ipairs(B) do
			C[i+j]=v
		end
		return C
	end
	
	function ModUtil.PathArray( Path )
		local s = ""
		local i = {}
		for c in Path:gmatch(".") do
			if c ~= "." then
				s = s .. c
			else
				table.insert(i,s)
				s = ""
			end
		end
		if #s > 0 then
			table.insert(i,s)
		end
		return i
	end
	
	function ModUtil.JoinPath( Path )
		local s = ""
		for c in Path:gmatch(".") do
			if c ~= "." then
				s = s .. c
			else
				s = s .. ModUtil.GlobalConnector
			end
		end
		return s
	end

	function ModUtil.WrapFunction( funcTable, funcIndexArray, wrapFunc, modObject )
		if type(wrapFunc) ~= "function" then return end
		if not funcTable then return end
		
		local func = ModUtil.SafeGet(funcTable, funcIndexArray)
		if type(func) ~= "function" then return end

		if type(modObject) == "table" then 
			ModUtil.NewTable( modObject, "BaseFunctions" )
			ModUtil.NewTable( modObject.BaseFunctions, funcTable )
			ModUtil.SafeSet(modObject.BaseFunctions[funcTable], funcIndexArray, func)
			ModUtil.NewTable( ModUtil.WrapCallbacks, funcTable )
			ModUtil.SafeSet(ModUtil.WrapCallbacks[funcTable], funcIndexArray, modObject)
		end
		ModUtil.SafeSet(funcTable, funcIndexArray, function( ... )
			return wrapFunc( func, ... )
		end)
		if type(modObject) == "table" then
			ModUtil.NewTable( modObject, "WrappedFunctions" )
			ModUtil.NewTable( modObject.WrappedFunctions, funcTable )
			ModUtil.SafeSet(modObject.WrappedFunctions[funcTable], funcIndexArray, ModUtil.SafeGet(funcTable, funcIndexArray))
		end
	end

	function ModUtil.WrapBaseFunction( baseFuncPath, wrapFunc, modObject )
		ModUtil.WrapFunction( _G, ModUtil.PathArray( baseFuncPath ), wrapFunc, modObject )
	end

	function ModUtil.Override( baseTable, IndexArray, modObject )
		ModUtil.ModOverrides[baseTable] = modObject 
		ModUtil.NewTable( modObject, "Overrides" )
		ModUtil.SafeSet(modObject.Overrides[baseTable], IndexArray, ModUtil.SafeGet(baseTable, IndexArray))
	end
	
	function ModUtil.BaseOverride( basePath, modObject )
		ModUtil.Override( _G, ModUtil.PathArray( basePath ), modObject )
	end
	
	function ModUtil.GlobalisePath( Path )
		_G[ModUtil.JoinPath( Path )] = ModUtil.SafeGet(_G,ModUtil.PathArray( Path ))
	end
	
	function ModUtil.GlobaliseFuncs( Table, Path )
		if Path == nil then
			Path = ""
		end
		for k,v in pairs( Table ) do
			if type(k) == "string" then
				if type(v) == "function" then
					_G[ModUtil.JoinPath( Path.."."..k )] = v
				elseif type(v) == "table" then
					ModUtil.GlobaliseFuncs( v, Path.."."..k )
				end
			end
		end
	end
	
	function ModUtil.GlobaliseModFuncs( modObject )
		local parent = modObject
		while parent.modParent do
			parent = parent.modParent
			if parent == _G then break end
		end
		ModUtil.GlobaliseFuncs( modObject, modObject.modName )
	end
	
	if ModUtil.Pyre then 
		
		if CampaignStartup then
			ModUtil.Pyre.Gamemode = "Campaign"
			ModUtil.Pyre.Campaign = {}
		else
			ModUtil.Pyre.Gamemode = "Versus"
			ModUtil.Pyre.Versus = {}
		end
		
	end
	
	if ModUtil.Hades then
	
		function ModUtil.Hades.CloseMenu( screen, button )
			CloseScreen(GetAllIds(screen.Components), 0.1)
			ModUtil.Anchors.Menu[screen.Name] = nil
			screen.KeepOpen = false
			OnScreenClosed({ Flag = screen.Name })
			if TableLength(ModUtil.Anchors.Menu) == 0 then
				DisableShopGamepadCursor()
				UnfreezePlayerUnit()
				SetConfigOption({ Name = "FreeFormSelectWrapY", Value = false })
				SetConfigOption({ Name = "UseOcclusion", Value = true })
			end
			if ModUtil.Anchors.CloseFuncs[screen.Name] then
				ModUtil.Anchors.CloseFuncs[screen.Name]( screen, button )
				ModUtil.Anchors.CloseFuncs[screen.Name]=nil
			end
		end
	
		function ModUtil.Hades.OpenMenu( group, closeFunc )
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
			
			return screen
		end
		
		function ModUtil.Hades.DimMenu( screen )
			if not screen.Components.BackgroundDim then
				screen.Components.BackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = screen.Name })
				SetScale({ Id = screen.Components.BackgroundDim.Id, Fraction = 4 })
			end
			SetColor({ Id = screen.Components.BackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.8} })
		end
		
		function ModUtil.Hades.UndimMenu( screen )
			if not screen.Components.BackgroundDim then return end
			SetColor({ Id = screen.Components.BackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0} })
		end
		
		function ModUtil.Hades.PostOpenMenu( group )
			local screen = ModUtil.Anchors.Menu[group]
			FreezePlayerUnit()
			EnableShopGamepadCursor()
			thread(HandleWASDInput, screen)
			HandleScreenInput(screen)
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
			--Background
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
		
		function ModUtil.Hades.NewMenuYesNo( name, yesFunc, noFunc, closeFunc, title, body, yesText, noText, icon, iconScale)
			if not name or name == "" then return end
			if not yesFunc or not noFunc then return end
			if not icon then icon = "AmmoPack" end
			if not iconScale then iconScale = 1 end
			if not yesText then yesText = "Yes" end
			if not noText then noText = "No" end
			if not body then body = "Make a choice..." end
			if not title then title = name end
			
			local group = "MenuYesNo_"..name
			
			local screen = ModUtil.Hades.OpenMenu( group, closeFunc )
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
			
			ModUtil.Hades.PostOpenMenu( group )
		end
		
		function ModUtil.Hades.CloseMenuYesNo( screen, button )
			PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENU" })
			_G[ModUtil.JoinPath("ModUtil.Anchors.Menu."..screen.Name..".Funcs.Yes")]=nil
			_G[ModUtil.JoinPath("ModUtil.Anchors.Menu."..screen.Name..".Funcs.No")]=nil
			ModUtil.Hades.CloseMenu( screen, button )
		end
		
	end
	
	ModUtil.GlobaliseModFuncs( ModUtil )

end