--[[
Mod: Mod Utility
Author: MagicGonads

	Library to allow mods to be more compatible with eachother and expand capabilities.
	Use the mod importer to import this mod to ensure it is loaded in the right position.

]]

ModUtil = {
	Internal = { },
	Metatables = { },
	New = { },
	Anchors = {
		Menu = { },
		CloseFuncs = { }
	},
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
	local f = m and m.__next or rawnext
	return f( t, k )
end

local next = next

-- truly raw pairs, ignores __next and __pairs
function rawpairs( t )
	return rawnext, t, nil
end

-- quasi-raw pairs, invokes __next but ignores __pairs
function qrawpairs( t )
    return next, t, nil
end

local rawget = rawget

-- doesn't invoke __index just like rawnext
function rawinext( t, i )
	if i == nil then i = 0 end
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
	local f = m and m.__inext or rawinext
	return f( t, i )
end

local inext = inext

-- truly raw ipairs, ignores __inext and __ipairs
function rawipairs( t )
	return function( self, key )
		return rawinext( self, key )
	end, t, nil
end

-- quasi-raw ipairs, invokes __inext but ignores __ipairs
function qrawipairs( t )
	return function( self, key )
		return inext( self, key )
	end, t, nil
end

local type = type

function getfenv( fn )
	if type( fn ) ~= "function" then
		fn = debug.getinfo( ( fn or 1 ) + 1, "f" ).func
	end
	local i = 0
	repeat
		i = i + 1
		local name, val = debug.getupvalue( fn, i )
		if name == "_ENV" then
			return val
		end
	until not name
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
	if type( fn ) ~= "function" then
		fn = debug.getinfo( ( fn or 1 ) + 1, "f" ).func
	end
	local i = 0
	repeat
		i = i + 1
		local name = debug.getupvalue( fn, i )
		if name == "_ENV" then
			debug.upvaluejoin( fn, i, ( function( )
				return env
			end ), 1 )
			return env
		end
	until not name
end

local table = table

table.rawinsert = table.insert
-- table.insert that respects metamethods
function table.insert( list, pos, value )
	local last = #list
	if value == nil then
		value = pos
		pos = last + 1
	end
	if pos < 1 or pos > last + 1 then
		error( "bad argument #2 to '" .. debug.getinfo( 1, "n" ).name .. "' (position out of bounds)", 2 )
	end
	if pos <= last then
		local i = last
		repeat
			list[ i + 1 ] = list[ i ]
			i = i - 1
		until i <= pos
	end
	list[ pos ] = value
end

table.rawremove = table.remove
-- table.remove that respects metamethods
function table.remove( list, pos )
	local last = #list
	if pos == nil then
		pos = last
	end
	if pos < 1 or pos > last then
		error( "bad argument #2 to '" .. debug.getinfo( 1, "n" ).name .. "' (position out of bounds)", 2 )
	end
	local value = list[ pos ]
	if pos <= last then
		local i = pos
		repeat
			list[ i ] = list[ i + 1 ]
			i = i + 1
		until i > last
	end
	return value
end

--[[
	NOTE: Other table functions that need to get updated to respect metamethods
	- table.unpack
	- table.concat
	- table.sort
]]

-- Environment Context (EXPERIMENTAL) (WIP) (INCOMPLETE)

-- bind to locals to minimise environment recursion
local
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, getfenv, setfenv, tostring, xpcall
	=
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, getfenv, setfenv, tostring, xpcall

function ModUtil.RawInterface( obj )

	local meta = {
		__index = function( _, key )
			return rawget( obj, key )
		end,
		__newindex = function( _, key, value )
			rawset( obj, key, value )
		end,
		__len = function( )
			return rawlen( obj )
		end,
		__next = function( _, key )
			return rawnext( obj, key )
		end,
		__inext = function( _ , idx )
			return rawinext( obj, idx )
		end,
		__pairs = function( )
			return rawpairs( obj )
		end,
		__ipairs = function(  )
			return rawipairs( obj )
		end
	}

	local interface = { }
	setmetatable( interface, meta )
	return interface

end

local __G = ModUtil.RawInterface( _G )
__G.__G = __G

local surrogateEnvironments = { }
setmetatable( surrogateEnvironments, { __mode = "k" } )

local function getenv( )
	local level = 3
	repeat
		level = level + 1
		local info = debug.getinfo( level, "f" )
		if info then
			local env = surrogateEnvironments[ info.func ]
			if env then
				return env
			end
		end
	until not info
	return __G
end

--[[
	Make lexical environments use locals instead of upvalues
]]
function ModUtil.ReplaceGlobalEnvironment( )

	local split = function( path )
		if type( path ) == "string"
		and path:find("[.]")
		and not path:find("[.][.]+")
		and not path:find("^[.]")
		and not path:find("[.]$") then
			return ModUtil.PathToIndexArray( path )
		end
		return { path }
	end
	local get = ModUtil.SafeGet
	debug.setmetatable( __G._G, { } )

	local meta = {
		__index = function( _, key )
			local env = getenv( )
			local value = env[ key ]
			if value ~= nil then return value end
			return get( env, split( key ) )
		end,
		__newindex = function( _, key, value )
			getenv( )[ key ] = value
		end,
		__len = function( )
			return #getenv( )
		end,
		__next = function( _, key )
			return next( getenv( ), key )
		end,
		__inext = function( _, key )
			return inext( getenv( ), key )
		end,
		__pairs = function( )
			return pairs( getenv( ) )
		end,
		__ipairs = function( )
			return ipairs( getenv( ) )
		end
	}

	debug.setmetatable( __G._G, meta )
end

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
function ModUtil.RegisterMod( modName, parent, content )
	if not parent then
		parent = _G
		SaveIgnores[ modName ] = true
	end
	local mod = parent[ modName ]
	if not mod then
		mod = { }
		parent[ modName ] = mod
		local path = ModUtil.Mods.Index[ parent ]
		if path ~= nil then
			path = path .. '.'
		else
			path = ''
		end
		path = path .. modName
		ModUtil.Mods.Table[ path ] = mod
		ModUtil.Identifiers.Table[ mod ] = path
	end
	if content then
		ModUtil.MapSetTable( parent[ modName ], content )
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
	ModUtil.Anchors.CloseFuncs = { }
	ModUtil.Anchors.Menu = { }
end
OnAnyLoad{ function( triggerArgs ) ModUtil.ForceClosed( triggerArgs ) end }

ModUtil.Internal.FuncsToLoad = { }

function ModUtil.Internal.LoadFuncs( triggerArgs )
	for _, v in pairs( ModUtil.Internal.FuncsToLoad ) do
		v( triggerArgs )
	end
	ModUtil.Internal.FuncsToLoad = { }
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
	for i, v in ipairs( ModUtil.Internal.FuncsToLoad ) do
		if v == triggerFunction then
			table.remove( ModUtil.Internal.FuncsToLoad, i )
		end
	end
end

-- Data Misc

function ModUtil.ReferFunction( funcPath, baseTable )
	if type( baseTable ) == "number" then -- locals
		baseTable = ModUtil.Locals( baseTable + 1 )
	end
	baseTable = baseTable or _G
	local indexArray = ModUtil.PathToIndexArray( funcPath )
	return function( ... )
		return ModUtil.SafeGet( baseTable, indexArray )( ... )
	end
end

local passByValueTypes = ToLookup{ "number", "boolean", "nil" }
local excludedFieldNames = ToLookup{ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" }

function ModUtil.ValueString( o )
	local t = type( o )
	if t == 'string' then
		return '"' .. o .. '"'
	end
	if passByValueTypes[ t ] then
		return tostring( o )
	end
	local identifier = ModUtil.Identifiers.Table[ o ]
	if identifier then
		identifier = "(" .. identifier .. ")"
	else
		identifier = ""
	end
	return identifier .. '<' .. tostring( o ) .. '>'
end

function ModUtil.KeyString( o )
	local t = type( o )
	o = tostring( o )
	if t == 'string' and not excludedFieldNames[ o ] then
		local pattern = "^[a-zA-Z_][a-zA-Z0-9_]*$"
		if o:gmatch( pattern ) then
			return o
		end
		return '"' .. o .. '"'
	end
	if t == 'number' then
	    o = "#" .. o
	end
	if not passByValueTypes[ t ] then
        o = '<' .. o .. '>'
	end
	local identifier = ModUtil.Identifiers.Table[ o ]
	if identifier then
		identifier = "(" .. identifier .. ")"
	else
		identifier = ""
	end
	return identifier .. o
end

function ModUtil.TableKeysString( o )
	if type( o ) == 'table' then
		local out = { }
		for k in pairs( o ) do
			table.insert( out , ModUtil.KeyString( k ) )
			table.insert( out , ', ' )
		end
		table.remove( out )
		return table.concat( out )
	end
end

function ModUtil.ToShallowString( o )
	if type( o ) == "table" then
		local out = { ModUtil.ValueString( o ), "{ " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.KeyString( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ValueString( v ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ValueString( o )
	end
end

function ModUtil.ToDeepString( o, seen )
	seen = seen or { }
	if type( o ) == "table" and not seen[ o ] then
		seen[ o ] = true
		local out = { ModUtil.ValueString( o ), "{ " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.KeyString( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ToDeepString( v, seen ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ValueString( o )
	end
end

function ModUtil.ToDeepNoNamespacesString( o, seen )
	local first = false
	if not seen then
		first = true
		seen = { }
	end
	if type( o ) == "table" and not seen[ o ] and o ~= __G._G and ( first or not ModUtil.Mods.Index[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ValueString( o ), "{ " }
		for k, v in pairs( o ) do
			if v ~= __G._G and not ModUtil.Mods.Index[ v ] then
				table.insert( out, ModUtil.KeyString( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToDeepNoNamespacesString( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ValueString( o )
	end
end

function ModUtil.ToDeepNamespacesString( o, seen )
	local first = false
	if not seen then
		first = true
		seen = { }
	end
	if type( o ) == "table" and not seen[ o ] and ( first or o == __G._G or ModUtil.Mods.Index[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ValueString( o ), "{ " }
		for k, v in pairs( o ) do
			if v == __G._G or ModUtil.Mods.Index[ v ] then
				table.insert( out, ModUtil.KeyString( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToDeepNamespacesString( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ValueString( o )
	end
end

function ModUtil.MapVars( mapFunc, ... )
	local out = {}
	for _, v in ipairs{ ... } do
		table.insert( out, mapFunc( v ) )
	end
	return table.unpack( out )
end

function ModUtil.MapTable( mapFunc, tableArg )
	local out = {}
	for k, v in pairs( tableArg ) do
		out[ k ] = mapFunc( v )
	end
	return out
end

function ModUtil.JoinStrings( sep, ... )
	local out = {}
	local args = { ... }
	local i
	i, out[ 1 ] = inext( args )
	for _, v in inext, args, i do
		table.insert( out, sep )
		table.insert( out, v )
	end
	return table.concat( out )
end

function ModUtil.ChunkText( text, chunkSize, maxChunks )
	local chunks = { "" }
	local cs = 0
	local ncs = 1
	for chr in text:gmatch( "." ) do
		cs = cs + 1
		if cs > chunkSize or chr == "\n" then
			ncs = ncs + 1
			if maxChunks and ncs > maxChunks then
				return chunks
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
		target[ k ] = data[ k ]
	end
	for k, v in pairs( data ) do
		target[ k ] = v
	end
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

-- Printing

function ModUtil.PrintToFile( file, ... )
	local close = false
	if type( file ) == "string" and io then
		file = io.open( file, "a" )
		close = true
	end
	file:write( ModUtil.MapVars( tostring, ... ) )
	if close then
		file:close( )
	end
end

function ModUtil.DebugPrint( ... )
	local text = ModUtil.JoinStrings( "\t", ModUtil.MapVars( tostring, ... ) ):gsub( "\t", "    " )
	for line in text:gmatch( "([^\n]+)" ) do
		DebugPrint{ Text = line }
	end
end

function ModUtil.Print( ... )
	print( ... )
	if DebugPrint then ModUtil.DebugPrint( ... ) end
	if io then
		if io.stdout ~= io.output( ) then
			ModUtil.PrintToFile( io.output( ), ... )
		end
		io.flush( )
	end
end

function ModUtil.PrintTraceback( level )
	level = ( level or 1 )
	ModUtil.Print("Traceback:")
	local cont = true
	while cont do
		local text = debug.traceback( "", level ):sub( 2 )
		local first = true
		local i = 1
		cont = false
		for line in text:gmatch( "([^\n]+)" ) do
			if first then
				first = false
			else
				if line == "\t" then
					break
				end
				if i > 10 then
					cont = true
					break
				end
				ModUtil.Print( line )
				i = i + 1
			end
		end
		level = level + 10
	end
end

function ModUtil.PrintDebugInfo( level )
	level = ( level or 1 )
	local text
	text = ModUtil.ToDeepString( debug.getinfo( level + 1 ) )
	ModUtil.Print( "Debug Info:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
end

function ModUtil.PrintNamespaces( level )
	level = ( level or 1 )
	local text
	ModUtil.Print("Namespaces:")
	text = ModUtil.ToDeepNamespacesString( ModUtil.Locals( level + 1 ) )
	ModUtil.Print( "\t" .. "Locals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToDeepNamespacesString( ModUtil.UpValues( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	local func = debug.getinfo( level + 1, "f" ).func
	text = ModUtil.ToDeepNamespacesString( surrogateEnvironments[ func ] or getfenv( func ) )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text )
end

function ModUtil.PrintVariables( level )
	level = ( level or 1 )
	local text
	ModUtil.Print("Variables:")
	text = ModUtil.ToDeepNoNamespacesString( ModUtil.Locals( level + 1 ) )
	ModUtil.Print( "\t" .. "Locals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToDeepNoNamespacesString( ModUtil.UpValues( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	local func = debug.getinfo( level + 1, "f" ).func
	text = ModUtil.ToDeepNoNamespacesString( surrogateEnvironments[ func ] or getfenv( func ) )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text )
end

--[[
	Call a function with the provided arguments
	instead of halting when an error occurs it prints the entire error traceback
]]
function ModUtil.DebugCall( f, ... )
	return xpcall( f, function( err )
		ModUtil.Print( err )
		ModUtil.PrintDebugInfo( 2 )
		ModUtil.PrintNamespaces( 2 )
		ModUtil.PrintVariables( 2 )
		ModUtil.PrintTraceback( 2 )
    end, ... )
end

-- Data Manipulation

--[[
	Return a slice of an array table, python style
		would be written state[ start : stop : step ] in python
	
	start and stop are offsets rather than ordinals
		meaning 0 corresponds to the start of the array
		and -1 corresponds to the end
]]
function ModUtil.Slice( state, start, stop, step )
	local slice = { }
	local n = #state
	start = start or 0
	if start < 0 then
		start = start + n
	end
	stop = stop or n
	if stop < 0 then
		stop = stop + n
	end
	for i = start, stop - 1, step do
		table.insert( slice, state[ i + 1 ] )
	end
	return slice
end

local function ShallowCopyTable( orig )
	-- from UtilityScripts.lua
	if orig == nil then
		return
	end

	local copy = { }
	for k, v in pairs( orig ) do
		copy[ k ] = v
	end
	return copy
end

local function DeepCopyTable( orig )
	-- from UtilityScripts.lua
	local orig_type = type( orig )
	local copy
	if orig_type == 'table' then
		copy = { }
		-- slightly more efficient to call next directly instead of using pairs
		for k, v in next, orig, nil do
			copy[ k ] = DeepCopyTable( v )
		end
	else
		copy = orig
	end
	return copy
end

ModUtil.Internal.MarkedForCollapse = { }

function ModUtil.CollapseTable( tableArg )
	local collapsedTable = { }
	local usedIndices = {}
	local i = 1
	repeat
		collapsedTable[ i ] = tableArg[ i ]
		usedIndices[ i ] = true
		i = i + 1
	until i > #tableArg
	for k, v in pairs( tableArg ) do
		if not usedIndices[ k ] then
			collapsedTable[ i ] = v
			i = i + 1
		end
	end
	return collapsedTable
end

function ModUtil.CollapseTableInPlace( tableArg )
	local collapsedTable = ModUtil.CollapseTable( tableArg )
	for k in pairs( tableArg ) do
		tableArg[ k ] = nil
	end
	for i, v in pairs( collapsedTable ) do
		tableArg[ i ] = v
	end
end

function ModUtil.CollapseMarked( )
	for tbl, state in pairs( ModUtil.Internal.MarkedForCollapse ) do
		if state then
			ModUtil.CollapseTableInPlace( tbl )
		end
	end
	ModUtil.Internal.MarkedForCollapse = { }
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
	local nodeType = ModUtil.Nodes.Index[ key ]
	if nodeType then
		return ModUtil.Nodes.Table[ nodeType ].New( tableArg )
	end
	local tbl = tableArg[ key ]
	if type( tbl ) ~= "table" then
		tbl = { }
		tableArg[ key ] = tbl
	end
	return tbl
end

--[[
	Safely retrieve the a value from deep inside a table, given
	an array of indices into the table.

	For example, if indexArray is { "a", 1, "c" }, then
	Table[ "a" ][ 1 ][ "c" ] is returned. If any of Table[ "a" ],
	Table[ "a" ][ 1 ], or Table[ "a" ][ 1 ][ "c" ] are nil, then nil
	is returned instead.

	Table			 - the table to retrieve from
	indexArray	- the list of indices
]]
function ModUtil.SafeGet( baseTable, indexArray )
	local node = baseTable
	for _, key in ipairs( indexArray ) do
		if type( node ) ~= "table" then
			return nil
		end
		local nodeType = ModUtil.Nodes.Index[ key ]
		if nodeType then
			node = ModUtil.Nodes.Table[ nodeType ].Get( node )
		else
			node = node[ key ]
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
	local n = #indexArray -- change to shallow copy + table.remove later
	local node = baseTable
	for i = 1, n - 1 do
		local key = indexArray[ i ]
		if not ModUtil.NewTable( node, key ) then return false end
		local nodeType = ModUtil.Nodes.Index[ key ]
		if nodeType then
			node = ModUtil.Nodes.Table[ nodeType ].Get( node )
		else
			node = node[ key ]
		end
	end
	local key = indexArray[ n ]
	local nodeType = ModUtil.Nodes.Index[ key ]
	if nodeType then
		return ModUtil.Nodes.Table[ nodeType ].Set( node, value )
	end
	node[ key ] = value
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
	for nilKey, nilVal in pairs( nilTable ) do
		local inVal = inTable[ nilKey ]
		if type( nilVal ) == "table" and type( inVal ) == "table" then
			ModUtil.MapNilTable( inVal, nilVal )
		else
			inTable[ nilKey ] = nil
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
	for setKey, setVal in pairs( setTable ) do
		local inVal = inTable[ setKey ]
		if type( setVal ) == "table" and type( inVal ) == "table" then
			ModUtil.MapSetTable( inVal, setVal )
		else
			inTable[ setKey ] = setVal
		end
	end
end

-- Path Manipulation

--[[
	Concatenates two index arrays, in order.

	a, b - the index arrays
]]
function ModUtil.JoinIndexArrays( a, b )
	local c = { }
	local j = 0
	for i, v in ipairs( a ) do
		c[ i ] = v
		j = i
	end
	for i, v in ipairs( b ) do
		c[ i + j ] = v
	end
	return c
end

--[[
	Create an index array from the provided Path.

	The returned array can be used as an argument to the safe table
	manipulation functions, such as ModUtil.SafeSet and ModUtil.SafeGet.

	path - a dot-separated string that represents a path into a table
]]
function ModUtil.PathToIndexArray( path )
	if type( path ) == "table" then return path end -- assume index array is given
	local s = ""
	local i = { }
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

	For example, ModUtil.PathGet( "a.b.c" ) returns a.b.c.
	If either a or a.b is nil, nil is returned instead.

	path - the path to get the value
	base - (optional) The table to retreive the value from.
				 If not provided, retreive a global.
]]
function ModUtil.PathGet( path, base )
	return ModUtil.SafeGet( base or _G, ModUtil.PathToIndexArray( path ) )
end

--[[
	Safely get set a value to a Path.

	For example, ModUtil.PathSet( "a.b.c", 1 ) sets a.b.c = 1.
	If either a or a.b is nil, they are created.

	path - the path to get the value
	base - (optional) The table to retreive the value from.
				 If not provided, retreive a global.
]]
function ModUtil.PathSet( path, value, base )
	return ModUtil.SafeSet( base or _G, ModUtil.PathToIndexArray( path ), value )
end

-- Metaprogramming Shenanigans (EXPERIMENTAL) (WIP)

local stackLevelProperty
stackLevelProperty = {
	here = function( self )
		local thread = rawget( self, "thread" )
		local cursize = rawget( self, "level" ) + 1
		while debug.getinfo( thread, cursize, "f" ) do
			cursize = cursize + 1
		end
		return cursize - rawget( self, "size" ) - 1
	end,
	top = function( self )
		local thread = rawget( self, "thread" )
		local level = rawget( self, "level" )
		local cursize = level + 1
		while debug.getinfo( thread, cursize, "f" ) do
			cursize = cursize + 1
		end
		return cursize - level - 1
	end,
	there = function( self ) return rawget( self, "level" ) end,
	bottom = function( self ) return rawget( self, "size" ) end,
	co = function( self ) return rawget( self, "thread" ) end,
	func = function( self )
		return debug.getinfo( self.co, self.here, "f" ).func
	end
}

local stackLevelFunction = {
	gethook = function( self, ... )
		return debug.gethook( self.co, ... )
	end,
	sethook = function( self, ... )
		return debug.sethook( self.co, ... )
	end,
	getlocal = function( self, ... )
		return debug.getlocal( self.co, self.here, ... )
	end,
	setlocal = function( self, ... )
		return debug.setlocal( self.co, self.here, ... )
	end,
	getinfo = function( self, ... )
		return debug.getinfo( self.co, self.here, ... )
	end,
	getupvalue = function( self, ... )
		return debug.getupvalue( self.func, ... )
	end,
	setupvalue = function( self, ... )
		return debug.setupvalue( self.func, ... )
	end,
	upvalueid = function( self, ... )
		return debug.upvalueid( self.func, ... )
	end,
	upvaluejoin = function( self, ... )
		return debug.upvaluejoin( self.func, ... )
	end,
	getfenv = function( self, ... )
		return getfenv( self.func, ... )
	end,
	setfenv = function( self, ... )
		return setfenv( self.func, ... )
	end
}

local stackLevelInterface = {}
for k, v in pairs( stackLevelProperty ) do
	stackLevelInterface[ k ] = v
	stackLevelProperty[ k ] = true
end
for k, v in pairs( stackLevelFunction ) do 
	stackLevelInterface[ k ] = v
	stackLevelFunction[ k ] = true
end

ModUtil.Metatables.StackLevel = {
	__index = function( self, key )
		if stackLevelProperty[ key ] then
			return stackLevelInterface[ key ]( self )
		elseif stackLevelFunction[ key ] then
			local func = stackLevelInterface[ key ]
			return function( ... )
				return func( self, ... )
			end
		end
	end,
	__newindex = function( ) end,
	__len = function( )
		return 0
	end,
	__next = function( self, key )
		repeat
			key = next( stackLevelInterface, key )
		until stackLevelFunction[ key ] == nil
		return key, self[ key ]
	end,
	__inext = function( ) end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
	__ipairs = function( self )
		return function( ) end, self
	end,
	__eq = function( self, other )
		return rawget( self, "thread" ) == rawget( other, "thread" )
		and rawget( self, "size" ) == rawget( other, "size")
		and rawget( self, "level" ) == rawget( other, "level")
	end
}

function ModUtil.StackLevel( level )
	level = ( level or 1 )
	local thread = coroutine.running( )
	local size = level + 1
	if not debug.getinfo( thread, level, "f" ) then return end
	while debug.getinfo( thread, size, "f" ) do
		size = size + 1
	end
	size = size - level - 1
	if size > 0 then
		local stackLevel = { level = level, size = size, thread = thread }
		setmetatable( stackLevel, ModUtil.Metatables.StackLevel )
		return stackLevel
	end
end

ModUtil.Metatables.StackLevels = {
	__index = function( self, level )
		return ModUtil.StackLevel( ( level or 0 ) + rawget( self, "level" ).here )
	end,
	__newindex = function() end,
	__len = function( self )
		return rawget( self, "level" ).bottom
	end,
	__next = function( self, level )
		level = ( level or 0 ) + 1
		local stackLevel = self[ level ]
		if stackLevel then
			return level, stackLevel
		end
	end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end
}
ModUtil.Metatables.StackLevels.__ipairs = ModUtil.Metatables.StackLevels.__pairs
ModUtil.Metatables.StackLevels.__inext = ModUtil.Metatables.StackLevels.__next

function ModUtil.StackLevels( level )
	local levels = { level = ModUtil.StackLevel( level or 0 ) }
	setmetatable( levels, ModUtil.Metatables.StackLevels )
	return levels
end

local excludedUpValueNames = ToLookup{ "_ENV" }

local idData = { }
setmetatable( idData, { __mode = "k" } )

local function getUpValueIdData( id )
	local tbl = idData[ id ]
	return tbl.func, tbl.idx
end

local function setUpValueIdData( id, func, idx )
	local tbl = idData[ id ]
	if not tbl then
		tbl = {}
		idData[ id ] = tbl
	end
	tbl.func, tbl.idx = func, idx
end

local upvaluejoin = debug.upvaluejoin

function debug.upvaluejoin( f1, n1, f2, n2 )
	upvaluejoin( f1, n1, f2, n2 )
	setUpValueIdData( debug.upvalueid( f1, n1 ), f2, n2 )
end

ModUtil.Metatables.UpValueIds = {
	__index = function( self, idx )
		local func =  rawget( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			local id = debug.upvalueid( func, idx )
			setUpValueIdData( id, func, idx )
			return id
		end
	end,
	__newindex = function( self, idx, value )
		local func = rawget( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			local func2, idx2 = getUpValueIdData( value )
			debug.upvaluejoin( func, idx, func2, idx2 )
			return
		end
	end,
	__len = function( self )
		return debug.getinfo( rawget( self, "func" ), 'u' ).nups
	end,
	__next = function ( self, idx )
		local func = rawget( self, "func" )
		idx = idx or 0
		local name
		while true do
			idx = idx + 1
			name = debug.getupvalue( func, idx )
			if not name then return end
			if not excludedUpValueNames[ name ] then
				return idx, self[ idx ]
			end
		end
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end
}
ModUtil.Metatables.UpValueIds.__inext = ModUtil.Metatables.UpValueIds.__next
ModUtil.Metatables.UpValueIds.__ipairs = ModUtil.Metatables.UpValueIds.__pairs

function ModUtil.UpValueIds( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValueIds )
	return ups
end

ModUtil.Metatables.UpValueValues = {
	__index = function( self, idx )
		local name, value = debug.getupvalue( rawget( self, "func" ), idx )
		if name and not excludedUpValueNames[ name ] then
			return value
		end
	end,
	__newindex = function( self, idx, value )
		local func = rawget( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			debug.setupvalue( func, idx, value )
			return
		end
	end,
	__len = function( self )
		return debug.getinfo( rawget( self, "func" ), 'u' ).nups
	end,
	__next = function ( self, idx )
		local func = rawget( self, "func" )
		idx = idx or 0
		local name, value
		while true do
			idx = idx + 1
			name, value = debug.getupvalue( func, idx )
			if not name then return end
			if not excludedUpValueNames[ name ] then
				return idx, value
			end
		end
	end,
	__pairs = ModUtil.Metatables.UpValueIds.__pairs,
	__ipairs = ModUtil.Metatables.UpValueIds.__ipairs
}
ModUtil.Metatables.UpValueValues.__inext = ModUtil.Metatables.UpValueValues.__next

function ModUtil.UpValueValues( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValueValues )
	return ups
end

ModUtil.Metatables.UpValueNames = {
	__index = function( self, idx )
		local name = debug.getupvalue( rawget( self, "func" ), idx )
		if name and not excludedUpValueNames[ name ] then
			return name
		end
	end,
	__newindex = function( ) end,
	__len = ModUtil.Metatables.UpValueValues.__len,
	__next = function ( self, idx )
		local func = rawget( self, "func" )
		idx = idx or 0
		local name
		while true do
			idx = idx + 1
			name = debug.getupvalue( func, idx )
			if not name then return end
			if not excludedUpValueNames[ name ] then
				return idx, name
			end
		end
	end,
	__pairs = ModUtil.Metatables.UpValueIds.__pairs,
	__ipairs = ModUtil.Metatables.UpValueIds.__ipairs
}
ModUtil.Metatables.UpValueNames.__inext = ModUtil.Metatables.UpValueNames.__next

function ModUtil.UpValueNames( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValueNames )
	return ups
end

ModUtil.Metatables.UpValues = {
	__index = function( self, name )
		if excludedUpValueNames[ name ] then return end
		local func = rawget( self, "func" )
		local idx = 0
		repeat
			idx = idx + 1
			local n, value = debug.getupvalue( func, idx )
			if n == name then
				return value
			end
		until not n
	end,
	__newindex = function( self, name, value )
		if excludedUpValueNames[ name ] then return end
		local func = rawget( self, "func" )
		local idx = name and 0 or -1
		repeat
			idx = idx + 1
			local n = debug.getupvalue( func, idx )
			if n == name then
				debug.setupvalue( func, idx, value )
				return
			end
		until not n
	end,
	__len = function ( self )
		return 0
	end,
	__next = function ( self, name )
		local func = rawget( self, "func" )
		local idx = name and 0 or -1
		repeat
			idx = idx + 1
			local n = debug.getupvalue( func, idx )
			if n == name then
				local value
				repeat
					idx = idx + 1
					n, value = debug.getupvalue( func, idx )
					if n and not excludedUpValueNames[ n ] then
						return n, value
					end
				until not n
			end
		until not n
	end,
	__inext = function() end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return function() end, self
	end
}

--[[
	Return a table representing the upvalues of a function.

	Upvalues are those variables captured by a function from it's
	creation context. For example, locals defined in the same file
	as the function are accessible to the function as upvalues.

	func - the function to get upvalues from
]]
function ModUtil.UpValues( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local upValues = { func = func }
	setmetatable( upValues, ModUtil.Metatables.UpValues )
	return upValues
end

ModUtil.Metatables.StackedUpValues = {
	__index = function( self, name )
		if excludedUpValueNames[ name ] then return end
		for _, level in pairs( rawget( self, "levels" ) ) do
			local idx = 0
			repeat
				idx = idx + 1
				local n, v = level.getupvalue( idx )
				if n == name then
					return v
				end
			until not n
		end
	end,
	__newindex = function( self, name, value )
		if excludedUpValueNames[ name ] then return end
		for _, level in pairs( rawget( self, "levels" ) ) do
			local idx = 0
			repeat
				idx = idx + 1
				local n = level.getupvalue( idx )
				if n == name then
					level.setupvalue( idx, value )
					return
				end
			until not n
		end
	end,
	__len = function( )
		return 0
	end,
	__next = function( self, name )
		local levels = rawget( self, "levels" )
		for _, level in pairs( levels ) do
			local idx = name and 0 or -1
			repeat
				idx = idx + 1
				local n = level.getupvalue( idx )
				if name and n == name or not name then
					local value
					repeat
						idx = idx + 1
						n, value = level.getupvalue( idx )
						if n and not excludedUpValueNames[ n ] then
							return n, value
						end
					until not n
				end
			until not n
		end
	end,
	__inext = function( ) return end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
	__ipairs = function( self )
		return function() end, self
	end
}

function ModUtil.StackedUpValues( level )
	local upValues = { levels = ModUtil.StackLevels( ( level or 1 ) ) }
	setmetatable( upValues, ModUtil.Metatables.StackedUpValues )
	return upValues
end

local excludedLocalNames = ToLookup{ "(*temporary)", "(for generator)", "(for state)", "(for control)" }

ModUtil.Metatables.LocalValues = {
	__index = function( self, idx )
		local name, value = rawget( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return value
			end
		end
	end,
	__newindex = function( self, idx, value )
		local level = rawget( self, "level" )
		local name = level.getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				level.setlocal( idx, value )
			end
		end
	end,
	__len = function( self )
		local level = rawget( self, "level" )
		local idx = 1
		while level.getlocal( level, idx ) do
			idx = idx + 1
		end
		return idx - 1
	end,
	__next = function( self, idx )
		idx = idx or 0
		idx = idx + 1
		local name, val = rawget( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return idx, val
			end
		end
	end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
}
ModUtil.Metatables.LocalValues.__ipairs = ModUtil.Metatables.LocalValues.__pairs
ModUtil.Metatables.LocalValues.__inext = ModUtil.Metatables.LocalValues.__next

--[[
	Example Use:
	for i, name, value in pairs( ModUtil.LocalValues( level ) ) do
		--
	end
]]
function ModUtil.LocalValues( level )
	if level == nil then level = 1 end
	local locals = { level = ModUtil.StackLevel( level + 1 ) }
	setmetatable( locals, ModUtil.Metatables.LocalValues )
	return locals
end

ModUtil.Metatables.LocalNames = {
	__index = function( self, idx )
		local name = rawget( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return name
			end
		end
	end,
	__newindex = function( ) return end,
	__len = ModUtil.Metatables.LocalValues.__len,
	__next = function( self, idx )
		if idx == nil then idx = 0 end
		idx = idx + 1
		local name = rawget( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return idx, name
			end
		end
	end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
}
ModUtil.Metatables.LocalNames.__ipairs = ModUtil.Metatables.LocalNames.__pairs
ModUtil.Metatables.LocalNames.__inext = ModUtil.Metatables.LocalNames.__next

--[[
	Example Use:
	for i, name, value in pairs( ModUtil.LocalNames( level ) ) do
		--
	end
]]
-- WORKS
function ModUtil.LocalNames( level )
	if level == nil then level = 1 end
	local locals = { level = ModUtil.StackLevel( level + 1 ) }
	setmetatable( locals, ModUtil.Metatables.LocalNames )
	return locals
end

ModUtil.Metatables.Locals = {
	__index = function( self, name )
		if excludedLocalNames[ name ] then return end
		local level = rawget( self, "level" )
		local idx = 0
		repeat
			idx = idx + 1
			local n, v = level.getlocal( level, idx )
			if n == name then
				return v
			end
		until not n
	end,
	__newindex = function( self, name, value )
		if excludedLocalNames[ name ] then return end
		local level = rawget( self, "level" )
		local idx = 0
		repeat
			idx = idx + 1
			local n = level.getlocal( idx )
			if n == name then
				level.setlocal( idx, value )
				return
			end
		until not n
	end,
	__len = function( )
		return 0
	end,
	__next = function( self, name )
		local level = rawget( self, "level" )
		local idx = name and 0 or -1
		repeat
			idx = idx + 1
			local n = level.getlocal( idx )
			if name and n == name or not name then
				local value
				repeat
					idx = idx + 1
					n, value = level.getlocal( idx )
					if n and not excludedLocalNames[ n ] then
						return n, value
					end
				until not n
			end
		until not n
	end,
	__inext = function( ) return end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
	__ipairs = function( self )
		return function( ) end, self
	end
}

function ModUtil.Locals( level )
	local locals = { level = ModUtil.StackLevel( ( level or 1 ) + 1 ) }
	setmetatable( locals, ModUtil.Metatables.Locals )
	return locals
end

ModUtil.Metatables.StackedLocals = {
	__index = function( self, name )
		if excludedLocalNames[ name ] then return end
		for _, level in pairs( rawget( self, "levels" ) ) do
			local idx = 0
			repeat
				idx = idx + 1
				local n, v = level.getlocal( idx )
				if n == name then
					return v
				end
			until not n
		end
	end,
	__newindex = function( self, name, value )
		if excludedLocalNames[ name ] then return end
		for _, level in pairs( rawget( self, "levels" ) ) do
			local idx = 0
			repeat
				idx = idx + 1
				local n = level.getlocal( idx )
				if n == name then
					level.setlocal( idx, value )
					return
				end
			until not n
		end
	end,
	__len = function( )
		return 0
	end,
	__next = function( self, name )
		local levels = rawget( self, "levels" )
		for _, level in pairs( levels ) do
			local idx = name and 0 or -1
			repeat
				idx = idx + 1
				local n = level.getlocal( idx )
				if name and n == name or not name then
					local value
					repeat
						idx = idx + 1
						n, value = level.getlocal( idx )
						if n and not excludedLocalNames[ n ] then
							return n, value
						end
					until not n
				end
			until not n
		end
	end,
	__inext = function( ) return end,
	__pairs = function( self )
		return qrawpairs( self ), self
	end,
	__ipairs = function( self )
		return function() end, self
	end
}

--[[
	Access to local variables, in the current function and callers.
	The most recent definition with a given name on the call stack will
	be used.

	For example, if your function is called from CreateTraitRequirements,
	you could access its 'local screen' as ModUtil.StackedLocals().screen
	and its 'local hasRequirement' as ModUtil.StackedLocals().hasRequirement.
]]
function ModUtil.StackedLocals( level )
	local locals = { levels = ModUtil.StackLevels( ( level or 1 ) ) }
	setmetatable( locals, ModUtil.Metatables.StackedLocals )
	return locals
end

-- Function Wrapping

ModUtil.Internal.WrapCallbacks = { }

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
		{ id = 1, mod = MyMod, wrap = wrapper, func = <original unwrapped function> }
		{ id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
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
	local func = ModUtil.SafeGet( funcTable, indexArray )
	if type( func ) ~= "function" then return end

	ModUtil.NewTable( ModUtil.Internal.WrapCallbacks, funcTable )
	local tempTable = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	if tempTable == nil then
		tempTable = { }
		ModUtil.SafeSet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray, tempTable )
	end
	table.insert( tempTable, { Id = #tempTable + 1, Mod = mod, Wrap = wrapFunc, Func = func } )

	ModUtil.SafeSet( skipenv( funcTable ), indexArray, function( ... )
		return wrapFunc( func, ... )
	end )
end

--[[
	Internal utility that reapplies the list of wrappers when the base function changes.

	For example. if the list of wrappers looks like:
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{ id = 1, mod = MyMod, wrap = wrapper, func = <original unwrapped function> }
		{ id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
		{ id = 3, mod = ModNumber3,  wrap = wrapper3, func = <original function + wrapper1 + wrapper 2> }
	}

	and the base function is modified by setting [ 1 ].func to a new value, like so:
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{ id = 1, mod = MyMod, wrap = wrapper, func = <new function> }
		{ id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <original function + wrapper1> }
		{ id = 3, mod = ModNumber3,  wrap = wrapper3, func = <original function + wrapper1 + wrapper 2> }
	}

	Then rewrap function will fix up eg. [ 2 ].func, [ 3 ].func so that the correct wrappers are applied
	ModUtil.Internal.WrapCallbacks[ _G ].UIFunctions.OnButton1Pushed = {
		{ id = 1, mod = MyMod, wrap = wrapper, func = <new function> }
		{ id = 2, mod = SomeOtherMod, wrap = wrapper2, func = <new function + wrapper1> }
		{ id = 3, mod = ModNumber3,  wrap = wrapper3, func = <new function + wrapper1 + wrapper 2> }
	}
	and also update the entry in funcTable to be the completely wrapped function, ie.

	UIFunctions.OnButton1Pushed = <new function + wrapper1 + wrapper2 + wrapper3>

	funcTable	 - the table the function is stored in (usually _G)
	indexArray	- the array of path elements to the function in the table
]]
function ModUtil.RewrapFunction( funcTable, indexArray )
	local wrapCallbacks = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	local preFunc = nil

	for _, tempTable in ipairs( wrapCallbacks ) do
		if preFunc then
			tempTable.Func = preFunc
		end
		preFunc = function( ... )
			return tempTable.Wrap( tempTable.Func, ... )
		end
		ModUtil.SafeSet( skipenv( funcTable ), indexArray, preFunc )
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
	local func = ModUtil.SafeGet( skipenv( funcTable ), indexArray )
	if type( func ) ~= "function" then return end

	local tempTable = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ funcTable ], indexArray )
	if not tempTable then return end
	local funcData = table.remove( tempTable ) -- removes the last value
	if not funcData then return end

	ModUtil.SafeSet( skipenv( funcTable ), indexArray, funcData.Func )
	return funcData
end


--[[
	Wraps the function with the path given by baseFuncPath, so that you
	can execute code before or after the original function is called,
	or modify the return value.

	For example:

	ModUtil.WrapBaseFunction( "CreateNewHero", function( baseFunc, prevRun, args )
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

ModUtil.Internal.Overrides = { }

local function getBaseValueForWraps( baseTable, indexArray )
	local baseValue = ModUtil.SafeGet( skipenv( baseTable ), indexArray )
	local wrapCallbacks = nil
	wrapCallbacks = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
	if wrapCallbacks then
		if wrapCallbacks[ 1 ] then
			baseValue = wrapCallbacks[ 1 ].Func
		end
	end

	return baseValue
end

local function setBaseValueForWraps( baseTable, indexArray, value )
	local baseValue = ModUtil.SafeGet( skipenv( baseTable ), indexArray )

	if type( baseValue ) ~= "function" or type( value ) ~= "function" then return false end

	local wrapCallbacks = nil
	wrapCallbacks = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
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
	For example, ModUtil.Override( _G, [ "UIFunctions", "OnButton1" ], overrideFunc, MyMod )
	will result in a data structure like:

	ModUtil.Internal.Overrides[ _G ].UIFunctions.OnButton1 = {
		{ id = 1, mod = MyMod, value = overrideFunc, base = <original value of UIFunctions.OnButton1> }
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
	local tempTable = ModUtil.SafeGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if tempTable == nil then
		tempTable = { }
		ModUtil.SafeSet( ModUtil.Internal.Overrides[ baseTable ], indexArray, tempTable )
	end
	table.insert( tempTable, { Id = #tempTable + 1, Mod = mod, Value = value, Base = baseValue } )

	if not setBaseValueForWraps( baseTable, indexArray, value ) then
		ModUtil.SafeSet( skipenv( baseTable ), indexArray, value )
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
	local tempTable = ModUtil.SafeGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if not tempTable then return end
	local baseData = table.remove( tempTable ) -- remove the last entry
	if not baseData then return end

	if not setBaseValueForWraps( baseTable, indexArray, baseData.Base ) then
		ModUtil.SafeSet( skipenv( baseTable ), indexArray, baseData.Base )
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
	ModUtil.Override( _G, ModUtil.PathToIndexArray( basePath ), value, mod )
end

--[[
	Undo the most recent override performed with ModUtil.Override,
	or ModUtil.BaseOverride, restoring the previous value.

	Use this carefully - if you are not the most recent mod to
	override the given path, the results may be unexpected.

	basePath	- the path to restore, as a string
]]
function ModUtil.BaseRestore( basePath )
	ModUtil.Restore( _G, ModUtil.PathToIndexArray( basePath ) )
end

-- Wrap/Override interaction

function ModUtil.GetOriginalValue( baseTable, indexArray )
	local baseValue = ModUtil.SafeGet( ModUtil.Internal.Overrides[ baseTable ], indexArray )
	if baseValue then
		baseValue = baseValue[ #baseValue ].Base
	else
		baseValue = ModUtil.SafeGet( ModUtil.Internal.WrapCallbacks[ baseTable ], indexArray )
		if baseValue then
			baseValue = baseValue[ 1 ].Func
		else
			baseValue = ModUtil.SafeGet( baseTable, indexArray )
		end
	end
	return baseValue
end

function ModUtil.GetOriginalBaseValue( basePath )
	return ModUtil.GetOriginalValue( _G, ModUtil.PathToIndexArray( basePath ) )
end

-- Automatically updating data structures

ModUtil.Metatables.EntangledInvertibleTable = {
	__index = function( self, key )
		return rawget( self, "Table" )[ key ]
	end,
	__newindex = function( self, key, value )
		local Table, Index = rawget( self, "Table" ), rawget( self, "Index" )
		if value ~= nil then
			local k = Index[ value ]
			if k ~= key  then
				if k ~= nil then
					Table[ k ] = nil
				end
				Index[ value ] = key
			end
		end
		if key ~= nil then
			local v = Table[ key ]
			if v ~= value then
				if v ~= nil then
					Index[ v ] = nil
				end
				Table[ key ] = value
			end
		end
	end,
	__len = function( self )
		return #rawget( self, "Table" )
	end,
	__next = function( self, key )
		return next( rawget( self, "Table" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "Table" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledInvertibleIndex = {
	__index = function( self, value )
		return rawget( self, "Index" )[ value ]
	end,
	__newindex = function( self, value, key )
		local table, index = rawget( self, "Table" ), rawget( self, "Index" )
		if value ~= nil then
			local k = index[ value ]
			if k ~= key then
				if k ~= nil then
					table[ k ] = nil
				end
				index[ value ] = key
			end
		end
		if key ~= nil then
			local v = table[ key ]
			if v ~= value then
				if v ~= nil then
					index[ v ] = nil
				end
				table[ key ] = value
			end
		end
	end,
	__len = function( self )
		return #rawget( self, "Index" )
	end,
	__next = function( self, value )
		return next( rawget( self, "Index" ), value )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "Index" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

function ModUtil.New.EntangledInvertiblePair( )
	local table, index = { }, { }
	table, index = { Table = table, Index = index }, { Table = table, Index = index }
	setmetatable( table, ModUtil.Metatables.EntangledInvertibleTable )
	setmetatable( index, ModUtil.Metatables.EntangledInvertibleIndex )
	return { Table = table, Index = index }
end

function ModUtil.New.EntangledInvertiblePairFromTable( tableArg )
	local pair = ModUtil.New.EntangledInvertiblePair( )
	for key, value in pairs( tableArg ) do
		pair.Table[ key ] = value
	end
	return pair
end

function ModUtil.New.EntangledInvertiblePairFromIndex( index )
	local pair = ModUtil.New.EntangledInvertiblePair( )
	for value, key in pairs( index ) do
		pair.Index[ value ] = key
	end
	return pair
end

ModUtil.Metatables.EntangledMap = {
	__index = function( self, key )
		return rawget( self, "Map" )[ key ]
	end,
	__newindex = function( self, key, value )
		local map = rawget( self, "Map" )
		local prevValue = map[ key ]
		map[ key ] = value
		local preImage = rawget( self, "PreImage" )
		local prevKeys
		if prevValue ~= nil then
			prevKeys = preImage[ prevValue ]
		end
		local keys = preImage[ value ]
		if not keys then
			keys = { }
			preImage[ value ] = keys
		end
		if prevKeys then
			prevKeys[ key ] = nil
		end
		keys[ key ] = true
	end,
	__len = function( self )
		return #rawget( self, "Map" )
	end,
	__next = function( self, key )
		return next( rawget( self, "Map" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "Map" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledPreImage = {
	__index = function( self, value )
		return rawget( self, "PreImage" )[ value ]
	end,
	__newindex = function( self, value, keys )
		rawget( self, "PreImage" )[ value ] = keys
		local map = rawget( self, "Map" )
		for key in pairs( map ) do
			map[ key ] = nil
		end
		for key in ipairs( keys ) do
			map[ key ] = value
		end
	end,
	__len = function( self )
		return #rawget( self, "PreImage" )
	end,
	__next = function( self, key )
		return next( rawget( self, "PreImage" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "PreImage" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

function ModUtil.New.EntangledPair( )
	local map, preImage = { }, { }
	map, preImage = { Map = map, PreImage = preImage }, { Map = map, PreImage = preImage }
	setmetatable( map, ModUtil.Metatables.EntangledMap )
	setmetatable( preImage, ModUtil.Metatables.EntangledPreImage )
	return { Map = map, PreImage = preImage }
end

function ModUtil.New.EntangledPairFromTable( tableArg )
	local pair = ModUtil.New.EntangledPair( )
	for key, value in pairs( tableArg ) do
		pair.Map[ key ] = value
	end
	return pair
end

function ModUtil.New.EntangledPairFromPreImage( preImage )
	local pair = ModUtil.New.EntangledPair( )
	for value, keys in pairs( preImage ) do
		pair.PreImage[ value ] = keys
	end
	return pair
end

ModUtil.Metatables.EntangledQueueData = {
	__index = function( self, key )
		return rawget( self, "Data" )[ key ]
	end,
	__newindex = function( self, key, value )
		local data = rawget( self, "Data" )
		local prevValue = data[ key ]
		data[ key ] = value
		local order = rawget( self, "Order" )
		local prevOrder = nil
		local prevOrderPair
		if prevValue ~= nil then
			prevOrderPair = order[ prevValue ]
			if not prevOrderPair then
				prevOrderPair = ModUtil.New.EntangledInvertiblePair( )
				order[ prevValue ] = prevOrderPair
			end
			prevOrder = prevOrderPair.Index[ key ]
		end
		local orderPair = order[ value ]
		if not orderPair then
			orderPair = ModUtil.New.EntangledInvertiblePair( )
			order[ value ] = orderPair
		end
		if prevOrder then
			table.remove( prevOrderPair.Table, prevOrder )
		end
		table.insert( orderPair.Table, key )
	end,
	__len = function( self )
		return #rawget( self, "Data" )
	end,
	__next = function( self, key )
		return next( rawget( self, "Data" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "Data" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

ModUtil.Metatables.EntangledQueueOrder = {
	__index = function( self, value )
		return rawget( self, "Order" )[ value ]
	end,
	__newindex = function( self, value, pair )
		rawget( self, "Order" )[ value ] = pair
		local data = rawget( self, "Data" )
		for _, key in pairs( data ) do
			data[ key ] = nil
		end
		for _, key in ipairs( pair.Table ) do
			data[ key ] = value
		end
	end,
	__len = function( self )
		return #rawget( self, "Order" )
	end,
	__next = function( self, key )
		return next( rawget( self, "Order" ), key )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "Order" ), idx )
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

function ModUtil.New.EntangledQueuePair( )
	local data, order = { }, { }
	data, order = { Data = data, Order = order }, { Data = data, Order = order }
	setmetatable( data, ModUtil.Metatables.EntangledQueueData )
	setmetatable( order, ModUtil.Metatables.EntangledQueueOrder )
	return { Data = data, Order = order }
end

function ModUtil.New.EntangledQueuePairFromData( data )
	local pair = ModUtil.New.EntangledQueuePair( )
	for key, value in pairs( data ) do
		pair.Data[ key ] = value
	end
	return pair
end

function ModUtil.New.EntangledQueuePairFromOrder( order )
	local pair = ModUtil.New.EntangledQueuePair( )
	for value, keys in pairs( order ) do
		pair.Order[ value ] = keys
	end
	return pair
end

-- Context Managers (EXPERIMENTAL) (WIP) (BROKEN) (INCOMPLETE)

ModUtil.Context = { }

ModUtil.Metatables.Environment = {
	__index = function( self, key )
		if key == "_G" then
			return rawget( self, "global" )
		end
		local value = rawget( self, "data" )[ key ]
		if value ~= nil then
			return value
		end
		return ( rawget( self, "fallback" ) or { } )[ key ]
	end,
	__newindex = function( self, key, value )
		rawget( self, "data" )[ key ] = value
		if key == "_G" then
			rawset( self, "global", value )
		end
	end,
	__len = function( self )
		return #rawget( self, "data" )
	end,
	__next = function( self, key )
		local out, first = { key }, true
		while out[ 2 ] == nil and ( out[ 1 ] ~= nil or first ) do
			first = false
			out = { next( rawget( self, "data" ), out[ 1 ] ) }
			if out[ 1 ] == "_G" then
				out = { "_G", rawget( self, "global" ) }
			end
		end
		return table.unpack( out )
	end,
	__inext = function( self, idx )
		local out, first = { idx }, true
		while out[ 2 ] == nil and ( out[ 1 ] ~= nil or first ) do
			first = false
			out = { inext( rawget( self, "data" ), out[ 1 ] ) }
			if out[ 1 ] == "_G" then
				out = { "_G", rawget( self, "global" ) }
			end
		end
		return table.unpack( out )
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
		local oldContextInfo = ModUtil.StackedLocals( 2 )._ContextInfo
		local contextInfo = {
			call = callContext,
			parent = oldContextInfo
		}

		contextInfo.targetIndexArray = ModUtil.PathToIndexArray( targetPath_or_targetIndexArray ) or { }
		if oldContextInfo ~= nil then
			contextInfo.indexArray = ShallowCopyTable( oldContextInfo.indexArray )
			contextInfo.baseTable = oldContextInfo.baseTable
		else
			contextInfo.indexArray = { }
			contextInfo.baseTable = _G
		end

		local callContextProcessor = rawget( self, "callContextProcessor" )
		contextInfo.callContextProcessor = callContextProcessor

		local contextData, contextArgs = callContextProcessor( contextInfo, ... )
		contextData = contextData or _G
		contextArgs = contextArgs or { }

		local _ContextInfo = contextInfo
		_ContextInfo.data = contextData
		_ContextInfo.args = contextArgs

		local callWrap = function( ... ) callContext( ... ) end
		surrogateEnvironments[ callWrap ] = contextData
		callWrap( table.unpack( contextArgs ) )
	end
}

function ModUtil.New.Context( callContextProcessor )
	local context = { callContextProcessor = callContextProcessor }
	setmetatable( context, ModUtil.Metatables.Context )
	return context
end

ModUtil.Context.Call = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	local obj = ModUtil.SafeGet( info.baseTable, info.indexArray )
	while type( obj ) == "table" do
		local meta = getmetatable( obj )
		if meta then
			if meta.__call then
				table.insert( info.indexArray, ModUtil.Nodes.Table.Metatable )
				table.insert( info.indexArray, "__call" )
				obj = meta.__call
			end
		end
	end
	local env = { data = ModUtil.NewTable( obj, ModUtil.Nodes.Table.Environment ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Meta = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	local parent = ModUtil.SafeGet( info.baseTable, info.indexArray )
	if parent == nil then
		parent = { }
		ModUtil.SafeSet( info.baseTable, info.indexArray, parent )
	end
	local env = { data = ModUtil.NewTable( parent, ModUtil.Nodes.Table.Metatable ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Data = ModUtil.New.Context( function( info )
	info.indexArray = ModUtil.JoinIndexArrays( info.indexArray, info.targetIndexArray )
	local tempArray = ShallowCopyTable( info.indexArray )
	local key = table.remove( tempArray )
	local parent = ModUtil.SafeGet( info.baseTable, tempArray )
	if parent == nil then
		parent = { }
		ModUtil.SafeSet( info.baseTable, tempArray, parent )
	end
	local env = { data = ModUtil.NewTable( parent, key ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

-- Special traversal nodes (EXPERIMENTAL) (WIP) (INCOMPLETE)

ModUtil.Nodes = ModUtil.New.EntangledInvertiblePair( )

ModUtil.Nodes.Table.Metatable = {
	New = function( obj )
		local meta = getmetatable( obj )
		if meta == nil then
			meta = { }
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

ModUtil.Nodes.Table.Environment = {
	New = function( obj )
		local env = surrogateEnvironments[ obj ]
		if env == nil or getmetatable( env ) ~= ModUtil.Metatables.Environment then
			env = { }
			env.data = env.data or { }
			env.fallback = _G
			env.global = env
			setmetatable( env, ModUtil.Metatables.Environment )
			surrogateEnvironments[ obj ] = env
		end
		return env
	end,
	Get = function( obj )
		return surrogateEnvironments[ obj ]
	end,
	Set = function( obj, value )
		surrogateEnvironments[ obj ] = value
		return true
	end
}

-- Identifier system (EXPERIMENTAL)

ModUtil.Identifiers = ModUtil.New.EntangledInvertiblePair( )
ModUtil.Identifiers.Index._G = _G
ModUtil.Identifiers.Index.ModUtil = ModUtil

ModUtil.Mods = ModUtil.New.EntangledInvertiblePair( )
ModUtil.Mods.Table.ModUtil = ModUtil

-- Mods tracking (EXPERIMENTAL) (WIP) (UNTESTED) (INCOMPLETE)

--[[
	Users should only ever opt-in to running this function
]]
function ModUtil.EnableModHistory( )
	if not ModHistory then
		ModHistory = { }
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores[ "ModHistory" ] = nil
	end
end

function ModUtil.DisableModHistory( )
	if not ModHistory then
		ModHistory = { }
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores[ "ModHistory" ] = nil
	end
end

function ModUtil.UpdateModHistoryEntry( options )
	if options.Override then
		ModUtil.EnableModHistory( )
	end
	if ModHistory then
		local mod = options.Mod
		local path = options.Path
		if mod == nil then
			mod = ModUtil.Mods.Table[ path ]
		end
		if path == nil then
			path = ModUtil.Mods.Index[ mod ]
		end
		local entry = ModHistory[ path ]
		if entry == nil then
			entry = { }
			ModHistory[ path ] = entry
		end
		if options.Version then
			entry.Version = options.Version
		end
		if options.FirstTime or options.All then
			if not entry.FirstTime then
				entry.FirstTime = os.time( )
			end
		end
		if options.LastTime or options.All then
			entry.LastTime = os.time( )
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
		options = { }
	end
	for path, mod in pairs( ModUtil.Mods.Table ) do
		options.Path, options.Mod = path, mod
		ModUtil.UpdateModHistoryEntry( options )
	end
end

-- Wrap/Overrides within functions (EXPERIMENTAL) (LIKELY DEPRECATED)

ModUtil.Internal.PerFunctionEnv = { }

--[[
	Create a new table whose getters and setters will default to the given
	baseTable, except in cases where values are setOverride into the overrideTable.
	This allows pinpoint overriding of values in the override table, while allowing
	all other accesses to continue to operate as if they were operating on baseTable.
	The overrides are stored in the _Overrides subtable. For example:
	_Overrides = {
		CurrentRun = {
			CurrentRoom = {
				_IsModUtilOverride = true,
				_Value = {
					Name = "RoomSimple01",
					...
				}
			}
		}
	}
	would be the result of overriding "CurrentRun.CurrentRoom" with a table represnting a room.
	Any accesses that happen above the override point (ie. reads/writes to CurrentRun) are
	reed to the base table. Any accesses that happen at or below the override point (ie.
	reads / writes to CurrentRun.CurrentRoom or CurrentRun.CurrentRoom.Name) are intercepted
	and apply to the overridden value instead.
	baseTable	- the table to access for entries not specifically overridden
]]
local function makeOverrideTable( baseTable, overrides )
	local overrideTable = {
		_IsModUtilOverrideTable = true,
		_Overrides = overrides or { },
		_BaseTable = baseTable
	}
	setmetatable( overrideTable, ModUtil.Metatables.OverrideTable )
	return overrideTable
end

ModUtil.Metatables.OverrideTable = {
	__index = function( self, name )
		local baseResult = self._BaseTable[ name ]
		local overridesResult = self._Overrides[ name ]
		if overridesResult == nil then
			return baseResult
		elseif overridesResult._IsModUtilOverride then
			return overridesResult._Value
		elseif type( baseResult ) == "table" then
			return makeOverrideTable( baseResult, overridesResult )
		else
			return makeOverrideTable( { }, overridesResult )
		end
	end,
	 __newindex = function( self, name, value )
		 local currentOverride = self._Overrides[ name ]
		 if currentOverride == nil then
			 self._BaseTable[ name ] = value
		 elseif currentOverride._IsModUtilOverride then
			 currentOverride._Value = value
		 else
			 self._BaseTable[ name ] = value
		 end
	 end
}

--[[
	Override the entry at indexArray in table with value.
	table	- the table whose entry should be overridden
		must come from a previous call to makeOverrideTable( )
	indexArray	- the list of indexes
	value	- the value to override
]]
local function setOverride( table, indexArray, value )
	if type( table ) ~= "table" or not table._IsModUtilOverrideTable then return end
	ModUtil.SafeSet( table._Overrides, indexArray, { _IsModUtilOverride = true, _Value = value } )
end

--[[
	Remove the override entry at indexArray in table.
	No effect if the indexArray does not identify an override point.
	table	- the table whose override should be removed
	indexArray	- the list of indexes
]]
local function removeOverride( table, indexArray )
	if type( table ) ~= "table" or not table._IsModUtilOverrideTable then return end
	local currentOverride = ModUtil.SafeGet( table._Overrides, indexArray )
	if currentOverride ~= nil and currentOverride._IsModUtilOverride then
		ModUtil.SafeSet( table._Overrides, indexArray, nil )
	end
end

--[[
	Check whether there is an override for indexArray in table.
	Only returns true for exact matches. For example, if you override CurrentRun in table T,
	hasOverride( T, { "CurrentRun", "CurrentRoom" } ) will return false.
	table	- the table to check for an override
	indexArray	- the list of indexes
]]
local function hasOverride( table, indexArray )
	if type( table ) ~= "table" or not table._IsModUtilOverrideTable then return false end
	local value = ModUtil.SafeGet( table._Overrides, indexArray )
	return value ~= nil and value._IsModUtilOverride
end

--[[
	Gets the function's local (partially-overriden) environment, or
	create a new one and attach it to the function if not yet present.
	baseTable	- the base table, on which to base the function's environment
	indexArray	- the list of indexes
]]
local function getFunctionEnv( baseTable, indexArray )
	local func = getBaseValueForWraps( baseTable, indexArray )
	if type( func ) ~= "function" then return nil end

	ModUtil.NewTable( ModUtil.Internal.PerFunctionEnv, baseTable )
	local env = ModUtil.SafeGet( ModUtil.Internal.PerFunctionEnv[ baseTable ], indexArray )
	if not env then
		env = makeOverrideTable( baseTable )
		ModUtil.SafeSet( ModUtil.Internal.PerFunctionEnv[ baseTable ], indexArray, env )
		setfenv( func, env )
	end
	return env
end

--[[
	Overrides the value at envIndexArray within the function referred to by
	indexArray in baseTable, by replacing it with value.
	Accesses to the value at envIndexArray from within other functions are
	unaffected.
	Generally, you should use ModUtil.BaseOverrideWithinFunction for a more
	modder-friendly interface.
	For example, after you do
		ModUtil.OverrideWithinFunction( _G, { "CreateRoom" }, { "CurrentRun.CurrentRoom" }, <room object> )
	1. Any reads to CurrentRun.CurrentRoom from CreateRoom will return <room object>
	2. Any writes to CurrentRun.CurrentRoom from CreateRoom will replace <room object>, which will
		with the new value, which will be returned for subsequent accesses to CurrentRun.CurrentRoom.
	3. Any writes to CurrentRun.CurrentRoom from CreateRoom will not be visible from other functions.
	4. If CreateRoom performs writes within <room object> (eg. CurrentRun.CurrentRoom.Name = "foo")
		 these will be visible to <room object> from any function that has access to it. If you want
		 full isolation, make sure you pass in an object that nobody else has a reference to, eg. by
		 creating one fresh or making a copy).
	baseTable	- the base table for function and environment lookups (usually _G)
	indexArray	- the list of indices identifying the function whose environment is to be overridden
	envIndexArray	- the list of indices identifying the value to be overridden in the function's environment
	value	- the value with which to override
]]
function ModUtil.OverrideWithinFunction( baseTable, indexArray, envIndexArray, value )
	if not baseTable then return end
	local env = getFunctionEnv( baseTable, indexArray )

	if not env then return end
	if hasOverride( env, envIndexArray ) then
		-- we might have wraps to reapply
		local overrideEnvIndexArray = DeepCopyTable( envIndexArray )
		table.insert( overrideEnvIndexArray, "_Value" )
		if not setBaseValueForWraps( env._Overrides, overrideEnvIndexArray, value ) then
			setOverride( env, envIndexArray, value )
		end
	else
		setOverride( env, envIndexArray, value )
	end
end

--[[
	Remove the override at envIndexArray for the function at indexArray in baseTable,
	so that reads and writes to envIndexArray have their usual effects on the base environment.
	baseTable	- the base table for function and environment lookups (usually _G)
	indexArray	- the list of indices identifying the function whose environment is to be overridden
	envIndexArray	- the list of indices identifying the value to be overridden in the function's environment
]]
function ModUtil.RestoreWithinFunction( baseTable, indexArray, envIndexArray )
	if not baseTable then return end

	local env = getFunctionEnv( baseTable, indexArray )
	if not env then return end

	removeOverride( env, envIndexArray )
end


--[[
	Wrap a function, so that you can insert code that runs before/after that function whenever
	it's called from within a particular other function, and modify the return value if needed.
	Generally, you should use ModUtil.WrapBaseWithinFunction for a more modder-friendly interface.
	baseTable	- the base table for function and environment lookups (usually _G)
	indexArray	- the list of indices identifying the function within with the wrap will apply
	envIndexArray	- the list of indices identifying the function whose calls will be wrapped
	wrapFunc	- the wrapping function
	mod	- (optional) the mod performing the wrapping, for debug purposes
]]
function ModUtil.WrapWithinFunction( baseTable, indexArray, envIndexArray, wrapFunc, mod )
	if type( wrapFunc ) ~= "function" then return end
	if not baseTable then return end
	local env = getFunctionEnv( baseTable, indexArray )
	if not env then return end

	if not hasOverride( env, envIndexArray ) then
		-- Resolve the entry in baseTable at call time (not now),
		-- in case further wraps or overrides are applied to it.
		setOverride(
			env,
			envIndexArray,
			function( ... )
				local resolvedFunc = ModUtil.SafeGet( ModUtil.Experimental.SkipEnvironment( baseTable ), envIndexArray )
				return resolvedFunc( ... )
			end
		)
	end

	ModUtil.WrapFunction( env, envIndexArray, wrapFunc, mod )
end

--[[
	Override the global value at the given path, when accessed from
	within the global function at funcPath.
	If the Value is a function, preserves the wraps
	applied with ModUtil.WrapBaseWithinFunction et. al.
	basePath	- the path to override, as a string
	envPath	- the path to override, as a string
	value	- the new value to store at the path
]]
function ModUtil.BaseOverrideWithinFunction( funcPath, basePath, value )
	local indexArray = ModUtil.PathArray( funcPath )
	local envIndexArray = ModUtil.PathArray( basePath )
	ModUtil.OverrideWithinFunction( _G, indexArray, envIndexArray, value )
end

--[[
	Wraps the function with the path given by baseFuncPath, when it is called from
	the function given by funcPath.
	This lets you insert code within a function, without affecting other functions
	that might make similar calls.
	For example, to insert code to display a "cancel" at the point in "CreateBoonLootButtons"
	where it calls IsMetaUpgradeSelected( "RerollPanelMetaUpgrade" ), do:
	ModUtil.WrapBaseWithinFunction( "CreateBoonLootButtons", "IsMetaUpgradeSelected", function( baseFunc, name )
		if name == "RerollPanelMetaUpgrade" and CalcNumLootChoices( ) == 0 then
			< code to display the cancel button >
			return false
		else
			return baseFunc( name )
		end
	end, YourMod )
	This provides better compatibility between mods that just wrapping IsMetaUpgradeSelected, because
	you new code only executes when within CreateBoonLootButtons, so there are less chances for collisions
	and side effects.
	It also provides better compatibility than using BaseOverride on "CreateBoonLootButtons", since only one
	override for a function can be active at a time, but multiple wraps can be active.
	funcPath	- the (global) path to the function within which the wrap will apply, as a string
		for most SGG-provided functions, this is just the function's name
		eg. "CreateRoomReward" or "SetTraitsOnLoot"
	baseFuncPath	- the (global) path to the function to wrap, as a string
		for most SGG-provided functions, this is just the function's name
		eg. "CreateRoomReward" or "SetTraitsOnLoot"
	wrapFunc	- the function to wrap around the base function
		this function receives the base function as its first parameter.
		all subsequent parameters should be the same as the base function
	mod	- (optional) the object for your mod, for debug purposes
]]
function ModUtil.WrapBaseWithinFunction( funcPath, baseFuncPath, wrapFunc, mod )
	local indexArray = ModUtil.PathArray( funcPath )
	local envIndexArray = ModUtil.PathArray( baseFuncPath )
	ModUtil.WrapWithinFunction( _G, indexArray, envIndexArray, wrapFunc, mod )
end

-- Final Processing
ModUtil.ReplaceGlobalEnvironment( )