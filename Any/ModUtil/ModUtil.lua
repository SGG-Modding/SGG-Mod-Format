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

	-- Setup
	
	local config = {
		AutoCollapse = true,
	}
	
	ModUtil = {
		config = config,
		modName = "ModUtil",
		WrapCallbacks = {},
		Mods = {},
		Overrides = {},
		Anchors = {Menu={},CloseFuncs={}},
		GlobalConnector = "__",
		FuncsToLoad = {},
		MarkedForCollapse = {},
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

	-- Management

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

	
	function ModUtil.LoadFuncs( triggerArgs )
		for k,v in pairs(ModUtil.FuncsToLoad) do
			v(triggerArgs)
		end
		ModUtil.FuncsToLoad = {}
	end
	OnAnyLoad{ModUtil.LoadFuncs}

	function ModUtil.LoadOnce( triggerFunction )
		table.insert( ModUtil.FuncsToLoad, triggerFunction )
	end

	function ModUtil.ForceClosed( triggerArgs )
		for k,v in pairs(ModUtil.Anchors.CloseFuncs) do
			v( nil, nil, triggerArgs )
		end
		ModUtil.Anchors.CloseFuncs = {}
		ModUtil.Anchors.Menu = {}
	end
	OnAnyLoad{ModUtil.ForceClosed}

	-- Data Misc

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
		if ModUtil.config.AutoCollapse then
			if not ModUtil.MarkedForCollapse[Table] then
				return ModUtil.IsUnKeyed( Table )
			else
				return false
			end
		end
		return false
	end

	-- Data Manipulation

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

	function ModUtil.SafeSet( Table, IndexArray, Value )
		if IsEmpty(IndexArray) then
			return -- can't set the input argument
		end
		local n = #IndexArray
		local node = Table
		for i = 1, n-1 do
			k = IndexArray[i]
			ModUtil.NewTable(node,k)
			node = node[k]
		end
		if (node[IndexArray[n]]==nil)~=(Value==nil) then
			if ModUtil.AutoIsUnKeyed( InTable ) then
				ModUtil.MarkForCollapse( node )
			end
		end
		node[IndexArray[n]] = Value
		return true
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

	function ModUtil.CollapseMarked()
		for k,v in pairs(ModUtil.MarkedForCollapse) do
			k = CollapseTable(k)
		end
		ModUtil.MarkedForCollapse = {}
	end
	OnAnyLoad{ModUtil.CollapseMarked}

	function ModUtil.MarkForCollapse( Table, IndexArray )
		ModUtil.MarkedForCollapse[ModUtil.SafeGet(Table, IndexArray)] = true
	end
	
	-- Path Manipulation

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

	function ModUtil.PathGet( Path, Base )
		return ModUtil.SafeGet(Base or _G, ModUtil.PathArray(Path))
	end

	function ModUtil.PathSet( Path, Value, Base )
		return ModUtil.SafeSet(Base or _G, ModUtil.PathArray(Path),Value)
	end

	function ModUtil.PathNilTable( Path, NilTable, Base )
		return ModUtil.MapNilTable( ModUtil.SafeGet(Base or _G, ModUtil.PathArray(Path)), NilTable )
	end

	function ModUtil.PathSetTable( Path, SetTable, Base )
		return ModUtil.MapSetTable( ModUtil.SafeGet(Base or _G, ModUtil.PathArray(Path)), SetTable )
	end

	-- Globalisation

	function ModUtil.GlobalisePath( Path )
		_G[ModUtil.JoinPath( Path )] = ModUtil.SafeGet(_G,ModUtil.PathArray( Path ))
	end
	
	function ModUtil.UpdateGlobalisedPath( Path, PathArray )
		local joinedPath = ModUtil.JoinPath( Path )
		if _G[joinedPath] then 
			if PathArray then
				_G[joinedPath] = ModUtil.SafeGet(_G,PathArray)
			else
				_G[joinedPath] = ModUtil.SafeGet(_G,ModUtil.PathArray( Path ))
			end
		end
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

	-- Function Wrapping

	function ModUtil.WrapFunction( funcTable, IndexArray, wrapFunc, modObject )
		if type(wrapFunc) ~= "function" then return end
		if not funcTable then return end
		local func = ModUtil.SafeGet(funcTable, IndexArray)
		if type(func) ~= "function" then return end

		ModUtil.NewTable(ModUtil.WrapCallbacks, funcTable)
		local tempTable = ModUtil.SafeGet(ModUtil.WrapCallbacks[funcTable], IndexArray)
		if tempTable == nil then
			tempTable = {}
			ModUtil.SafeSet(ModUtil.WrapCallbacks[funcTable], IndexArray, tempTable)
		end
		table.insert(tempTable, {id=#tempTable+1,mod=modObject,wrap=wrapFunc,func=func})
		
		ModUtil.SafeSet(funcTable, IndexArray, function( ... )
			return wrapFunc( func, ... )
		end)
	end
	
	function ModUtil.RewrapFunction( funcTable, IndexArray )
		local wrapCallbacks = ModUtil.SafeGet(ModUtil.WrapCallbacks[funcTable], IndexArray)
		local preFunc = nil
		
		for i,t in ipairs(wrapCallbacks) do
			if preFunc then
				t.func = preFunc
			end
			preFunc = function( ... )
				return t.wrap( t.func, ... )
			end
			ModUtil.SafeSet(funcTable, IndexArray, preFunc )
		end

	end
	
	function ModUtil.UnwrapFunction( funcTable, IndexArray )
		if not funcTable then return end
		local func = ModUtil.SafeGet(funcTable, IndexArray)
		if type(func) ~= "function" then return end

		local tempTable = ModUtil.SafeGet(ModUtil.WrapCallbacks[funcTable], IndexArray)
		if not tempTable then return end 
		local funcData = table.remove(tempTable)
		if not funcData then return end
		
		ModUtil.SafeSet( funcTable, IndexArray, funcData.func )
		return funcData
	end

	function ModUtil.WrapBaseFunction( baseFuncPath, wrapFunc, modObject )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.WrapFunction( _G, pathArray, wrapFunc, modObject )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end
	
	function ModUtil.RewrapBaseFunction( baseFuncPath )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.RewrapFunction( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end
	
	function ModUtil.UnwrapBaseFunction( baseFuncPath )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.UnwrapFunction( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end

	-- Override Management

	function ModUtil.Override( baseTable, IndexArray, Value, modObject )
		if not baseTable then return end
	
		local baseValue = ModUtil.SafeGet(baseTable, IndexArray)
		local wrapCallbacks = nil
		if type(baseValue) == "function" and type(Value) == "function" then
			wrapCallbacks = ModUtil.SafeGet(ModUtil.WrapCallbacks[baseTable], IndexArray)
			if wrapCallbacks then if wrapCallbacks[1] then
				baseValue = wrapCallbacks[1].func 
				wrapCallbacks[1].func = Value
			end end
		end
		
		ModUtil.NewTable(ModUtil.Overrides, baseTable)
		local tempTable = ModUtil.SafeGet(ModUtil.Overrides[baseTable], IndexArray)
		if tempTable == nil then
			tempTable = {}
			ModUtil.SafeSet(ModUtil.Overrides[baseTable], IndexArray, tempTable)
		end
		table.insert(tempTable, {id=#tempTable+1,mod=modObject,value=Value,base=baseValue})
		
		if wrapCallbacks then if wrapCallbacks[1] then
			ModUtil.RewrapFunctions( baseTable, IndexArray )
			return end
		else
			ModUtil.SafeSet( baseTable, IndexArray, Value )
		end
	end
	
	function ModUtil.Restore( baseTable, IndexArray )
		if not baseTable then return end
		local tempTable = ModUtil.SafeGet(ModUtil.Overrides[baseTable], IndexArray)
		if not tempTable then return end
		local baseData = table.remove(tempTable)
		if not baseData then return end
		
		if type(baseData.base) == "function" then
			local wrapCallbacks = ModUtil.SafeGet(ModUtil.WrapCallbacks[baseTable], IndexArray)
			if wrapCallbacks then if wrapCallbacks[1] then
				wrapCallbacks[1].func = baseData.base
				ModUtil.RewrapFunction( baseTable, IndexArray )
				return baseData
			end end
		end
		
		ModUtil.SafeSet( baseTable, IndexArray, baseData.base )
		return baseData
	end
	
	function ModUtil.BaseOverride( basePath, Value, modObject )
		local pathArray = ModUtil.PathArray( basePath )
		ModUtil.Override( _G, pathArray, Value, modObject )
		ModUtil.UpdateGlobalisedPath( basePath, pathArray )
	end
	
	function ModUtil.BaseRestore( basePath )
		local pathArray = ModUtil.PathArray( basePath )
		ModUtil.Restore( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( basePath, pathArray )
	end
	
	-- Misc
	
	function ModUtil.RandomElement(Table,rng)
		local Collapsed = CollapseTable(Table)
		return Collapsed[RandomInt(1, #Collapsed, rng)]
	end
	
	function ModUtil.RandomColor(rng)
		return ModUtil.RandomElement(Color,rng)
	end
	
	-- Post Setup
	
	ModUtil.GlobaliseModFuncs( ModUtil )

end