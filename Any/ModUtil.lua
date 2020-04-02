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
		AutoCollapse = true,
		WrapCallbacks = {},
		Mods = {},
		ModOverrides = {},
		Anchors = {},
		
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

	function ModUtil.RegisterMod( modName )
		if not _G[modName] then
			_G[modName] = {}
			table.insert(ModUtil.Mods,_G[modName])
		end
		_G[modName].modName = modName
		SaveIgnores[modName]=true
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

	function ModUtil.InvertTable( Table )
		local inverseTable = {}
		for key,value in ipairs(tableArg) do
			inverseTable[value]=key
		end
		return inverseTable
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

	function ModUtil.SafeGet( Table, IndexArray )
		if IsEmpty(IndexArray) then
			return Table
		end
		local n = #IndexArray
		local node = Table
		for k, i in ipairs(IndexArray) do
			if type(node) ~= "table" then
				return nil
			end
			if k == n then
				return node[i]
			end
			node = Table[i]
		end
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
				return
			end
			if k == n then
				local unkeyed = ModUtil.AutoIsUnKeyed( InTable )
				node[i] = Value
				if Value == nil and unkeyed then
					ModUtil.MarkForCollapse( node )
				end
				return
			end
			node = Table[i]
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

	function ModUtil.WrapBaseFunction( baseFuncName, wrapFunc, modObject )
		if type(wrapFunc) ~= "function" then return end
		if not baseFuncName then return end
		if type(_G[baseFuncName]) ~= "function" then return end
		local baseFunc = _G[baseFuncName]
		if type(modObject) == "table" then 
			ModUtil.SafeSet(modObject, {"BaseFunctions",baseFuncName}, _G[baseFuncName])
			if type(ModUtil.WrapCallbacks[baseFuncName]) == "table" then
				table.insert(ModUtil.WrapCallbacks[baseFuncName],modObject)
			else
				ModUtil.WrapCallbacks[baseFuncName] = {modObject}
			end
		end
		_G[baseFuncName] = function( ... )
			return wrapFunc( baseFunc, ... )
		end
		if type(modObject) == "table" then 
			ModUtil.SafeSet(modObject, {"WrappedFunctions",baseFuncName}, _G[baseFuncName])
		end
	end

	function ModUtil.StoreOverride( globalName , modObject )
		ModUtil.ModOverrides[globalName] = modObject 
		if not modObject.Overrides then
			modObject.Overrides = {}
		end
		modObject.Overrides[globalName] = _G[globalName]
	end
	
	function ModUtil.RandomColor(rng)
		local Color_Collapsed = CollapseTable(Color)
		return Color_Collapsed[RandomInt(1, #Color_Collapsed, rng)]
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
			
			local Ymul = 8
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
		
		function ModUtil.Hades.PrintStack( text, color, bgcol, delay, sound)
			if type(text) ~= "string" then
				text = tostring(text)
			end
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
			if color == nil then
				color = Color.Yellow
			end
			if delay == nil then
				delay = 5
			end
			if ModUtil.Anchors.PrintDisplay then
				Destroy({Ids = ModUtil.Anchors.PrintDisplay.Id})
			end
			ModUtil.Anchors.PrintDisplay = CreateScreenComponent({Name = "BlankObstacle", Group = "PrintDisplay", X = 30, Y = 30 })
			CreateTextBox({ Id = ModUtil.Anchors.PrintDisplay.Id, Text = text, FontSize = 22, OffsetX = 50, OffsetY = 30, Color = color, Font = "UbuntuMonoBold"})
			
			if delay > 0 then
				thread(function()
					wait(delay)
					Destroy({Ids = ModUtil.Anchors.PrintDisplay.Id})
					ModUtil.Anchors.PrintDisplay = nil
				end)
			end
		end
	
		function ModUtil.Hades.PrintOverhead(text, delay, color, dest)
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
		
	end

end