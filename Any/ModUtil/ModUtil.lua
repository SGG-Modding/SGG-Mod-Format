--[[
Mod: Mod Utility
Author: MagicGonads

	Library to allow mods to be more compatible with eachother and expand capabilities.
	Use the mod importer to import this mod to ensure it is loaded in the right position.

]]

ModUtil = {

	Mod = { },
	Print = { },
	ToString = { },
	String = { },
	Table = { },
	Path = { },
	IndexArray = { },
	UpValues = { },
	Locals = { },
	Internal = { },
	Metatables = { },
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
		rawpairs, rawipairs, qrawpairs, qrawipairs, type, tostring, xpcall
	=
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, type, tostring, xpcall

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

do
	local getinfo = debug.getinfo

	local function getenv( )
		local level = 3
		repeat
			level = level + 1
			local info = getinfo( level, "f" )
			if info then
				local env = rawget( surrogateEnvironments, rawget( info, "func" ) )
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
	local split = function( path )
		if type( path ) == "string"
		and path:find("[.]")
		and not path:find("[.][.]+")
		and not path:find("^[.]")
		and not path:find("[.]$") then
			return ModUtil.Path.IndexArray( path )
		end
		return { path }
	end
	local get = ModUtil.IndexArray.Get
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

-- Management

--[[
	Create a namespace that can be used for the mod's functions
	and data, and ensure that it doesn't end up in save files.

	modName - the name of the mod
	parent	- the parent mod, or nil if this mod stands alone
]]
function ModUtil.Mod.Register( modName, parent, content )
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
		ModUtil.Table.SetMap( parent[ modName ], content )
	end
	return parent[ modName ]
end

--[[
	Tell each screen anchor that they have been forced closed by the game
]]
function ModUtil.Internal.ForceClosed( triggerArgs )
	for _, v in pairs( ModUtil.Anchors.CloseFuncs ) do
		v( nil, nil, triggerArgs )
	end
	ModUtil.Anchors.CloseFuncs = { }
	ModUtil.Anchors.Menu = { }
end
OnAnyLoad{ function( triggerArgs ) ModUtil.Internal.ForceClosed( triggerArgs ) end }

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

local passByValueTypes = ToLookup{ "number", "boolean", "nil" }
local excludedFieldNames = ToLookup{ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" }

function ModUtil.ToString.Value( o )
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

function ModUtil.ToString.Key( o )
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

function ModUtil.ToString.TableKeys( o )
	if type( o ) == 'table' then
		local out = { }
		for k in pairs( o ) do
			table.insert( out , ModUtil.ToString.Key( k ) )
			table.insert( out , ', ' )
		end
		table.remove( out )
		return table.concat( out )
	end
end

function ModUtil.ToString.Shallow( o )
	if type( o ) == "table" then
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.ToString.Key( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ToString.Value( v ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ToString.Value( o )
	end
end

function ModUtil.ToString.Deep( o, seen )
	seen = seen or { }
	if type( o ) == "table" and not seen[ o ] then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.ToString.Key( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ToString.Deep( v, seen ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ToString.Value( o )
	end
end

function ModUtil.ToString.DeepNoNamespaces( o, seen )
	local first = false
	if not seen then
		first = true
		seen = { }
	end
	if type( o ) == "table" and not seen[ o ] and o ~= __G._G and ( first or not ModUtil.Mods.Index[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			if v ~= __G._G and not ModUtil.Mods.Index[ v ] then
				table.insert( out, ModUtil.ToString.Key( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToString.DeepNoNamespaces( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ToString.Value( o )
	end
end

function ModUtil.ToString.DeepNamespaces( o, seen )
	local first = false
	if not seen then
		first = true
		seen = { }
	end
	if type( o ) == "table" and not seen[ o ] and ( first or o == __G._G or ModUtil.Mods.Index[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			if v == __G._G or ModUtil.Mods.Index[ v ] then
				table.insert( out, ModUtil.ToString.Key( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToString.DeepNamespaces( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " }"
	else
		return ModUtil.ToString.Value( o )
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

function ModUtil.String.Join( sep, ... )
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

function ModUtil.String.Chunk( text, chunkSize, maxChunks )
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

function ModUtil.Table.Replace( target, data )
	for k in pairs( target ) do
		target[ k ] = data[ k ]
	end
	for k, v in pairs( data ) do
		target[ k ] = v
	end
end

function ModUtil.Table.IsUnKeyed( tableArg )
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

-- Print

setmetatable( ModUtil.Print, {
	__call = function ( _, ... )
		print( ... )
		if DebugPrint then ModUtil.Print.Debug( ... ) end
		if io then
			if io.stdout ~= io.output( ) then
				ModUtil.Print.ToFile( io.output( ), ... )
			end
			io.flush( )
		end
	end
})

function ModUtil.Print.ToFile( file, ... )
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

function ModUtil.Print.Debug( ... )
	local text = ModUtil.String.Join( "\t", ModUtil.MapVars( tostring, ... ) ):gsub( "\t", "    " )
	for line in text:gmatch( "([^\n]+)" ) do
		DebugPrint{ Text = line }
	end
end

function ModUtil.Print.Traceback( level )
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

function ModUtil.Print.DebugInfo( level )
	level = ( level or 1 )
	local text
	text = ModUtil.ToString.Deep( debug.getinfo( level + 1 ) )
	ModUtil.Print( "Debug Info:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
end

function ModUtil.Print.Namespaces( level )
	level = ( level or 1 )
	local text
	ModUtil.Print("Namespaces:")
	text = ModUtil.ToString.DeepNamespaces( ModUtil.Local( level + 1 ) )
	ModUtil.Print( "\t" .. "Local:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNamespaces( ModUtil.UpValue( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	local func = debug.getinfo( level + 1, "f" ).func
	text = ModUtil.ToString.DeepNamespaces( surrogateEnvironments[ func ] )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text )
end

function ModUtil.Print.Variables( level )
	level = ( level or 1 )
	local text
	ModUtil.Print("Variables:")
	text = ModUtil.ToString.DeepNoNamespaces( ModUtil.Local( level + 1 ) )
	ModUtil.Print( "\t" .. "Local:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNoNamespaces( ModUtil.UpValue( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	local func = debug.getinfo( level + 1, "f" ).func
	text = ModUtil.ToString.DeepNoNamespaces( surrogateEnvironments[ func ] )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text )
end

--[[
	Call a function with the provided arguments
	instead of halting when an error occurs it prints the entire error traceback
]]
function ModUtil.DebugCall( f, ... )
	return xpcall( f, function( err )
		ModUtil.Print( err )
		ModUtil.Print.DebugInfo( 2 )
		ModUtil.Print.Namespaces( 2 )
		ModUtil.Print.Variables( 2 )
		ModUtil.Print.Traceback( 2 )
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

--[[
	Safely create a new empty table at Table.key and return it.

	Table - the table to modify
	key	 - the key at which to store the new empty table
]]
function ModUtil.Table.New( tableArg, key )
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
function ModUtil.IndexArray.Get( baseTable, indexArray )
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
function ModUtil.IndexArray.Set( baseTable, indexArray, value )
	if next( indexArray ) == nil then
		return false -- can't set the input argument
	end
	local n = #indexArray -- change to shallow copy + table.remove later
	local node = baseTable
	for i = 1, n - 1 do
		local key = indexArray[ i ]
		if not ModUtil.Table.New( node, key ) then return false end
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
function ModUtil.Table.NilMap( inTable, nilTable )
	for nilKey, nilVal in pairs( nilTable ) do
		local inVal = inTable[ nilKey ]
		if type( nilVal ) == "table" and type( inVal ) == "table" then
			ModUtil.Table.NilMap( inVal, nilVal )
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
function ModUtil.Table.SetMap( inTable, setTable )
	for setKey, setVal in pairs( setTable ) do
		local inVal = inTable[ setKey ]
		if type( setVal ) == "table" and type( inVal ) == "table" then
			ModUtil.Table.SetMap( inVal, setVal )
		else
			inTable[ setKey ] = setVal
		end
	end
end

function ModUtil.IndexArray.Map( baseTable, indexArray, map, ... )
	ModUtil.IndexAray.Set( baseTable, indexArray, map( ModUtil.IndexArray.Get( baseTable, indexArray ), ... ) )
end

--[[
	Concatenates two index arrays, in order.

	a, b - the index arrays
]]
function ModUtil.IndexArray.Join( a, b )
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

-- Path Manipulation

function ModUtil.Path.Map( path, map, ... )
	local indexArray = ModUtil.Path.IndexArray( path )
	ModUtil.IndexAray.Set( _G, indexArray, map( ModUtil.IndexArray.Get( _G, indexArray ), ... ) )
end

function ModUtil.Path.Join( a, b )
	if a == '' then return b end
	if b == '' then return a end
	return a .. '.' .. b
end

--[[
	Create an index array from the provided Path.

	The returned array can be used as an argument to the safe table
	manipulation functions, such as ModUtil.IndexArray.Set and ModUtil.IndexArray.Get.

	path - a dot-separated string that represents a path into a table
]]
function ModUtil.Path.IndexArray( path )
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

	For example, ModUtil.Path.Get( "a.b.c" ) returns a.b.c.
	If either a or a.b is nil, nil is returned instead.

	path - the path to get the value
	base - (optional) The table to retreive the value from.
				 If not provided, retreive a global.
]]
function ModUtil.Path.Get( path, base )
	return ModUtil.IndexArray.Get( base or _G, ModUtil.Path.IndexArray( path ) )
end

--[[
	Safely get set a value to a Path.

	For example, ModUtil.Path.Set( "a.b.c", 1 ) sets a.b.c = 1.
	If either a or a.b is nil, they are created.

	path - the path to get the value
	base - (optional) The table to retreive the value from.
				 If not provided, retreive a global.
]]
function ModUtil.Path.Set( path, value, base )
	return ModUtil.IndexArray.Set( base or _G, ModUtil.Path.IndexArray( path ), value )
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

ModUtil.Metatables.UpValues = {
	__index = function( self, name )
		if excludedUpValueNames[ name ] then return end
		local func = rawget( self, "func" )
		local idx = 0
		repeat
			idx = idx + 1
			local n, value = debug.getupvalue( func, idx )
			if n == name then
				return n, value
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

setmetatable( ModUtil.UpValues, {
	__call = function( func )
		if type(func) ~= "function" then
			func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
		end
		local upValues = { func = func }
		setmetatable( upValues, ModUtil.Metatables.UpValues )
		return upValues
	end
})

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

ModUtil.Metatables.UpValues.Ids = {
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
ModUtil.Metatables.UpValues.Ids.__inext = ModUtil.Metatables.UpValues.Ids.__next
ModUtil.Metatables.UpValues.Ids.__ipairs = ModUtil.Metatables.UpValues.Ids.__pairs

function ModUtil.UpValues.Ids( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValues.Ids )
	return ups
end

ModUtil.Metatables.UpValues.Values = {
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
	__pairs = ModUtil.Metatables.UpValues.Ids.__pairs,
	__ipairs = ModUtil.Metatables.UpValues.Ids.__ipairs
}
ModUtil.Metatables.UpValues.Values.__inext = ModUtil.Metatables.UpValues.Values.__next

function ModUtil.UpValues.Values( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValues.Values )
	return ups
end

ModUtil.Metatables.UpValues.Names = {
	__index = function( self, idx )
		local name = debug.getupvalue( rawget( self, "func" ), idx )
		if name and not excludedUpValueNames[ name ] then
			return name
		end
	end,
	__newindex = function( ) end,
	__len = ModUtil.Metatables.UpValues.Values.__len,
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
	__pairs = ModUtil.Metatables.UpValues.Ids.__pairs,
	__ipairs = ModUtil.Metatables.UpValues.Ids.__ipairs
}
ModUtil.Metatables.UpValues.Names.__inext = ModUtil.Metatables.UpValues.Names.__next

function ModUtil.UpValues.Names( func )
	if type(func) ~= "function" then
		func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
	end
	local ups = { func = func }
	setmetatable( ups, ModUtil.Metatables.UpValues.Names )
	return ups
end

ModUtil.Metatables.UpValues.Stacked = {
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

function ModUtil.UpValues.Stacked( level )
	local upValues = { levels = ModUtil.StackLevels( ( level or 1 ) ) }
	setmetatable( upValues, ModUtil.Metatables.UpValues.Stacked )
	return upValues
end

local excludedLocalNames = ToLookup{ "(*temporary)", "(for generator)", "(for state)", "(for control)" }

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

setmetatable( ModUtil.Locals, {
	__call = function( level )
		local locals = { level = ModUtil.StackLevel( ( level or 1 ) + 1 ) }
		setmetatable( locals, ModUtil.Metatables.Locals )
		return locals
	end
} )

ModUtil.Metatables.Locals.Values = {
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
ModUtil.Metatables.Locals.Values.__ipairs = ModUtil.Metatables.Locals.Values.__pairs
ModUtil.Metatables.Locals.Values.__inext = ModUtil.Metatables.Locals.Values.__next

--[[
	Example Use:
	for i, name, value in pairs( ModUtil.Locals.Values( level ) ) do
		--
	end
]]
function ModUtil.Locals.Values( level )
	if level == nil then level = 1 end
	local locals = { level = ModUtil.StackLevel( level + 1 ) }
	setmetatable( locals, ModUtil.Metatables.Locals.Values )
	return locals
end

ModUtil.Metatables.Locals.Names = {
	__index = function( self, idx )
		local name = rawget( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return name
			end
		end
	end,
	__newindex = function( ) return end,
	__len = ModUtil.Metatables.Locals.Values.__len,
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
ModUtil.Metatables.Locals.Names.__ipairs = ModUtil.Metatables.Locals.Names.__pairs
ModUtil.Metatables.Locals.Names.__inext = ModUtil.Metatables.Locals.Names.__next

--[[
	Example Use:
	for i, name, value in pairs( ModUtil.Locals.Names( level ) ) do
		--
	end
]]
function ModUtil.Locals.Names( level )
	if level == nil then level = 1 end
	local locals = { level = ModUtil.StackLevel( level + 1 ) }
	setmetatable( locals, ModUtil.Metatables.Locals.Names )
	return locals
end

ModUtil.Metatables.Locals.Stacked = {
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
	you could access its 'local screen' as ModUtil.Locals.Stacked().screen
	and its 'local hasRequirement' as ModUtil.Locals.Stacked().hasRequirement.
]]
function ModUtil.Locals.Stacked( level )
	local locals = { levels = ModUtil.StackLevels( ( level or 1 ) ) }
	setmetatable( locals, ModUtil.Metatables.Locals.Stacked )
	return locals
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

function ModUtil.EntangledInvertiblePair( )
	local table, index = { }, { }
	table, index = { Table = table, Index = index }, { Table = table, Index = index }
	setmetatable( table, ModUtil.Metatables.EntangledInvertibleTable )
	setmetatable( index, ModUtil.Metatables.EntangledInvertibleIndex )
	return { Table = table, Index = index }
end

function ModUtil.EntangledInvertiblePairFromTable( tableArg )
	local pair = ModUtil.EntangledInvertiblePair( )
	for key, value in pairs( tableArg ) do
		pair.Table[ key ] = value
	end
	return pair
end

function ModUtil.EntangledInvertiblePairFromIndex( index )
	local pair = ModUtil.EntangledInvertiblePair( )
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

function ModUtil.EntangledPair( )
	local map, preImage = { }, { }
	map, preImage = { Map = map, PreImage = preImage }, { Map = map, PreImage = preImage }
	setmetatable( map, ModUtil.Metatables.EntangledMap )
	setmetatable( preImage, ModUtil.Metatables.EntangledPreImage )
	return { Map = map, PreImage = preImage }
end

function ModUtil.EntangledPairFromTable( tableArg )
	local pair = ModUtil.EntangledPair( )
	for key, value in pairs( tableArg ) do
		pair.Map[ key ] = value
	end
	return pair
end

function ModUtil.EntangledPairFromPreImage( preImage )
	local pair = ModUtil.EntangledPair( )
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
				prevOrderPair = ModUtil.EntangledInvertiblePair( )
				order[ prevValue ] = prevOrderPair
			end
			prevOrder = prevOrderPair.Index[ key ]
		end
		local orderPair = order[ value ]
		if not orderPair then
			orderPair = ModUtil.EntangledInvertiblePair( )
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

function ModUtil.EntangledQueuePair( )
	local data, order = { }, { }
	data, order = { Data = data, Order = order }, { Data = data, Order = order }
	setmetatable( data, ModUtil.Metatables.EntangledQueueData )
	setmetatable( order, ModUtil.Metatables.EntangledQueueOrder )
	return { Data = data, Order = order }
end

function ModUtil.EntangledQueuePairFromData( data )
	local pair = ModUtil.EntangledQueuePair( )
	for key, value in pairs( data ) do
		pair.Data[ key ] = value
	end
	return pair
end

function ModUtil.EntangledQueuePairFromOrder( order )
	local pair = ModUtil.EntangledQueuePair( )
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
	__call = function( self, callContext, ... )
		local oldContextInfo = ModUtil.Locals.Stacked( 2 )._ContextInfo
		local contextInfo = {
			call = callContext,
			parent = oldContextInfo
		}

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

setmetatable( ModUtil.Context, {
	__call = function( callContextProcessor )
		local context = { callContextProcessor = callContextProcessor }
		setmetatable( context, ModUtil.Metatables.Context )
		return context
	end
} )

ModUtil.Context.Data = ModUtil.Context( function( info )
	local env = { data = info.args[ 1 ], fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Meta = ModUtil.Context( function( info )
	local env = { data = ModUtil.Nodes.Table.Metatable.New( info.args[ 1 ] ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Call = ModUtil.Context( function( info )
	local env = { data = ModUtil.Nodes.Table.Environment.New( ModUtil.Nodes.Table.Call.Get( info.args[ 1 ] ) ), fallback = _G }
	env.global = env
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

-- Special traversal nodes (EXPERIMENTAL) (WIP) (INCOMPLETE)

ModUtil.Nodes = ModUtil.EntangledInvertiblePair( )

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
		if env == nil then
			env = { }
			env.data = { }
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

ModUtil.Nodes.Table.Call = {
	New = function( obj )
		local call
		while type( obj ) == "table" do
			local meta = getmetatable( obj )
			if meta then
				call = meta.__call
				if call then
					obj = call
				end
			end
		end
		return call or error( "node new rejected, new call nodes are not meaningfully mutable.", 2 )
	end,
	Get = function( obj )
		while type( obj ) == "table" do
			local meta = getmetatable( obj )
			if meta then
				if meta.__call then
					obj = meta.__call
				end
			end
		end
		return obj
	end,
	Set = function( obj, value )
		local meta
		while type( obj ) == "table" do
			meta = getmetatable( obj )
			if meta then
				if meta.__call then
					obj = meta.__call
				end
			end
		end
		if not meta then return false end
		meta.__call = value
		return true
	end
}

ModUtil.Nodes.Table.UpValues = {
	New = function( obj )
		return ModUtil.UpValues( obj )
	end,
	Get = function( obj )
		return ModUtil.UpValues( obj )
	end,
	Set = function( )
		error( "node set rejected, upvalues node cannot be set.", 2 )
	end
}

-- Identifier system (EXPERIMENTAL)

ModUtil.Identifiers = ModUtil.EntangledInvertiblePair( )
setmetatable( rawget( ModUtil.Identifiers.Table, "Index" ), { __mode = "k" } )
setmetatable( rawget( ModUtil.Identifiers.Index, "Table" ), { __mode = "v" } )

ModUtil.Identifiers.Index._G = _G
ModUtil.Identifiers.Index.ModUtil = ModUtil

ModUtil.Mods = ModUtil.EntangledInvertiblePair( )
setmetatable( rawget( ModUtil.Mods.Table, "Index" ), { __mode = "k" } )
setmetatable( rawget( ModUtil.Mods.Index, "Table" ), { __mode = "v" } )
ModUtil.Mods.Table.ModUtil = ModUtil

-- Mods tracking (EXPERIMENTAL) (WIP) (UNTESTED) (INCOMPLETE)

ModUtil.Mod.History = { }

--[[
	Users should only ever opt-in to running this function
]]
function ModUtil.Mod.History.Enable( )
	if not ModHistory then
		ModHistory = { }
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores[ "ModHistory" ] = nil
	end
end

function ModUtil.Mod.History.Disable( )
	if not ModHistory then
		ModHistory = nil
		if PersistVariable then PersistVariable{ Name = "ModHistory" } end
		SaveIgnores[ "ModHistory" ] = nil
	end
end

function ModUtil.Mod.History.UpdateEntry( options )
	if options.Override then
		ModUtil.Mod.History.Enable( )
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

function ModUtil.Mod.History.Populate( options )
	if not options then
		options = { }
	end
	for path, mod in pairs( ModUtil.Mods.Table ) do
		options.Path, options.Mod = path, mod
		ModUtil.Mod.History.UpdateEntry( options )
	end
end

-- Function Wrapping

ModUtil.Internal.WrapCallbacks = { }
setmetatable( ModUtil.Internal.WrapCallbacks, { __mode = "k" } )

function ModUtil.Wrap( base, wrap, mod )
	local obj = { Base = base, Wrap = wrap, Mod = mod }
	local func = function( ... ) return wrap( base, ... ) end
	ModUtil.Internal.WrapCallbacks[ func ] = obj
	return func
end

function ModUtil.Unwrap( obj )
	local callback = ModUtil.Internal.WrapCallbacks[ obj ]
	return callback and callback.Base or obj
end

function ModUtil.Rewrap( obj )
	local node = ModUtil.Internal.WrapCallbacks[ obj ]
	if not node then return ModUtil.OverridenValue( obj ) end
	return ModUtil.Wrap( ModUtil.Rewrap( node.Base ), node.Wrap, node.Mod )
end

-- Overrides

ModUtil.Internal.Overrides = { }

function ModUtil.Override( base, value, mod )
    local obj = { Base = ModUtil.OriginalValue( base ), Mod = mod }
    ModUtil.Internal.Overrides[ value ] = obj
    return ModUtil.Rewrap( value )
end

-- Override and Wrap interaction

function ModUtil.OverridenValue( obj )
	local node = ModUtil.Internal.WrapCallbacks[ obj ]
	if not node then return obj end
	return ModUtil.OriginalValue( node.Base )
end

function ModUtil.OriginalValue( obj )
	local node = ModUtil.Internal.WrapCallbacks[ obj ] or ModUtil.Internal.Overrides[ obj ]
	if not node then return obj end
	return ModUtil.OriginalValue( node.Base )
end