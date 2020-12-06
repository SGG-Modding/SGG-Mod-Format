--[[
Mod: Mod Utility
Author: MagicGonads 

	Library to allow mods to be more compatible with eachother and expand capabilities.
	Use the mod importer to import this mod to ensure it is loaded in the right position.
	
]]

if not ModUtil then

	-- Setup
	
	local Config = {
		AutoCollapse = true,
	}
	
	ModUtil = {
		Config = Config,
		ModName = "ModUtil",
		WrapCallbacks = {},
		Mods = {},
		Overrides = {},
		Anchors = {Menu={},CloseFuncs={}},
		GlobalConnector = "__",
		FuncsToLoad = {},
		MarkedForCollapse = {},
	}
	SaveIgnores["ModUtil"]=true

	local GameHints = {
		Hades=SetupHeroObject,
		Pyre=CommenceDraft,
		Transistor=GlobalTest,
	}
	for game,hint in pairs(GameHints) do
		ModUtil.Game = game
		ModUtil[game] = {}
		break
	end

	-- Management

	--[[
		Create a namespace that can be used for the mod's functions
		and data, and ensure that it doesn't end up in save files.

		modName - the name of the mod
		parent	- the parent mod, or nil if this mod stands alone
	]]
	function ModUtil.RegisterMod( modName, parent )
		if not parent then
			parent = _G
			SaveIgnores[modName]=true
		end
		if not parent[modName] then
			parent[modName] = {}
			table.insert( ModUtil.Mods, parent[modName] )
		end
		parent[modName].ModName = modName
		parent[modName].ModParent = parent
		return parent[modName]
	end

	-- internal
	function ModUtil.LoadFuncs( triggerArgs )
		for k,v in pairs(ModUtil.FuncsToLoad) do
			v(triggerArgs)
		end
		ModUtil.FuncsToLoad = {}
	end
	OnAnyLoad{ModUtil.LoadFuncs}

	--[[
		Run the provided function once on the next in-game load.

		triggerFunction - the function to run
	]]
	function ModUtil.LoadOnce( triggerFunction )
		table.insert( ModUtil.FuncsToLoad, triggerFunction )
	end

	--[[
		Tell each screen anchor that they have been forced closed by the game
	]]
	function ModUtil.ForceClosed( triggerArgs )
		for k,v in pairs( ModUtil.Anchors.CloseFuncs ) do
			v( nil, nil, triggerArgs )
		end
		ModUtil.Anchors.CloseFuncs = {}
		ModUtil.Anchors.Menu = {}
	end
	OnAnyLoad{ModUtil.ForceClosed}

	-- Data Misc

	function ModUtil.ValueString( o )
		if type( o ) == 'string' then
			return '"'..o..'"'
		end
		return tostring( o )
	end
	
	function ModUtil.KeyString( o )
		if type( o ) == 'number' then o = o..'.' end
		return tostring( o )
	end

	function ModUtil.TableKeysString( o )
		if type( o ) == 'table' then
			local first = true
			local s = ''
			for k,v in pairs( o ) do
				if not first then s = s .. ', ' else first = false end
				s = s .. ModUtil.KeyString( k )
			end
			return s
		end
	end

	function ModUtil.ToString( o )
		--https://stackoverflow.com/a/27028488
		if type( o ) == 'table' then
			local first = true
			local s = '{'
			for k,v in pairs( o ) do
				if not first then s = s .. ', ' else first = false end
				s = s .. ModUtil.KeyString( k ) ..' = ' .. ModUtil.ToString( v )
			end
			return s .. '}'
		else
			return ModUtil.ValueString( o )
		end
	end

	function ModUtil.ToStringLimited( o, n, m, t, j)
		if type( o ) == 'table' then
			local first = true
			local s = ''
			local i = 0
			local go = true
			if not j then j = 1 end
			if not m then m = 0 end
			if not t then t = {} end
			for k,v in pairs( o ) do
				if t[j] then go = type( v ) == t[j] or t[j] == true end
				if go then
					i = i + 1
					if n then if i > n+m then return s end end
					if m < i then
						if not first then s = s .. ', ' else first = false end
						if type( v ) == "table" and t[j+1] then
							s = s .. ModUtil.KeyString( k ) ..' = ('..ModUtil.ToStringLimited( v, n, m, t, j+1 )..')'
						else
							s = s .. ModUtil.KeyString( k ) ..' = '..ModUtil.ValueString( v )
						end
					end
				end
			end
			return s
		else
			return ModUtil.ValueString( o )
		end
	end

	function ModUtil.ChunkText( text, chunkSize, maxChunks )
		local chunks = {""}
		local cs = 0
		local ncs = 1
		for chr in text:gmatch( "." ) do
			cs = cs + 1
			if cs > chunkSize or chr == "\n" then
				ncs = ncs + 1
				if maxChunks then
					if ncs > maxChunks then
						return chunks
					end
				end
				chunks[ncs] = ""
				cs = 0
			end
			if chr ~= "\n" then
				chunks[ncs] = chunks[ncs] .. chr
			end
		end
		return chunks
	end

	function ModUtil.InvertTable( tableArg )
		local inverseTable = {}
		for key,value in ipairs( tableArg ) do
			inverseTable[value] = key
		end
		return inverseTable
	end

	function ModUtil.IsUnKeyed( tableArg )
		local lk = 0
		for k, v in pairs( tableArg ) do
			if type( k ) ~= "number" then
				return false
			end
			if lk+1 ~= k then
				return false
			end
			lk = k
		end
		return true
	end

	function ModUtil.AutoIsUnKeyed( tableArg )
		if ModUtil.Config.AutoCollapse then
			if not ModUtil.MarkedForCollapse[ tableArg ] then
				return ModUtil.IsUnKeyed( tableArg )
			else
				return false
			end
		end
		return false
	end

	-- Data Manipulation

	--[[
		Safely create a new empty table at Table.key.

		Table - the table to modify
		key	 - the key at which to store the new empty table
	]]
	function ModUtil.NewTable( tableArg, key )
		if type( tableArg ) ~= "table" then return end
		if tableArg[key] == nil then
			tableArg[key] = {}
		end
	end
	
	--[[
		Safely retrieve the a value from deep inside a table, given
		an array of indices into the table.

		For example, if indexArray is ["a", 1, "c"], then
		Table["a"][1]["c"] is returned. If any of Table["a"],
		Table["a"][1], or Table["a"][1]["c"] are nil, then nil
		is returned instead.

		Table			 - the table to retrieve from
		indexArray	- the list of indices
	]]
	function ModUtil.SafeGet( baseTable, indexArray )
		local n = #indexArray
		local node = baseTable
		for k, i in ipairs( indexArray ) do
			if type( node ) ~= "table" then
				return nil
			end
			node = node[i]
		end
		return node
	end

	--[[
		Safely set a value deep inside a table, given an array of
		indices into the table, and creating any necessary tables
		along the way.

		For example, if indexArray is ["a", 1, "c"], then
		Table["a"][1]["c"] = Value once this function returns.
		If any of Table["a"] or Table["a"][1] does not exist, they
		are created.

		Table			 - the table to set the value in
		indexArray	- the list of indices
		Value			 - the value to add
	]]
	function ModUtil.SafeSet( baseTable, indexArray, value )
		if IsEmpty( indexArray ) then
			return false -- can't set the input argument
		end
		local n = #indexArray
		local node = baseTable
		for i = 1, n-1 do
			k = indexArray[i]
			ModUtil.NewTable( node, k )
			node = node[k]
		end
		if ( node[indexArray[n]] == nil ) ~= ( value == nil ) then
			if ModUtil.AutoIsUnKeyed( InTable ) then
				ModUtil.MarkForCollapse( node )
			end
		end
		node[indexArray[n]] = value
		return true
	end

	--[[
		Set all the values in inTable corresponding to keys
		in nilTable to nil.

		For example, if inTable is 
		{
			Foo = 5,
			Bar = 6,
			Baz = {
				InnerFoo = 5,
				InnerBar = 6
			}
		}

		and nilTable is
		{
			Foo = true,
			Baz = {
				InnerBar = true
			}
		}

		then the result will be
		{
			Foo = nil
			Bar = 6,
			Baz = {
				InnerFoo = 5,
				InnerBar = nil
			}
		}
	]]
	function ModUtil.MapNilTable( inTable, nilTable )
		local unkeyed = ModUtil.AutoIsUnKeyed( inTable )
		for nilKey, nilVal in pairs( nilTable ) do
			local inVal = inTable[nilKey]
			if type(nilVal) == "table" and type( inVal ) == "table" then
				ModUtil.MapNilTable( inVal, nilVal )
			else
				inTable[nilKey] = nil
				if unkeyed then 
					ModUtil.MarkForCollapse( inTable )
				end
			end
		end
	end

	--[[
		Set all the the values in inTable corresponding to values
		in setTable to their values in setTable.

		For example, if inTable is
		{
			Foo = 5,
			Bar = 6
		}

		and setTable is
		{
			Foo = 7,
			Baz = {
				InnerBar = 8
			}
		}

		then the result will be
		{
			Foo = 7,
			Bar = 6,
			Baz = {
				InnerBar = 8
			}
		}
	]]
	function ModUtil.MapSetTable( inTable, setTable )
		local unkeyed = ModUtil.AutoIsUnKeyed( inTable )
		for setKey, setVal in pairs( setTable ) do
			local inVal = inTable[setKey]
			if type( setVal ) == "table" and type( inVal ) == "table" then
				ModUtil.MapSetTable( inVal, setVal )
			else
				inTable[setKey] = setVal
				if type( setKey ) ~= "number" and unkeyed then
					ModUtil.MarkForCollapse( inTable )
				end
			end
		end
	end

	local function CollapseTable( tableArg )
		-- from UtilityScripts.lua
		if tableArg == nil then
			return
		end

		local collapsedTable = {}
		local index = 1
		for k, v in pairs( tableArg ) do
			collapsedTable[index] = v
			index = index + 1
		end

		return collapsedTable

	end

	function ModUtil.CollapseMarked()
		for k,v in pairs( ModUtil.MarkedForCollapse ) do
			k = CollapseTable( k )
		end
		ModUtil.MarkedForCollapse = {}
	end
	OnAnyLoad{ModUtil.CollapseMarked}

	function ModUtil.MarkForCollapse( baseTable, indexArray )
		ModUtil.MarkedForCollapse[ModUtil.SafeGet( baseTable, indexArray )] = true
	end
	
	-- Path Manipulation

	--[[
		Concatenates two index arrays, in order.

		a, b - the index arrays
	]]
	function ModUtil.JoinIndexArrays( a, b )
		local c = {}
		local j = 0
		for i,v in ipairs(a) do
			c[i] = v
			j = i
		end
		for i,v in ipairs(b) do
			c[i+j] = v
		end
		return c
	end
	
	--[[
		Create an index array from the provided Path.

		The returned array can be used as an argument to the safe table
		manipulation functions, such as ModUtil.SafeSet and ModUtil.SafeGet.

		path - a dot-separated string that represents a path into a table
	]]
	function ModUtil.PathArray( path )
		local s = ""
		local i = {}
		for c in path:gmatch( "." ) do
			if c ~= "." then
				s = s .. c
			else
				table.insert( i, s )
				s = ""
			end
		end
		if #s > 0 then
			table.insert( i,s )
		end
		return i
	end
	
	--[[
		Mangles a provide path so that it is safe to use to index a table, by
		replacing the periods with ModUtil.GlobalConnector.

		This is useful to create a unique global key from a path, in for interoperability
		with utilities that don't understand paths or index arrays.

		For example, the OnPressedFunctionName of a button must refer to a single key 
		in the globals table (_G); if you have a Path then JoinPath may be used to create such a key.
	]]
	function ModUtil.JoinPath( path )
		local s = ""
		for c in path:gmatch( "." ) do
			if c ~= "." then
				s = s .. c
			else
				s = s .. ModUtil.GlobalConnector
			end
		end
		return s
	end

	--[[
		Safely get a value from a Path.

		For example, ModUtil.PathGet("a.b.c") returns a.b.c.
		If either a or a.b is nil, nil is returned instead.

		path - the path to get the value
		base - (optional) The table to retreive the value from.
					 If not provided, retreive a global.
	]]
	function ModUtil.PathGet( path, base )
		return ModUtil.SafeGet( base or _G, ModUtil.PathArray( path ) )
	end

	--[[
		Safely get set a value to a Path.

		For example, ModUtil.PathSet("a.b.c", 1) sets a.b.c = 1.
		If either a or a.b is nil, they are created.

		path - the path to get the value
		base - (optional) The table to retreive the value from.
					 If not provided, retreive a global.
	]]
	function ModUtil.PathSet( path, value, base )
		return ModUtil.SafeSet( base or _G, ModUtil.PathArray( path ), value )
	end

	function ModUtil.PathNilTable( path, nilTable, base )
		return ModUtil.MapNilTable( ModUtil.PathGet( path, base ), nilTable )
	end

	function ModUtil.PathSetTable( path, setTable, base )
		return ModUtil.MapSetTable( ModUtil.PathGet( path, base ), setTable )
	end

	-- Globalisation

	--[[
		Sets a unique global variable equal to the value stored at Path.

		For example, the OnPressedFunctionName of a button must refer to a single key
		in the globals table (_G). If you have a function defined in your module's
		table that you would like to use, ie.

			function YourModName.FunctionName(...)

		then ModUtil.GlobalizePath("YourModName.FunctionName") will create a global
		variable for that function, and you can then set OnPressedFunctionName to
		ModUtil.JoinPath("YourModName.FunctionName").

		path - the path to be globalised
	]]
	function ModUtil.GlobalisePath( path )
		_G[ModUtil.JoinPath( path )] = ModUtil.SafeGet( _G, ModUtil.PathArray( path ) )
	end
	
	--[[
		Updates the global created by ModUtil.GlobalisePath, to pick up any
		changes to the value at the Path.

		path			- the path to be globalised
		pathArray	- (optional) if present, retrive the updated value from
								a location other than the default ModUtil.PathArray(Path)
	]]
	function ModUtil.UpdateGlobalisedPath( path, pathArray )
		local joinedPath = ModUtil.JoinPath( path )
		if _G[joinedPath] then 
			if pathArray then
				_G[joinedPath] = ModUtil.SafeGet( _G, pathArray )
			else
				_G[joinedPath] = ModUtil.SafeGet( _G, ModUtil.PathArray( path ) )
			end
		end
	end
	
	--[[
		Makes all the functions in Table available globally, as if
		ModUtil.GlobalisePath had been called on each of them.
		
		If you have a lot of functions you need to export for UI or
		other by-name callbacks, it will be eaiser to maintain a single
		call to ModUtil.GlobaliseFuncs at the bottom of your mod file,
		rather than having a bunch of GlobalisePath calls that need to
		be maintained.

		For example, if you have a table at YourModName.UIFunctions with

		function YourModName.UIFunctions.OnButton1(...)
		function YourModName.UIFunctiosn.OnButton2(...)

		then ModUtil.GlobaliseFuncs(YourModName.UIFunctions) will create global
		functions called OnButton1 and OnButton2. If you are worried about
		collisions with other global functions, consider using a prefix ie.

			ModUtil.GlobaliseFuncs(YourModName.UIFunctions, "YourModNameUI")

		So that the global functions are called YourModNameUI__OnButton1 etc.

		tableArg	- The table containing the functions to globalise
		prefixPath	- (optional) if present, add this path as a prefix to the
						path from the root of the table.
	]]
	function ModUtil.GlobaliseFuncs( tableArg, prefixPath )
		if prefixPath == nil then
			prefixPath = ""
		end
		for k,v in pairs( tableArg ) do
			if type( k ) == "string" then
				if type(v) == "function" then
					_G[ModUtil.JoinPath( prefixPath .. "." .. k )] = v
				elseif type(v) == "table" then
					ModUtil.GlobaliseFuncs( v, prefixPath.."."..k )
				end
			end
		end
	end
	
	--[[
		Globalise all the functions in your mod object.

		modObject - The mod object created by ModUtil.RegisterMod
	]]
	function ModUtil.GlobaliseModFuncs( modObject )
		local parent = modObject
		local prefix = modObject.ModName
		while parent.ModParent do
			parent = parent.ModParent
			if parent == _G then break end
			prefix = parent.ModName .. "." .. prefix
		end
		ModUtil.GlobaliseFuncs( modObject, prefix )
	end


	-- Metaprogramming Shenanigans

	local function getfenv( fn )
		local i = 1
		while true do
			local name, val = debug.getupvalue(fn, i)
			if name == "_ENV" then
				return val
			elseif not name then
				break
			end
			i = i + 1
		end
	end

	--[[
		Replace a function's _ENV with a new environment table.

		Global variable lookups (including function calls) in that function
		will use the new environment table rather than the normal one.

		This is useful for function-specific overrides. The new environment
		table should generally have _G as its __index, so that any globals
		other than those being overridden can still be read.
	]]
	local function setfenv( fn, env )
		local i = 1
		while true do
			local name = debug.getupvalue( fn, i )
			if name == "_ENV" then
				debug.upvaluejoin( fn, i, (function()
					return env
				end), 1 )
				break
			elseif not name then
				break
			end
			i = i + 1
		end
		return fn
	end

	--[[
		Return a table representing the upvalues of a function.

		Upvalues are those variables captured by a function from it's
		creation context. For example, locals defined in the same file
		as the function are accessible to the function as upvalues.

		func - the function to get upvalues from
	]]
	function ModUtil.GetUpValues( func )
		if type( func ) ~= "function" then return nil end
		local key = {}
		local u = nil
		local i = 1
		while true do
			u = debug.getupvalue( func, i )
			if u == nil then break end
			key[i] = u
			i = i + 1
		end
		local ind = {}
		for i,k in pairs( key ) do
			ind[k] = i
		end
		local ups = {}
		setmetatable( ups, {
			__index = function( self, name )
				return debug.getupvalue( func, ind[name] )
			end,
			__newindex = function( self, name, value )
				debug.setupvalue( func, ind[name], value )
			end
		})
		return ups, ind, key
	end
	
	function ModUtil.GetBottomUpValues( baseTable, indexArray )
		local baseValue = ModUtil.SafeGet( ModUtil.Overrides[baseTable], indexArray )
		if baseValue then
			baseValue = baseValue[#baseValue].Base
		else
			baseValue = ModUtil.SafeGet( ModUtil.WrapCallbacks[baseTable], indexArray )
			if baseValue then
				baseValue = baseValue[1].func
			else
				baseValue = ModUtil.SafeGet( baseTable, indexArray )
			end
		end 
		return ModUtil.GetUpValues( baseValue )
	end

	--[[
		Return a table representing the upvalues of the base function identified
		by basePath (ie. ignoring all wrappers that other mods may have placed
		around the function).

		basePath - the path to the function, as a string
	]]
	function ModUtil.GetBaseBottomUpValues( basePath )
		return ModUtil.GetBottomUpValues( _G, ModUtil.PathArray( basePath ) )
	end

	-- Function Wrapping

	--[[
		Wrap a function, so that you can insert code that runs before/after that function
		whenever it's called, and modify the return value if needed.

		Generally, you should use ModUtil.WrapBaseFunction instead for a more modder-friendly
		interface.

		Multiple wrappers can be applied to the same function.

		As an example, for WrapFunction(_G, ["UIFunctions", "OnButton1Pushed"], wrapper, MyModObject)

		Wrappers are stored in a structure like this:

		ModUtil.WrapCallbacks[_G].UIFunctions.OnButton1Pushed = {
			{id:1, mod=MyModObject, wrap=wrapper, func=<original unwrapped function>}
		}

		If a second wrapper is applied via
			WrapFunction(_G, ["UIFunctions", "OnButton1Pushed"], wrapperFunction2, SomeOtherMod)
		then the resulting structure will be like:

		ModUtil.WrapCallbacks[_G].UIFunctions.OnButton1Pushed = {
			{id:1, mod=MyModObject,	wrap=wrapper,	func=<original unwrapped function>}
			{id:2, mod=SomeOtherMod, wrap=wrapper2, func=<original function + wrapper1>}
		}

		This allows several mods to apply wrappers to the same base function, and then:
		 - unwrap again later
		 - reapply the same wrappers to a new base function when it's overridden

		This function also updates the entry in funcTable at indexArray to be the completely
		wrapped function, ie. in our example with two wrappers it would do

		UIFunctions.OnButton1Pushed = <original function + wrapper1 + wrapper2>

		funcTable	 - the table the function is stored in (usually _G)
		indexArray	- the array of path elements to the function in the table
		wrapFunc		- the wrapping function
		modObject	 - (optional) the mod installing the wrapper, for informational purposes
	]]
	function ModUtil.WrapFunction( funcTable, indexArray, wrapFunc, modObject )
		if type( wrapFunc ) ~= "function" then return end
		if not funcTable then return end
		local func = ModUtil.SafeGet( funcTable, indexArray )
		if type( func ) ~= "function" then return end

		ModUtil.NewTable( ModUtil.WrapCallbacks, funcTable )
		local tempTable = ModUtil.SafeGet( ModUtil.WrapCallbacks[funcTable], indexArray )
		if tempTable == nil then
			tempTable = {}
			ModUtil.SafeSet( ModUtil.WrapCallbacks[funcTable], indexArray, tempTable )
		end
		table.insert( tempTable, { Id = #tempTable + 1, Mod = modObject, Wrap = wrapFunc, Func = func } )
		
		ModUtil.SafeSet( funcTable, indexArray, function( ... )
			return wrapFunc( func, ... )
		end )
	end
	
	--[[
		Internal utility that reapplies the list of wrappers when the base function changes.

		For example. if the list of wrappers looks like:
		ModUtil.WrapCallbacks[_G].UIFunctions.OnButton1Pushed = {
			{id:1, mod=MyModObject,	wrap=wrapper,	func=<original unwrapped function>}
			{id:2, mod=SomeOtherMod, wrap=wrapper2, func=<original function + wrapper1>}
			{id:3, mod=ModNumber3,	 wrap=wrapper3, func=<original function + wrapper1 + wrapper 2>}
		}

		and the base function is modified by setting [1].func to a new value, like so:
		ModUtil.WrapCallbacks[_G].UIFunctions.OnButton1Pushed = {
			{id:1, mod=MyModObject,	wrap=wrapper,	func=<new function>}
			{id:2, mod=SomeOtherMod, wrap=wrapper2, func=<original function + wrapper1>}
			{id:3, mod=ModNumber3,	 wrap=wrapper3, func=<original function + wrapper1 + wrapper 2>}
		}

		Then rewrap function will fix up eg. [2].func, [3].func so that the correct wrappers are applied
		ModUtil.WrapCallbacks[_G].UIFunctions.OnButton1Pushed = {
			{id:1, mod=MyModObject,	wrap=wrapper,	func=<new function>}
			{id:2, mod=SomeOtherMod, wrap=wrapper2, func=<new function + wrapper1>}
			{id:3, mod=ModNumber3,	 wrap=wrapper3, func=<new function + wrapper1 + wrapper 2>}
		}
		and also update the entry in funcTable to be the completely wrapped function, ie.

		UIFunctions.OnButton1Pushed = <new function + wrapper1 + wrapper2 + wrapper3>

		funcTable	 - the table the function is stored in (usually _G)
		indexArray	- the array of path elements to the function in the table
	]]
	function ModUtil.RewrapFunction( funcTable, indexArray )
		local wrapCallbacks = ModUtil.SafeGet( ModUtil.WrapCallbacks[funcTable], indexArray )
		local preFunc = nil
		
		for i,t in ipairs( wrapCallbacks ) do
			if preFunc then
				t.Func = preFunc
			end
			preFunc = function( ... )
				return t.Wrap( t.Func, ... )
			end
			ModUtil.SafeSet( funcTable, indexArray, preFunc )
		end

	end
	
	--[[
		Removes the most recent wrapper from a function, and restore it to its
		previous value.

		Generally, you should use ModUtil.UnwrapBaseFunction instead for a more
		modder-friendly interface.

		funcTable	 - the table the function is stored in (usually _G)
		indexArray	- the array of path elements to the function in the table
	]]
	function ModUtil.UnwrapFunction( funcTable, indexArray )
		if not funcTable then return end
		local func = ModUtil.SafeGet( funcTable, indexArray )
		if type( func ) ~= "function" then return end

		local tempTable = ModUtil.SafeGet( ModUtil.WrapCallbacks[funcTable], indexArray )
		if not tempTable then return end 
		local funcData = table.remove( tempTable ) -- removes the last value
		if not funcData then return end
		
		ModUtil.SafeSet( funcTable, indexArray, funcData.Func )
		return funcData
	end


	--[[
		Wraps the function with the path given by baseFuncPath, so that you
		can execute code before or after the original function is called,
		or modify the return value.

		For example:

		ModUtil.WrapBaseFunction("CreateNewHero", function(baseFunc, prevRun, args)
			local hero = baseFunc(prevRun, args)
			hero.Health = 1
			return hero
		end, YourMod)

		will cause the function CreateNewHero to be wrapped so that the hero's
		health is set to 1 before the hero is returned.

		This provides better compatibility with other mods that overriding the
		function, since multiple mods can wrap the same function.

		baseFuncPath	- the (global) path to the function, as a string
			for most SGG-provided functions, this is just the function's name
			eg. "CreateRoomReward" or "SetTraitsOnLoot"
		wrapFunc	- the function to wrap around the base function
			this function receives the base function as its first parameter.
			all subsequent parameters should be the same as the base function
		modObject	- (optional) the object for your mod, for debug purposes
	]]
	function ModUtil.WrapBaseFunction( baseFuncPath, wrapFunc, modObject )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.WrapFunction( _G, pathArray, wrapFunc, modObject )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end
	
	--[[
		Internal function that reapplies all the wrappers to a function.
	]]
	function ModUtil.RewrapBaseFunction( baseFuncPath )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.RewrapFunction( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end
	
	--[[
		Remove the most recent wrapper from the function at baseFuncPath,
		restoring it to its previous state

		Note that this does _not_ remove overrides, and it removes the most
		recent wrapper regardless of which mod added it, so be careful!

		baseFuncPath	- the (global) path to the function, as a string
			for most SGG-provided functions, this is just the function's name
			eg. "CreateRoomReward" or "SetTraitsOnLoot"
	]]
	function ModUtil.UnwrapBaseFunction( baseFuncPath )
		local pathArray = ModUtil.PathArray( baseFuncPath )
		ModUtil.UnwrapFunction( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( baseFuncPath, pathArray )
	end

	-- Override Management

	function ModUtil.Override( baseTable, indexArray, value, modObject )
		if not baseTable then return end
	
		local baseValue = ModUtil.SafeGet( baseTable, indexArray )
		local wrapCallbacks = nil
		if type( baseValue ) == "function" and type( value ) == "function" then
			wrapCallbacks = ModUtil.SafeGet( ModUtil.WrapCallbacks[baseTable], indexArray )
			if wrapCallbacks then if wrapCallbacks[1] then
				baseValue = wrapCallbacks[1].Func 
				wrapCallbacks[1].Func = value
			end end
		end
		
		ModUtil.NewTable( ModUtil.Overrides, baseTable )
		local tempTable = ModUtil.SafeGet( ModUtil.Overrides[baseTable], indexArray )
		if tempTable == nil then
			tempTable = {}
			ModUtil.SafeSet( ModUtil.Overrides[baseTable], indexArray, tempTable )
		end
		table.insert( tempTable, { Id = #tempTable + 1, Mod = modObject, Value = value, Base = baseValue } )
		
		if wrapCallbacks then if wrapCallbacks[1] then
			ModUtil.RewrapFunction( baseTable, indexArray )
			return end
		else
			ModUtil.SafeSet( baseTable, indexArray, value )
		end
	end
	
	function ModUtil.Restore( baseTable, indexArray )
		if not baseTable then return end
		local tempTable = ModUtil.SafeGet( ModUtil.Overrides[baseTable], indexArray )
		if not tempTable then return end
		local baseData = table.remove( tempTable )
		if not baseData then return end
		
		if type( baseData.Base ) == "function" then
			local wrapCallbacks = ModUtil.SafeGet( ModUtil.WrapCallbacks[baseTable], indexArray )
			if wrapCallbacks then if wrapCallbacks[1] then
				wrapCallbacks[1].func = baseData.Base
				ModUtil.RewrapFunction( baseTable, indexArray )
				return baseData
			end end
		end
		
		ModUtil.SafeSet( baseTable, indexArray, baseData.Base )
		return baseData
	end
	
	function ModUtil.BaseOverride( basePath, value, modObject )
		local pathArray = ModUtil.PathArray( basePath )
		ModUtil.Override( _G, pathArray, value, modObject )
		ModUtil.UpdateGlobalisedPath( basePath, pathArray )
	end
	
	function ModUtil.BaseRestore( basePath )
		local pathArray = ModUtil.PathArray( basePath )
		ModUtil.Restore( _G, pathArray )
		ModUtil.UpdateGlobalisedPath( basePath, pathArray )
	end
	
	-- Misc
	
	-- function depends on Random.lua having run first
	function ModUtil.RandomElement( tableArg, rng )
		local Collapsed = CollapseTable( tableArg )
		return Collapsed[RandomInt( 1, #Collapsed, rng )]
	end
	
	-- Post Setup
	
	ModUtil.GlobaliseModFuncs( ModUtil )

end
