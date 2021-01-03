--[[
Mod: Mod Utility
Author: MagicGonads

	Library to allow mods to be more compatible with eachother and expand capabilities.
	Use the mod importer to import this mod to ensure it is loaded in the right position.

]]

ModUtil = {
	Anchors = {
		Menu = {},
		CloseFuncs = {}
	},
	Internal = {
		Overrides = {},
		WrapCallbacks = {},
		PerFunctionEnv = {}
	},
	Context = {},
	Metatables = {},
	New = {},
	Nodes = {
		Inverse = {
		}
	}
}
SaveIgnores[ "ModUtil" ] = true

-- Extended Global Utilities (assuming lua 5.2)

local debug = debug

-- doesn't invoke __index
rawnext = next
local rawnext = rawnext

-- invokes __next
function next( t, k )
	local m = debug.getmetatable( t )
	local n = m and m.__next or rawnext
	return n( t, k )
end

local next = next

-- doesn't invoke __index just like rawnext
function rawinext( t, i )
	i = i or 0
	i = i + 1
	local v = rawget( t, i )
	if v ~= nil then
		return i, v
	end
end

local rawinext = rawinext

-- invokes __inext
function inext( t, i )
	local m = debug.getmetatable( t )
	local n = m and m.__inext or rawinext
	return n( t, i )
end

-- truly raw pairs, ignores __next and __pairs
function rawpairs( t )
	return rawnext, t, nil
end

-- truly raw ipairs, ignores __inext and __ipairs
function rawipairs( t )
	return rawinext, t, nil
end

-- quasi-raw pairs, invokes __next but ignores __pairs
function qrawpairs( t )
    return next, t, nil
end

-- quasi-raw ipairs, invokes __inext but ignores __ipairs
function qrawipairs( t )
    return inext, t, nil
end

function getfenv( fn )
	local i = 1
	while true do
		local name, val = debug.getupvalue( fn, i )
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
function setfenv( fn, env )
	local i = 1
	while true do
		local name = debug.getupvalue( fn, i )
		if name == "_ENV" then
			debug.upvaluejoin( fn, i, ( function()
				return env
			end ), 1 )
			break
		elseif not name then
			break
		end
		i = i + 1
	end
	return fn
end

-- Environment Context

-- bind to locals to minimise environment recursion and increase speed
local
rawget, rawset, rawlen, ModUtil, table, getmetatable, setmetatable, type, pairs, ipairs, rawpairs, rawipairs, inext, qrawpairs, qrawipairs, getfenv, setfenv
=
rawget, rawset, rawlen, ModUtil, table, getmetatable, setmetatable, type, pairs, ipairs, rawpairs, rawipairs, inext, qrawpairs, qrawipairs, getfenv, setfenv

function ModUtil.RawInterface( obj )

	local meta = {
		__index = function( _, key )
			return rawget( obj, key )
		end,
		__newindex = function( _, key, value )
			rawset( obj, key, value )
		end,
		__len = function()
			return rawlen( obj )
		end,
		__next = function( _, key )
			return rawnext( obj, key )
		end,
		__inext = function( _ , idx )
			return rawinext( obj, idx )
		end,
		__pairs = function()
			return rawpairs( obj )
		end,
		__ipairs = function(  )
			return rawipairs( obj )
		end
	}

	local interface = {}
	setmetatable( interface, meta )
	return interface

end

local __G = ModUtil.RawInterface( _G )
__G.__G = __G

--[[
	Make lexical environments use locals instead of upvalues
]]
function ModUtil.ReplaceGlobalEnvironment()

	debug.setmetatable( __G._G, {})

	local function env()
		local level = 2
		while debug.getinfo( level, "f" ) do
			local idx, name, value = 1, true, nil
			while name do
				name, value = debug.getlocal( level, idx )
				if name == "_ENV" then
					return value
				end

				idx = idx + 1
			end
			level = level + 1
		end
		return __G
	end

	local meta = {
		__index = function( _, key )
			return env()[key]
		end,
		__newindex = function( _, key, value )
			env()[key] = value
		end,
		__len = function()
			return #env()
		end,
		__next = function( _, key )
			return next( env(), key )
		end,
		__inext = function( _, key )
			return inext( env(), key )
		end,
		__pairs = function()
			return pairs( env() )
		end,
		__ipairs = function()
			return ipairs( env() )
		end
	}

	debug.setmetatable( __G._G, meta )
end

-- the performance overhead of this has not been rigorously measured, but seems insignificant
ModUtil.ReplaceGlobalEnvironment()

local function skipenv( obj )
	if obj ~= __G._G then return obj end
	return __G
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
		SaveIgnores[ modName ] = true
	end
	if not parent[ modName ] then
		parent[ modName ] = {}
		local prefix = ModUtil.Mods.Index[ parent ]
		if prefix ~= nil then
			prefix = prefix .. '.'
		else
			prefix = ''
		end
		ModUtil.Mods.Table[ prefix .. modName ] = parent[ modName ]
	end
	return parent[ modName ]
end

--[[
	Tell each screen anchor that they have been forced closed by the game
]]
function ModUtil.ForceClosed( triggerArgs )
	for _, v in pairs( ModUtil.Anchors.CloseFuncs ) do
		v( nil, nil, triggerArgs )
	end
	ModUtil.Anchors.CloseFuncs = {}
	ModUtil.Anchors.Menu = {}
end
OnAnyLoad{ function( triggerArgs ) ModUtil.ForceClosed( triggerArgs ) end }

ModUtil.Internal.FuncsToLoad = {}

function ModUtil.Internal.LoadFuncs( triggerArgs )
	for _, v in pairs( ModUtil.Internal.FuncsToLoad ) do
		v( triggerArgs )
	end
	ModUtil.Internal.FuncsToLoad = {}
end
OnAnyLoad{ function( triggerArgs ) ModUtil.Internal.LoadFuncs( triggerArgs ) end }

--[[
	Run the provided function once on the next in-game load.

	triggerFunction - the function to run
]]
function ModUtil.LoadOnce( triggerFunction )
	table.insert( ModUtil.Internal.FuncsToLoad, triggerFunction )
end

--[[
	Cancel running the provided function once on the next in-game load.

	triggerFunction - the function to cancel running
]]
function ModUtil.CancelLoadOnce( triggerFunction )
	for i,v in ipairs( ModUtil.Internal.FuncsToLoad) do
		if v == triggerFunction then
			table.remove( ModUtil.Internal.FuncsToLoad, i )
		end
	end
end

-- Data Misc

function ModUtil.ValueString( o )
	if type( o ) == 'string' then
		return '"' .. o .. '"'
	end
	if type ( o ) == 'number' or type( o ) == 'boolean' then
		return tostring( o )
	end
	return '<'..tostring( o )..'>'
end

function ModUtil.KeyString( o )
	if type( o ) == 'number' then o = o .. '.' end
	return tostring( o )
end

function ModUtil.TableKeysString( o )
	if type( o ) == 'table' then
		local first = true
		local s = ''
		for k,_ in pairs( o ) do
			if not first then s = s .. ', ' else first = false end
			s = s .. ModUtil.KeyString( k )
		end
		return s
	end
end

function ModUtil.ToString( o, seen )
	--https://stackoverflow.com/a/27028488
	seen = seen or {}
	if type( o ) == 'table' and not seen[ o ] then
		seen[ o ] = true
		local first = true
		local s = '<' .. tostring(o) .. ">{"
		for k,v in pairs( o ) do
			if not first then s = s .. ', ' else first = false end
			s = s .. ModUtil.KeyString( k ) ..' = ' .. ModUtil.ToString( v, seen )
		end
		return s .. '}'
	else
		return ModUtil.ValueString( o )
	end
end

function ModUtil.PrintToFile( file, ... )
    local out = {}
	for _, v in ipairs( { ... } ) do
		table.insert( out, "\t" )
		table.insert( out, ModUtil.ToString( v ) )
	end
	table.insert( out, "\n" )
	table.remove( out,1 )
	
	file:write( table.unpack( out ) )
end

function ModUtil.ChunkText( text, chunkSize, maxChunks )
	local chunks = { "" }
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
			chunks[ ncs ] = ""
			cs = 0
		end
		if chr ~= "\n" then
			chunks[ ncs ] = chunks[ ncs ] .. chr
		end
	end
	return chunks
end

function ModUtil.ReplaceTable( target, data )
	for k in pairs( target ) do
		target[k] = data[k]
	end
	for k,v in pairs( data ) do
		target[k] = v
	end
end

function ModUtil.InvertTable( tableArg )
	local inverseTable = {}
	for key, value in ipairs( tableArg ) do
		inverseTable[ value ] = key
	end
	return inverseTable
end

function ModUtil.IsUnKeyed( tableArg )
	local lk = 0
	for k in pairs( tableArg ) do
		if type( k ) ~= "number" then
			return false
		end
		if lk + 1 ~= k then
			return false
		end
		lk = k
	end
	return true
end

-- Data Manipulation

--[[
	Return a slice of an array table, python style
		would be written state[start:stop:step] in python
	
	start and stop are offsets rather than ordinals
		meaning 0 corresponds to the start of the array
		and -1 corresponds to the end
]]
function ModUtil.Slice( state, start, stop, step )
	local slice = {}
	local n = #state
	
	start = start or 0
	if start < 0 then
		start = start + n
	end
	stop = stop or n - 1
	if stop < 0 then
		stop = stop + n
	end

	for i = start, stop, step do
		table.insert( slice, state[i + 1] )
	end

	return slice
end

local function CollapseTable( tableArg )
	-- from UtilityScripts.lua
	if tableArg == nil then
		return
	end

	local collapsedTable = {}
	local index = 1
	for _, v in pairs( tableArg ) do
		collapsedTable[ index ] = v
		index = index + 1
	end

	return collapsedTable

end

local function ShallowCopyTable( orig )
	-- from UtilityScripts.lua
	if orig == nil then
		return
	end

	local copy = {}
	for k, v in pairs( orig ) do
		copy[k] = v
	end
	return copy
end

local function DeepCopyTable( orig )
	-- from UtilityScripts.lua
	local orig_type = type( orig )
	local copy
	if orig_type == 'table' then
		copy = {}
		-- slightly more efficient to call next directly instead of using pairs
		for k, v in next, orig, nil do
			copy[ k ] = DeepCopyTable( v )
		end
	else
		copy = orig
	end

	return copy
end

ModUtil.Internal.MarkedForCollapse = {}

local function autoIsUnKeyed( tableArg )
	if not ModUtil.Internal.MarkedForCollapse[ tableArg ] then
		return ModUtil.IsUnKeyed( tableArg )
	end
	return false
end

function ModUtil.CollapseMarked()
	for tbl, state in pairs( ModUtil.Internal.MarkedForCollapse ) do
		if state then
			local ctbl = CollapseTable( tbl )
			for k in pairs( tbl ) do
				tbl[ k ] = nil
			end
			for k, v in pairs( ctbl ) do
				tbl[ k ] = v
			end
		end
	end
	ModUtil.Internal.MarkedForCollapse = {}
end
OnAnyLoad{ ModUtil.CollapseMarked }

function ModUtil.MarkForCollapse( tableArg )
	ModUtil.Internal.MarkedForCollapse[ tableArg ] = true
end

function ModUtil.UnmarkForCollapse( tableArg )
	ModUtil.Internal.MarkedForCollapse[ tableArg ] = false
end

--[[
	Safely create a new empty table at Table.key and return it.

	Table - the table to modify
	key	 - the key at which to store the new empty table
]]
function ModUtil.NewTable( tableArg, key )
	if ModUtil.Nodes.Index[ key ] then
		return ModUtil.Nodes.Index[ key ].New( tableArg )
	end
	local tbl = tableArg[ key ]
	if type(tbl) ~= "table" then
		tbl = {}
		tableArg[ key ] = tbl
	end
	return tbl
end

--[[
	Safely retrieve the a value from deep inside a table, given
	an array of indices into the table.

	For example, if indexArray is { "a", 1, "c" }, then
	Table["a"][1]["c"] is returned. If any of Table["a"],
	Table["a"][1], or Table["a"][1]["c"] are nil, then nil
	is returned instead.

	Table			 - the table to retrieve from
	indexArray	- the list of indices
]]
function ModUtil.SafeGet( baseTable, indexArray )
	local node = baseTable
	for i, k in ipairs( indexArray ) do
		if type( node ) ~= "table" then
			return nil
		end
		if ModUtil.Nodes.Index[ k ] then
			node = ModUtil.Nodes.Index[ k ].Get( node )
		else
			node = node[ k ]
		end
	end
	return node
end

--[[
	Safely set a value deep inside a table, given an array of
	indices into the table, and creating any necessary tables
	along the way.

	For example, if indexArray is { "a", 1, "c" }, then
	Table[ "a" ][ 1 ][ "c" ] = Value once this function returns.
	If any of Table[ "a" ] or Table[ "a" ][ 1 ] does not exist, they
	are created.

	baseTable	 - the table to set the value in
	indexArray	- the list of indices
	value	- the value to add
]]
function ModUtil.SafeSet( baseTable, indexArray, value )
	if next( indexArray ) == nil then
		return false -- can't set the input argument
	end
	local n = #indexArray
	local node = baseTable
	for i = 1, n - 1 do
		local k = indexArray[ i ]
		if not ModUtil.NewTable( node, k ) then return false end
		if ModUtil.Nodes.Index[ k ] then
			node = ModUtil.Nodes.Index[ k ].Get( node )
		else
			node = node[ k ]
		end
	end
	local k = indexArray[ n ]
	if ModUtil.Nodes.Index[ k ] then
		return ModUtil.Nodes.Index[ k ].Set( node, value )
	end
	if ( node[ k ] == nil ) ~= ( value == nil ) then
		if autoIsUnKeyed( baseTable ) then
			ModUtil.MarkForCollapse( node )
		end
	end
	node[ k ] = value
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
	local unkeyed = autoIsUnKeyed( inTable )
	for nilKey, nilVal in pairs( nilTable ) do
		local inVal = inTable[ nilKey ]
		if type( nilVal ) == "table" and type( inVal ) == "table" then
			ModUtil.MapNilTable( inVal, nilVal )
		else
			inTable[ nilKey ] = nil
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
	local unkeyed = autoIsUnKeyed( inTable )
	for setKey, setVal in pairs( setTable ) do
		local inVal = inTable[ setKey ]
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

-- Path Manipulation

--[[
	Concatenates two index arrays, in order.

	a, b - the index arrays
]]
function ModUtil.JoinIndexArrays( a, b )
	local c = {}
	local j = 0
	for i, v in ipairs(a) do
		c[ i ] = v
		j = i
	end
	for i, v in ipairs(b) do
		c[ i + j ] = v
	end
	return c
end

--[[
	Create an index array from the provided Path.

	The returned array can be used as an argument to the safe table
	manipulation functions, such as ModUtil.ArraySet and ModUtil.ArrayGet.

	path - a dot-separated string that represents a path into a table
]]
function ModUtil.PathToIndexArray( path )
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
		table.insert( i, s )
	end
	return i
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
	return ModUtil.ArrayGet( base or _G, ModUtil.PathToIndexArray( path ) )
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
	return ModUtil.ArraySet( base or _G, ModUtil.PathToIndexArray( path ), value )
end

-- Metaprogramming Shenanigans

ModUtil.Metatables.DirectLocalLevel = {
	__index = function( self, idx )
		return debug.getlocal( rawget( self, "level" ) + 1, idx )
	end,
	__newindex = function( self, idx, value )
		local level = rawget( self, "level" ) + 1
		local name = debug.getlocal( level, idx )
		if name ~= nil then
			debug.setlocal( level, idx, value )
		end
	end,
	__len = function( self )
		local level = rawget( self, "level" ) + 1
		local idx = 1
		while debug.getlocal( level, idx ) do
			idx = idx + 1
		end
		return idx - 1
	end,
	__next = function( self, idx )
		idx = idx or 0
		idx = idx + 1
		local name, val = debug.getlocal( rawget( self, "level" ) + 1, idx )
		if val ~= nil then
			return idx, name, val
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}
ModUtil.Metatables.DirectLocalLevel.__inext = ModUtil.Metatables.DirectLocalLevel.__next

--[[
	Example Use:
	for i, name, value in pairs(ModUtil.LocalLevel(level)) do
		--
	end
]]
function ModUtil.DirectLocalLevel(level)
	local localLevel = { level = level }
	setmetatable( localLevel, ModUtil.Metatables.DirectLocalLevel )
	return localLevel
end

ModUtil.Metatables.DirectLocalLevels = {
	__index = function( _, level )
		return level, ModUtil.DirectLocalLevel( level )
	end,
	__len = function()
		local level = 2
		while debug.getinfo( level, "f" ) do
			level = level + 1
		end
		return level - 1
	end,
	__next = function( _, level )
		level = level or 0
		level = level + 1
		if debug.getinfo(level + 1, "f") then
			return level, ModUtil.DirectLocalLevel( level )
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}
ModUtil.Metatables.DirectLocalLevels.__inext = ModUtil.Metatables.DirectLocalLevels.__next

--[[
	Example Use:
	for level,localLevel in pairs(ModUtil.LocalLevels) do
		for i, name, value in pairs(localLevel) do
			--
		end
	end
]]
ModUtil.DirectLocalLevels = {}
setmetatable(ModUtil.DirectLocalLevels, ModUtil.Metatables.DirectLocalLevels)

ModUtil.Metatables.LocalsInterface = {
	__index = function( self, name )
		local pair = rawget( self, "index" )[ name ]
		if pair ~= nil then
			local _, value = debug.getlocal( pair.level + 1, pair.index )
			return value
		end
	end,
	__newindex = function( self, name, value )
		local pair = rawget( self, "index" )[ name ]
		if pair ~= nil then
			debug.setlocal( pair.level + 1, pair.index, value )
		end
	end,
	__len = function( self )
		-- locals can't have integer names
		return 0 --#rawget( self, "index" )
	end,
	__next = function( self, name )
		local pair
		name, pair = next( rawget( self, "index" ), name )
		if pair ~= nil then
			local _, value = debug.getlocal( pair.level + 1, pair.index )
			return name, value
		end
	end,
	__inext = function( self , i )
		local pair
		i, pair = inext( rawget( self, "index" ), i )
		if pair ~= nil then
			local _, value = debug.getlocal( pair.level + 1, pair.index )
			return i, value
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

--[[
	Interface only valid within the scope it was constructed
]]
function ModUtil.LocalsInterface( names, level )
	local lookup = {}
	if names then
		-- assume names is strictly either a list or a lookup table
		lookup = names
		if #lookup ~= 0 then
			lookup = ModUtil.InvertTable(names)
		end
	end

	local order = {}
	local index = {}

	if level == nil then level = 1 end
	local localLevel
	level, localLevel = next( ModUtil.DirectLocalLevels, level )
	while level do
		for i, name, value in pairs( localLevel ) do
			if (not names or lookup[ name ]) and index[ name ] == nil then
				index[ name ] = { level = level - 1, index = i }
				table.insert( order, name )
			end
		end
		level,localLevel = next( ModUtil.DirectLocalLevels, level )
	end
	local interface = { index = index, order = order }
	setmetatable( interface, ModUtil.Metatables.LocalsInterface )

	return interface, index, order
end

ModUtil.Metatables.DirectPairLocals = {
	__index = function( _, pair )
		return debug.getlocal( pair.level + 1, pair.index )
	end,
	__newindex = function( _, pair, value )
		debug.setlocal( pair.level + 1, pair.index, value )
	end,
	__len = function()
		return 0
	end,
	__next = function( _, pair )
		local nextpair = { level = 1, index = 1 }
		if pair == nil then
			return nextpair, debug.getlocal( 2, 1 )
		end

		nextpair.level = pair.level
		nextpair.index = pair.index + 1
		while debug.getinfo( nextpair.level + 1, "f" ) do
			local name, value = debug.getlocal( nextpair.level + 1, nextpair.index )
			if name then
				return nextpair, name, value
			end
			nextpair.level = nextpair.level + 1
			nextpair.index = 1
		end

	end,
	__inext = function() return end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.DirectPairLocals = {}
setmetatable( ModUtil.DirectPairLocals, ModUtil.Metatables.DirectPairLocals )

ModUtil.Metatables.Locals = {
	__index = function( _, name )
		local level = 2
		while debug.getinfo( level, "f" ) do
			local idx = 1
			while true do
				local n, v = debug.getlocal( level, idx )
				if n == name then
					return v
				elseif not n then
					break
				end
				idx = idx + 1
			end
			level = level + 1
		end
	end,
	__newindex = function( _, name, value )
		local level = 2
		while debug.getinfo( level, "f" ) do
			local idx = 1
			while true do
				local n = debug.getlocal( level, idx )
				if n == name then
					debug.setlocal( level, idx, value )
					return
				elseif not n then
					break
				end
				idx = idx + 1
			end
			level = level + 1
		end
	end,
	__len = function()
		return 0
	end,
	__next = function( _, name )
		if name == nil then
			return debug.getlocal( 2, 1 )
		end
		local level = 2
		while debug.getinfo( level, "f" ) do
			local idx = 1
			while true do
				local n = debug.getlocal( level, idx )
				if n == name then
					return debug.getlocal( level, idx + 1 )
				elseif not n then
					break
				end
				idx = idx + 1
			end
			level = level + 1
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}
ModUtil.Metatables.Locals.__inext = ModUtil.Metatables.Locals.__next

--[[
	Access to local variables, in the current function and callers.
	The most recent definition with a given name on the call stack will
	be used.

	For example, if your function is called from CreateTraitRequirements,
	you could access its 'local screen' as ModUtil.Locals.screen
	and its 'local hasRequirement' as ModUtil.Locals.hasRequirement.
]]
ModUtil.Locals = {}
setmetatable( ModUtil.Locals, ModUtil.Metatables.Locals )

ModUtil.Metatables.DirectUpValues = {
	__index = function( self, idx )
		return debug.getupvalue( rawget(self,"func"), idx )
	end,
	__newindex = function( self, idx, value )
		debug.setupvalue( rawget(self,"func"), idx, value )
	end,
	__len = function( self )
		return debug.getinfo( rawget( self, "func" ), 'u' ).nups
	end,
	__next = function ( self, idx )
		idx = idx or 0
		idx = idx + 1
		return idx, debug.getupvalue( rawget( self, "func" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}
ModUtil.Metatables.DirectUpValues.__inext = ModUtil.Metatables.DirectUpValues.__next

ModUtil.Metatables.UpValues = {
	__index = function( self, name )
		local _, v = debug.getupvalue( rawget( self, "func" ), rawget( self, "ind" )[ name ] )
		return v
	end,
	__newindex = function( self, name, value )
		debug.setupvalue( rawget( self, "func" ), rawget( self, "ind" )[ name ], value )
	end,
	__len = function ( self )
		return rawget( self, "n" )
	end,
	__next = function ( self, name )
		local i
		name, i = next( rawget( self, "ind" ), name )
		if i ~= nil then
			return debug.getupvalue( rawget( self, "func" ), i )
		end
	end,
	__inext = function ( self, idx )
		local i
		idx, i = next( rawget( self, "ind" ), idx )
		if i ~= nil then
			return debug.getupvalue( rawget( self, "func" ), i )
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

--[[
	Return a table representing the upvalues of a function.

	Upvalues are those variables captured by a function from it's
	creation context. For example, locals defined in the same file
	as the function are accessible to the function as upvalues.

	func - the function to get upvalues from
]]
function ModUtil.GetUpValues( func )
	local ind = {}
	local name
	local i = 1
	while true do
		name = debug.getupvalue( func, i )
		if name == nil then break end
		ind[ name ] = i
		i = i + 1
	end
	local ups = { func = func, ind = ind, n = debug.getinfo( func, 'u' ).nups }
	setmetatable( ups, ModUtil.Metatables.UpValues )
	return ups, ind
end

function ModUtil.GetDirectUpValues( func )
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.DirectUpValues )
	return ups
end

function ModUtil.GetBottomUpValues( baseTable, indexArray )
	local baseValue = ModUtil.ArrayGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if baseValue then
		baseValue = baseValue[ #baseValue ].Base
	else
		baseValue = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
		if baseValue then
			baseValue = baseValue[ 1 ].Func
		else
			baseValue = ModUtil.ArrayGet( baseTable, indexArray )
		end
	end
	return ModUtil.GetUpValues( baseValue )
end

function ModUtil.GetBottomDirectUpValues( baseTable, indexArray )
	local baseValue = ModUtil.ArrayGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if baseValue then
		baseValue = baseValue[ #baseValue ].Base
	else
		baseValue = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
		if baseValue then
			baseValue = baseValue[ 1 ].Func
		else
			baseValue = ModUtil.ArrayGet( baseTable, indexArray )
		end
	end
	return ModUtil.GetDirectUpValues( baseValue )
end

--[[
	Return a table representing the upvalues of the base function identified
	by basePath (ie. ignoring all wrappers that other mods may have placed
	around the function).

	basePath - the path to the function, as a string
]]
function ModUtil.GetBaseBottomUpValues( basePath )
	return ModUtil.GetBottomUpValues( _G, ModUtil.PathToIndexArray( basePath ) )
end

function ModUtil.GetBaseBottomDirectUpValues( basePath )
	return ModUtil.GetBottomDirectUpValues( _G, ModUtil.PathToIndexArray( basePath ) )
end

-- Globalisation

ModUtil.Metatables.GlobalisedFunc = {
	__call = function( self, ... )
		return ModUtil.ArrayGet( rawget( self, "table" ), rawget( self, "array" ) )( ... )
	end
}

function ModUtil.New.GlobalisedFunc( baseTable, indexArray )
	local funcTable = { table = baseTable, array = indexArray }
	setmetatable( funcTable, ModUtil.Metatables.GlobalisedFunc )
end

function ModUtil.GlobaliseFunc( baseTable, indexArray, key )
	_G[ key ] = ModUtil.New.GlobalisedFunc( baseTable, indexArray )
end

--[[
	Sets a unique global variable equal to the value stored at Path.

	For example, the OnPressedFunctionName of a button must refer to a single key
	in the globals table ( _G ). If you have a function defined in your module's
	table that you would like to use, ie.

		function YourModName.FunctionName( ... )

	then ModUtil.GlobalizePath("YourModName.FunctionName") will create a global
	variable for that function, and you can then set OnPressedFunctionName to
	ModUtil.JoinPath( "YourModName.FunctionName" ).

	path 		- the path to be globalised
	prefixPath 	- (optional) if present, add this path as a prefix to the
					path from the root of the table.
]]
function ModUtil.GlobaliseFuncPath( path, prefixPath )
	if prefixPath == nil then
		prefixPath = ""
	else
		prefixPath = prefixPath .. '.'
	end
	ModUtil.GlobaliseFunc( _G,  ModUtil.PathToIndexArray( path ), prefixPath .. path )
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

	So that the global functions are called "YourModNameUI.OnButton1" etc.

	tableArg	- The table containing the functions to globalise
	prefixPath	- (optional) if present, add this path as a prefix to the
					path from the root of the table.
]]
function ModUtil.GlobaliseFuncs( tableArg, prefixPath )
	if prefixPath == nil then
		prefixPath = ""
	else
		prefixPath = prefixPath .. '.'
	end
	for k, v in pairs( tableArg ) do
		if type( k ) == "string" then
			if type( v ) == "function" then
				ModUtil.GlobaliseFunc( v, { k }, prefixPath .. '.' .. k )
			elseif type( v ) == "table" then
				ModUtil.GlobaliseFuncs( v, prefixPath .. '.' .. k )
			end
		end
	end
end

--[[
	Globalise all the functions in your mod object.

	mod - The mod object created by ModUtil.RegisterMod
]]
function ModUtil.GlobaliseModFuncs( mod )
	local prefix = ModUtil.Mods.Index[ mod ]
	ModUtil.GlobaliseFuncs( mod, prefix )
end

-- Function Wrapping

--[[
	Wrap a function, so that you can insert code that runs before/after that function
	whenever it's called, and modify the return value if needed.

	Generally, you should use ModUtil.WrapBaseFunction instead for a more modder-friendly
	interface.

	Multiple wrappers can be applied to the same function.

	As an example, for WrapFunction( _G, { "UIFunctions", "OnButton1Pushed" }, wrapper, MyMod )

	Wrappers are stored in a structure like this:

	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{ id = 1, mod = MyMod, wrap=wrapper, func = <original unwrapped function> }
	}

	If a second wrapper is applied via
		WrapFunction( _G, { "UIFunctions", "OnButton1Pushed" }, wrapperFunction2, SomeOtherMod )
	then the resulting structure will be like:

	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{id = 1, mod = MyMod,	wrap = wrapper,	func = <original unwrapped function> }
		{id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
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
	mod	 - (optional) the mod installing the wrapper, for informational purposes
]]
function ModUtil.WrapFunction( funcTable, indexArray, wrapFunc, mod )
	if type( wrapFunc ) ~= "function" then return end
	if not funcTable then return end
	local func = ModUtil.ArrayGet( funcTable, indexArray )
	if type( func ) ~= "function" then return end

	ModUtil.NewTable( ModUtil.Internal.WrapCallbacks, funcTable )
	local tempTable = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	if tempTable == nil then
		tempTable = {}
		ModUtil.ArraySet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray, tempTable )
	end
	table.insert( tempTable, { Id = #tempTable + 1, Mod = mod, Wrap = wrapFunc, Func = func } )

	ModUtil.ArraySet( skipenv( funcTable ), indexArray, function( ... )
		return wrapFunc( func, ... )
	end )
end

--[[
	Internal utility that reapplies the list of wrappers when the base function changes.

	For example. if the list of wrappers looks like:
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{id = 1, mod = MyMod,	wrap = wrapper,	func = <original unwrapped function> }
		{id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
		{id = 3, mod = ModNumber3,	 wrap = wrapper3, func = <original function + wrapper1 + wrapper 2> }
	}

	and the base function is modified by setting [ 1 ].func to a new value, like so:
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{id = 1, mod = MyMod,	wrap = wrapper,	func = <new function> }
		{id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
		{id = 3, mod = ModNumber3,	 wrap = wrapper3, func = <original function + wrapper1 + wrapper 2> }
	}

	Then rewrap function will fix up eg. [ 2 ].func, [ 3 ].func so that the correct wrappers are applied
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{id = 1, mod = MyMod,	wrap = wrapper,	func = <new function> }
		{id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <new function + wrapper1> }
		{id = 3, mod = ModNumber3,	 wrap = wrapper3, func = <new function + wrapper1 + wrapper 2> }
	}
	and also update the entry in funcTable to be the completely wrapped function, ie.

	UIFunctions.OnButton1Pushed = <new function + wrapper1 + wrapper2 + wrapper3>

	funcTable	 - the table the function is stored in (usually _G)
	indexArray	- the array of path elements to the function in the table
]]
function ModUtil.RewrapFunction( funcTable, indexArray )
	local wrapCallbacks = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	local preFunc = nil

	for _, tempTable in ipairs( wrapCallbacks ) do
		if preFunc then
			tempTable.Func = preFunc
		end
		preFunc = function( ... )
			return tempTable.Wrap( tempTable.Func, ... )
		end
		ModUtil.ArraySet( skipenv( funcTable ), indexArray, preFunc )
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
	local func = ModUtil.ArrayGet( skipenv( funcTable ), indexArray )
	if type( func ) ~= "function" then return end

	local tempTable = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	if not tempTable then return end
	local funcData = table.remove( tempTable ) -- removes the last value
	if not funcData then return end

	ModUtil.ArraySet( skipenv( funcTable ), indexArray, funcData.Func )
	return funcData
end


--[[
	Wraps the function with the path given by baseFuncPath, so that you
	can execute code before or after the original function is called,
	or modify the return value.

	For example:

	ModUtil.WrapBaseFunction("CreateNewHero", function( baseFunc, prevRun, args )
		local hero = baseFunc( prevRun, args )
		hero.Health = 1
		return hero
	end, YourMod )

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
	mod	- (optional) the object for your mod, for debug purposes
]]
function ModUtil.WrapBaseFunction( baseFuncPath, wrapFunc, mod )
	local pathArray = ModUtil.PathToIndexArray( baseFuncPath )
	ModUtil.WrapFunction( _G, pathArray, wrapFunc, mod )
end

--[[
	Internal function that reapplies all the wrappers to a function.
]]
function ModUtil.RewrapBaseFunction( baseFuncPath )
	local pathArray = ModUtil.PathToIndexArray( baseFuncPath )
	ModUtil.RewrapFunction( _G, pathArray )
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
	local pathArray = ModUtil.PathToIndexArray( baseFuncPath )
	ModUtil.UnwrapFunction( _G, pathArray )
end

-- Override Management

local function getBaseValueForWraps( baseTable, indexArray )
	local baseValue = ModUtil.ArrayGet( skipenv( baseTable ), indexArray )
	local wrapCallbacks = nil
	wrapCallbacks = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
	if wrapCallbacks then
		if wrapCallbacks[ 1 ] then
			baseValue = wrapCallbacks[ 1 ].Func
		end
	end

	return baseValue
end

local function setBaseValueForWraps( baseTable, indexArray, value )
	local baseValue = ModUtil.ArrayGet( skipenv( baseTable ), indexArray )

	if type(baseValue) ~= "function" or type(value) ~= "function" then return false end

	local wrapCallbacks = nil
	wrapCallbacks = ModUtil.ArrayGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
	if wrapCallbacks then if wrapCallbacks[ 1 ] then
		baseValue = wrapCallbacks[ 1 ].Func
		wrapCallbacks[ 1 ].Func = value
		ModUtil.RewrapFunction( baseTable, indexArray )
		return true
	end end

	return false
end

--[[
	Override a value in baseTable.

	Generally, you should use ModUtil.BaseOverride instead for a more modder-friendly
	interface.

	If the value is a function, overrides only the base function,
	preserving all the wraps added with ModUtil.WrapFunction.

	The previous value is stored so that it can be restored later if desired.
	For example, ModUtil.Override(_G, ["UIFunctions", "OnButton1"], overrideFunc, MyMod)
	will result in a data structure like:

	ModUtil.Internal.Overrides[_G].UIFunctions.OnButton1 = {
		{id=1, mod=MyMod, value=overrideFunc, base=<original value of UIFunctions.OnButton1>}
	}

	and subsequent overides wil be added as subsequent entries in the same table.

	baseTable	- the table in which to override, usually _G (globals)
	indexArray	- the list of indices
	value	- the new value
	mod	- (optional) the mod that performed the override, for debugging purposes
]]
function ModUtil.Override( baseTable, indexArray, value, mod )
	if not baseTable then return end

	local baseValue = getBaseValueForWraps( baseTable, indexArray )

	ModUtil.NewTable( ModUtil.Internal.Overrides, baseTable )
	local tempTable = ModUtil.ArrayGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if tempTable == nil then
		tempTable = {}
		ModUtil.ArraySet( ModUtil.Internal.Overrides[ baseTable ], indexArray, tempTable )
	end
	table.insert( tempTable, { Id = #tempTable + 1, Mod = mod, Value = value, Base = baseValue } )

	if not setBaseValueForWraps( baseTable, indexArray, value ) then
		ModUtil.ArraySet( skipenv( baseTable ), indexArray, value )
	end
end

--[[
	Undo the most recent override performed with ModUtil.Override, restoring
	the previous value.

	Generally, you should use ModUtil.BaseRestore instead for a more modder-friendly
	interface.

	If the previous value is a function, the current stack of wraps for that
	IndexArray will be reapplied to it.

	baseTable	= the table in which to undo the override, usually _G (globals)
	indexArray	- the list of indices
]]
function ModUtil.Restore( baseTable, indexArray )
	if not baseTable then return end
	local tempTable = ModUtil.ArrayGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if not tempTable then return end
	local baseData = table.remove( tempTable ) -- remove the last entry
	if not baseData then return end

	if not setBaseValueForWraps( baseTable, indexArray, baseData.Base ) then
		ModUtil.ArraySet( skipenv( baseTable ), indexArray, baseData.Base )
	end
	return baseData
end

--[[
	Override the global value at the given basePath.

	If the Value is a function, preserves the wraps
	applied with ModUtil.WrapBaseFunction et. al.

	basePath	- the path to override, as a string
	value	- the new value to store at the path
	mod	- (optional) the mod performing the override,
		for debug purposes
]]
function ModUtil.BaseOverride( basePath, value, mod )
	local pathArray = ModUtil.PathToIndexArray( basePath )
	ModUtil.Override( _G, pathArray, value, mod )
end

--[[
	Undo the most recent override performed with ModUtil.Override,
	or ModUtil.BaseOverride, restoring the previous value.

	Use this carefully - if you are not the most recent mod to
	override the given path, the results may be unexpected.

	basePath	- the path to restore, as a string
]]
function ModUtil.BaseRestore( basePath )
	local pathArray = ModUtil.PathToIndexArray( basePath )
	ModUtil.Restore( _G, pathArray )
end

-- Automatically updating data structures (WIP)

ModUtil.Metatables.EntangledIsomorphism = {
	__index = function( self, key )
		return rawget( self, "data" )[ key ]
	end,
	__newindex = function( self, key, value )
		local data, inverse = rawget( self, "data" ), rawget( self, "inverse" )
		if value ~= nil then
			local k = inverse[ value ]
			if k ~= nil and k ~= key then
				data[ k ] = nil
			end
			inverse[ value ] = key
		end
		if key ~= nil then
			local v = data[ key ]
			if v ~= nil and v ~= value then
				inverse[ v ] = nil
			end
			data[ key ] = value
		end
	end,
	__len = function( self )
		return #rawget( self, "data" )
	end,
	__next = function( self, key )
		return next( rawget( self, "data" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "data" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledIsomorphismInverse = {
	__index = function( self, value )
		return rawget( self, "inverse" )[ value ]
	end,
	__newindex = function( self, value, key )
		local data, inverse = rawget( self, "data" ), rawget( self, "inverse" )
		if value ~= nil then
			local k = inverse[ value ]
			if k ~= nil and k ~= key then
				data[ k ] = nil
			end
			inverse[ value ] = key
		end
		if key ~= nil then
			local v = data[ key ]
			if v ~= nil and v ~= value then
				inverse[ v ] = nil
			end
			data[ key ] = value
		end
	end,
	__len = function( self )
		return #rawget( self, "inverse" )
	end,
	__next = function( self, value )
		return next( rawget( self, "inverse" ), value )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "inverse" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

function ModUtil.New.EntangledInvertiblePair()
	local data, inverse = {}, {}
	data, inverse = { data = data, inverse = inverse }, { data = data, inverse = inverse }
	setmetatable( data, ModUtil.Metatables.EntangledIsomorphism )
	setmetatable( inverse, ModUtil.Metatables.EntangledIsomorphismInverse )
	return { Table = data, Index = inverse }
end

function ModUtil.New.EntangledInvertiblePairFromTable( tableArg )
	local pair = ModUtil.New.EntangledInvertiblePair()
	for key, value in pairs( tableArg ) do
		pair.Table[ key ] = value
	end
	return pair
end

function ModUtil.New.EntangledInvertiblePairFromIndex( indexArg )
	local pair = ModUtil.New.EntangledInvertiblePair()
	for value, key in pairs( indexArg ) do
		pair.Index[ value ] = key
	end
	return pair
end

ModUtil.Metatables.PreImageNode = {
	__index = function( self, idx )
		local data = rawget( self, "data" )
		if idx == nil then
			idx = #data
		end
		return data[ idx ]
	end,
	__newindex = function( self, idx, key )
		local data = rawget( self, "data" )
		local n = #data
		if idx == nil then
			idx = n
		end

		data[ idx ] = key
		if key == nil and idx < n then
			local inverse = rawget( data, "inverse" )
			data = rawget( data, "data" )
			for i = idx, n-1 do
				data[ i ] = data[ i + 1 ]
				inverse[ data[ i ] ] = i
			end
		end
	end,
	__len = function( self )
		return #rawget( self, "data" )
	end,
	__next = function( self, value )
		return next( rawget( self, "inverse" ), value )
	end,
	__inext = function( self, value )
		return inext( rawget( self, "inverse" ), value )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledPreImageNode = {
	__index = ModUtil.Metatables.PreImageNode.__index,
	__newindex = function( self, idx, key )
		local data = rawget( self, "data" )
		local n = #data
		if idx == nil then
			idx = n
		end

		local value = rawget( data, "value" )
		if value ~= nil then
			rawget( rawget( data, "parent" ), "data" )[ idx ] = value
		end
		data[ idx ] = value
		if key == nil and idx < n then
			local inverse = rawget( data, "inverse" )
			data = rawget( data, "data" )
			for i = idx, n - 1 do
				data[ i ] = data[ i + 1 ]
				inverse[ data[ i ] ] = i
			end
		end
	end,
	__len = ModUtil.Metatables.PreImageNode.__len,
	__next = ModUtil.Metatables.PreImageNode.__next,
	__inext = ModUtil.Metatables.PreImageNode.__inext,
	__pairs = ModUtil.Metatables.PreImageNode.__pairs,
	__ipairs = ModUtil.Metatables.PreImageNode.__ipairs
}

function ModUtil.New.EntangledPreImageNode( self, value )
	local data, inverse = {}, {}
	data, inverse = { parent = self, value = value, data = data, inverse = inverse }, { parent = self, value = value, data = data, inverse = inverse }
	local pair = { data, inverse }
	setmetatable( pair, ModUtil.Metatables.EntangledPreImageNode )
	return pair
end

ModUtil.Metatables.EntangledMorphism = {
	__index = function( self, key )
		return rawget( self, "data" )[ key ]
	end,
	__newindex = function( self, key, value )
		rawget( self, "data" )[ key ] = value
		rawget( self, "preImage" )[ value ][ nil ] = key
	end,
	__len = function( self )
		return #rawget( self, "data" )
	end,
	__next = function( self, key )
		return next( rawget( self, "data" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "data" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledMorphismPreImage = {
	__index = function( self, value )
		return rawget( self, "preImage" )[ value ]
	end,
	__newindex = function( self, value, keys )
		local preImage = rawget( self, "preImage" )
		local preImagePair = preImage[ value ]
		local newPreImagePair = ModUtil.New.EntangledPreImageNode( self, value )

		local data = rawget( self, "data" )
		for _, key in pairs( preImagePair ) do
			data[ key ] = nil
		end
		preImage[ value ] = newPreImagePair
		for _, key in pairs( keys ) do
			data[ key ] = nil
		end
	end,
	__len = function( self )
		return #rawget( self, "preImage" )
	end,
	__next = function( self, value )
		return next( rawget( self, "preImage" ), value )
	end
}

function ModUtil.New.EntangledPair()
	local data, preImage = {}, {}
	data, preImage = { data = data, preImage = preImage }, { data = data, preImage = preImage }
	setmetatable( data, ModUtil.Metatables.EntangledMorphism )
	setmetatable( preImage, ModUtil.Metatables.EntangledMorphismPreImage )
	return {Map = data, PreImage = preImage}
end

function ModUtil.New.EntangledPairFromTable( tableArg )
	local pair = ModUtil.New.EntangledPair()
	for key, value in pairs( tableArg ) do
		pair.Map[key] = value
	end
	return pair
end

function ModUtil.New.EntangledPairFromPreImage( preImage )
	local pair = ModUtil.New.EntangledPair()
	for value, keys in pairs( preImage ) do
		pair.PreImage[ value ] = keys
	end
	return pair
end

-- Context Managers (WIP)

ModUtil.Metatables.ContextEnvironment = {
	__index = function( self, key )

		if key == "_G" then
			return rawget( self, "global" )
		end
		local value = rawget( self, "data" )[key]
		if value ~= nil then
			return value
		end
		return ( rawget( self, "fallback" ) or {} )[ key ]
	end,
	__newindex = function( self, key, value )
		rawget( self, "data" )[key] = value
		if key == "_G" then
			rawset( self, "global", value )
		end
	end,
	__len = function( self )
		return #rawget( self, "data" )
	end,
	__next = function( self, key )
		local out, first = { key }, true
		while out[2] == nil and (out[1] ~= nil or first) do
			first = false
			out = { next( rawget( self, "data" ), out[1] ) }
			if out[1] == "_G" then
				out = { "_G", rawget( self, "global" ) }
			end
		end
		return table.unpack(out)
	end,
	__inext = function( self, idx )
		local out, first = { idx }, true
		while out[2] == nil and (out[1] ~= nil or first) do
			first = false
			out = { inext( rawget( self, "data" ), out[1] ) }
			if out[1] == "_G" then
				out = { "_G", rawget( self, "global" ) }
			end
		end
		return table.unpack(out)
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.Context = {
	__call = function( self, targetPath_or_targetIndexArray, callContext, ... )

		local oldContextInfo = ModUtil.Locals._ContextInfo
		local contextInfo = {
			call = callContext,
			parent = oldContextInfo
		}

		if type(targetPath_or_targetIndexArray) == "string" then
			targetPath_or_targetIndexArray = ModUtil.PathToIndexArray(targetPath_or_targetIndexArray)
		end

		contextInfo.targetIndexArray = targetPath_or_targetIndexArray or {}
		if oldContextInfo ~= nil then
			contextInfo.indexArray = oldContextInfo.indexArray
			contextInfo.baseTable = oldContextInfo.baseTable
		else
			contextInfo.indexArray = {}
			contextInfo.baseTable = _G
		end

		local callContextProcessor = rawget( self, "callContextProcessor" )
		contextInfo.callContextProcessor = callContextProcessor

		local contextData, contextArgs = callContextProcessor( contextInfo, ... )
		contextData = contextData or _G
		contextArgs = contextArgs or {}

		local _ContextInfo = contextInfo
		_ContextInfo.data = contextData
		_ContextInfo.args = contextArgs

		local _ENV = contextData
		callContext( table.unpack( contextArgs ) )

	end
}

function ModUtil.New.Context( callContextProcessor )
	local context = { callContextProcessor = callContextProcessor }
	setmetatable( context, ModUtil.Metatables.Context )
	return context
end

ModUtil.Context.Call = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	local obj = ModUtil.ArrayGet( info.baseTable, info.indexArray )
	while type( obj ) ~= "function" do
		if type( obj ) ~= "table" then return end
		local meta = getmetatable(obj)
		if meta.__call then
			table.insert( info.indexArray, ModUtil.Nodes.Table.Metatable )
			table.insert( info.indexArray, "__call" )
			obj = meta.__call
		end
	end
	table.insert( info.indexArray, ModUtil.Nodes.Table.Environment )
	return ModUtil.ArrayNewTable( info.baseTable, info.indexArray )
end )

ModUtil.Context.Meta = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	table.insert( info.indexArray, ModUtil.Nodes.Table.Metatable )
	local env = { data = ModUtil.ArrayNewTable( info.baseTable, info.indexArray ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.ContextEnvironment )
	return env
end )

ModUtil.Context.Data = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	local env = { data = ModUtil.ArrayNewTable( info.baseTable, info.indexArray ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.ContextEnvironment )
	return env
end )

-- Special traversal nodes (WIP)

ModUtil.Nodes = ModUtil.New.EntangledInvertiblePair()

ModUtil.Nodes.Table.Metatable = {
	New = function( obj )
		local meta = getmetatable( obj )
		if meta == nil then
			meta = {}
			setmetatable( obj, meta )
		end
		return meta
	end,
	Get = function( obj )
		return getmetatable( obj )
	end,
	Set = function( obj, value )
		setmetatable( obj, value )
		return true
	end
}

ModUtil.Nodes.Table.UpValues = {
	New = function()
		return false
	end,
	Get = function( obj )
		return ModUtil.GetUpValues( obj )
	end,
	Set = function()
		return false
	end
}

ModUtil.Nodes.Table.Environment = {
	New = function( obj )
		local env = getfenv( obj )
		if env == __G._G then
			env = {}
			env.data = env.data or {}
			env.fallback = _G
			env.global = env
			setmetatable( env, ModUtil.Metatables.ContextEnvironment )
			setfenv( obj, env )
		end
		return env
	end,
	Get = function( obj )
		return getfenv( obj )
	end,
	Set = function( obj, value )
		setfenv( obj, value )
		return true
	end
}

-- Mods tracking (WIP)

ModUtil.Mods = ModUtil.New.EntangledInvertiblePair()
ModUtil.Mods.Table.ModUtil = ModUtil

--[[
	Users should only ever opt-in to running this function
]]
function ModUtil.EnableModHistory()
	if not ModHistory then
		ModHistory = {}
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores["ModHistory"] = nil
	end
end

function ModUtil.DisableModHistory()
	if not ModHistory then
		ModHistory = {}
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores["ModHistory"] = nil
	end
end

function ModUtil.UpdateModHistoryEntry( options )
	if options.Override then
		ModUtil.EnableModHistory()
	end
	if ModHistory then
		local mod = options.Mod
		local path = options.Path
		if mod == nil then
			mod = ModUtil.Mods.Table[path]
		end
		if path == nil then
			path = ModUtil.Mods.Index[mod]
		end
		local entry = ModHistory[path]
		if entry == nil then
			entry = {}
			ModHistory[path] = entry
		end
		if options.Version then
			entry.Version = options.Version
		end
		if options.FirstTime or options.All then
			if not entry.FirstTime then
				entry.FirstTime = os.time()
			end
		end
		if options.LastTime or options.All then
			entry.LastTime = os.time()
		end

		if options.Count or options.All then
			local count = entry.Count
			if not count then
				count = 0
			end
			entry.Count = count + 1
		end
	end
end

function ModUtil.PopulateModHistory( options )
	if not options then
		options = {}
	end
	for path, mod in pairs(ModUtil.Mods.Table) do
		options.Path, options.Mod = path, mod
		ModUtil.UpdateModHistoryEntry( options )
	end
end