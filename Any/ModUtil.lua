-- IMPORT @ DEFAULT
-- PRIORITY 0

--[[
Mod: Mod Utility
Author: MagicGonads 

	Library to allow mods to be more compatible with eachother
	To include in your mod you must tell the user that they require this mod.
	
	To use add (before other mods) to the BOTTOM of DEFAULT
	"Import "../Mods/ModUtil/Scripts/ModUtil.lua""
	
	Mods can also manually import it by ading the statement to their script
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
		Pyre=CampaignStartup,
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
	
		function ModUtil.Pyre.PrintDisplay( text , delay, color )
			if color == nil then
				color = Color.Yellow
			end
			if delay == nil then
				delay = 5
			end
			Destroy({Ids = ModUtil.Anchors.PrintDisplay})
			ModUtil.Anchors.PrintDisplay = { Components = {} }
			local screen = ModUtil.Anchors.PrintDisplay
			local components = screen.Components
			screen.Name = "PrintDisplay"
			components.Block = SpawnObstacle({ Name = "BlankObstacle", Group = "PrintDisplay", X = 30, Y = 30 })
			DisplayWorldText({ Id = components.Block.Id, Text = text, FontSize = 22, OffsetX = 50, OffsetY = 30, Color = color, Font = "UbuntuMonoBold"})
			wait(delay)
			if delay > 0 then
				RemoveWorldText({ DestinationId = components.Block, Duration = 0.3 })
				Destroy({Ids = ModUtil.Anchors.PrintDisplay})
				ModUtil.Anchors.PrintDisplay = nil
			end
		end
	
	end
	
	if ModUtil.Hades then
	
		function ModUtil.Hades.PrintDisplay( text , delay, color )
			if color == nil then
				color = Color.Yellow
			end
			if delay == nil then
				delay = 5
			end
			Destroy({Ids = ModUtil.Anchors.PrintDisplay})
			ModUtil.Anchors.PrintDisplay = { Components = {} }
			local screen = ModUtil.Anchors.PrintDisplay
			local components = screen.Components
			screen.Name = "PrintDisplay"
			components.Block = CreateScreenComponent({ Name = "BlankObstacle", Group = "PrintDisplay", X = 30, Y = 30 })
			CreateTextBox({ Id = components.Block.Id, Text = text, FontSize = 22, OffsetX = 50, OffsetY = 30, Color = color, Font = "UbuntuMonoBold"})
			wait(delay, RoomThreadName)
			if delay > 0 then
				Destroy({Ids = ModUtil.Anchors.PrintDisplay})
				ModUtil.Anchors.PrintDisplay = nil
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
			Destroy({Ids = ScreenAnchors.HoldDisplayId})
			ScreenAnchors.HoldDisplayId = SpawnObstacle({ Name = "BlankObstacle", Group = "Events", DestinationId = dest })
			Attach({ Id = ScreenAnchors.HoldDisplayId, DestinationId = dest })
			CreateTextBox({ Id = ScreenAnchors.HoldDisplayId, Text = text, FontSize = 32, OffsetX = 0, OffsetY = -150, Color = color, Font = "UbuntuMonoBold", Justification = "Center" })
			wait(delay, RoomThreadName)
			if delay > 0 then
				Destroy({Ids = ScreenAnchors.HoldDisplayId})
				ScreenAnchors.HoldDisplayId = nil
			end
		end
		
	end

end