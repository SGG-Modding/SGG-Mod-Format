--[[
Mod: Mod Utility
Author: MagicGonads

	Library to allow mods to be more compatible with eachother and expand capabilities.
	Use the mod importer to import this mod to ensure it is loaded in the right position.

--]]
ModUtil = {

	Mod = { },
	Print = { },
	ToString = { },
	String = { },
	Table = { },
	Path = { },
	Array = { },
	IndexArray = { },
	UpValues = { },
	Locals = { },
	Entangled = { },
	Internal = { },
	Metatables = { },
	Anchors = {
		Menu = { },
		CloseFuncs = { }
	}

}

-- Extended Global Utilities (assuming lua 5.2)

local error, pcall, xpcall = error, pcall, xpcall

local debug, type, table = debug, type, table
local function getname( )
	return debug.getinfo( 2, "n" ).name
end

-- doesn't invoke __index
rawnext = next
local rawnext = rawnext

local function pusherror( f, ... )
	local ret = table.pack( pcall( f, ... ) )
	if ret[ 1 ] then return table.unpack( ret, 2, ret.n ) end
	error( ret[ 2 ], 3 )
end

-- invokes __next
function next( t, k )
	local m = debug.getmetatable( t )
	local f = m and m.__next or rawnext
	return pusherror( f, t, k )
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

	if type( t ) ~= "table" then
		error( "bad argument #1 to '" .. getname( ) .. "'(table expected got " .. type( i ) ..")", 2 )
	end

	if i == nil then
		i = 0
	elseif type( i ) ~= "number" then
		error( "bad argument #2 to '" .. getname( ) .. "'(number expected got " .. type( i ) ..")", 2 )
	elseif i < 0 then
		error( "bad argument #2 to '" .. getname( ) .. "'(index out of bounds, too low)", 2 )
	end

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
	return pusherror( f, t, i )
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
	table should generally have _G as its __index and __newindex, so that any globals
	other than those being deliberately overridden operate as usual.
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
			return
		end
	until not name
end

table.rawinsert = table.insert
-- table.insert that respects metamethods
function table.insert( list, pos, value )
	local last = #list
	if value == nil then
		value = pos
		pos = last + 1
	end
	if pos < 1 or pos > last + 1 then
		error( "bad argument #2 to '" .. getname( ) .. "' (position out of bounds)", 2 )
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
		error( "bad argument #2 to '" .. getname( ) .. "' (position out of bounds)", 2 )
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
--]]

--- bind to locals to minimise environment recursion and improve speed
local
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, tostring, getfenv, setfenv
	=
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, tostring, getfenv, setfenv

--[[
	local version of ToLookup as to not depend on Main.lua
]]
local function ToLookup( tableArg )
	local lookup = { }
	for _, value in pairs( tableArg ) do
		lookup[ value ] = true
	end
	return lookup
end

-- Managed Object Data

local objectData = setmetatable( { }, { __mode = "k" } )

local function newObjectData( data )
	local obj = { }
	objectData[ obj ] = data
	return obj
end

local function getObjectData( obj, key )
	return objectData[ obj ][ key ]
end

function ModUtil.ObjectDataProxy( data, meta )
	return setmetatable( newObjectData( data ), meta )
end

function ModUtil.RawInterface( obj )
	return setmetatable( { }, {
		__index = function( _, ... )
			return rawget( obj, ... )
		end,
		__newindex = function( _, ... )
			return rawset( obj, ... )
		end,
		__len = function( _, ...)
			return rawlen( obj, ... )
		end,
		__next = function( _, ... )
			return rawnext( obj, ... )
		end,
		__inext = function( _, ... )
			return rawinext( obj, ... )
		end,
		__pairs = function( _, ... )
			return rawpairs( obj, ... )
		end,
		__ipairs = function( _, ... )
			return rawipairs( obj, ... )
		end
	} )
end

-- Environment Context ( EXPERIMENTAL ) ( BROKEN )

local _G = _ENV
local __G

local threadEnvironments = setmetatable( { }, { __mode = "k" } )

local function getEnv( thread )
	return threadEnvironments[ thread or coroutine.running( ) ] or _G
end

local function replaceGlobalEnvironment( )
	__G = debug.setmetatable( { }, {
		__index = function( _, key )
			return getEnv( )[ key ]
		end,
		__newindex = function( _, key, value )
			getEnv( )[ key ] = value
		end,
		__len = function( )
			return #getEnv( )
		end,
		__next = function( _, key )
			return next( getEnv( ), key )
		end,
		__inext = function( _, key )
			return inext( getEnv( ), key )
		end,
		__pairs = function( )
			return pairs( getEnv( ) )
		end,
		__ipairs = function( )
			return ipairs( getEnv( ) )
		end
	} )
	_G._G = __G
	local reg = debug.getregistry( )
	for i, v in ipairs( reg ) do
		if v == _G then reg[ i ] = __G end
	end
	ModUtil.Identifiers.Inverse._ENV = __G
end

-- Data Misc

local passByValueTypes = ToLookup{ "number", "boolean", "nil" }
local excludedFieldNames = ToLookup{ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" }

setmetatable( ModUtil.ToString, {
	__call = function ( _, o )
		local identifier = ModUtil.Identifiers.Data[ o ]
		identifier = identifier and identifier .. ":" or ""
		return identifier .. ModUtil.ToString.Static( o )
	end
})

function ModUtil.ToString.Address( o )
	local t = type( o )
	if t == "string" or passByValueTypes[ t ] then return end
	return tostring( o ):match( ": 0*([0-9A-F]*)" )
end

function ModUtil.ToString.Static( o )
	local t = type( o )
	if t == "string" or passByValueTypes[ t ] then return tostring( o ) end
	return tostring( o ):gsub( ": 0*", ":", 1 )
end

function ModUtil.ToString.Value( o )
	local t = type( o )
	if t == 'string' then
		return '"' .. o .. '"'
	end
	if passByValueTypes[ t ] then
		return tostring( o )
	end
	return '<' .. ModUtil.ToString( o ) .. '>'
end

function ModUtil.ToString.Key( o )
	local t = type( o )
	if t == 'string' then
		if not excludedFieldNames[ o ] and o:gmatch( "^[a-zA-Z_][a-zA-Z0-9_]*$" ) then
			return o
		end
		return '"' .. o .. '"'
	end
	if t == 'number' then
	    return "#" .. tostring( o )
	end
	if passByValueTypes[ t ] then return tostring( o ) end
    return '<' .. ModUtil.ToString( o ) .. '>'
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
		local out = { ModUtil.ToString.Value( o ), "( " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.ToString.Key( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ToString.Value( v ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " )"
	else
		return ModUtil.ToString.Value( o )
	end
end

function ModUtil.ToString.Deep( o, seen )
	seen = seen or { }
	if type( o ) == "table" and not seen[ o ] then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "( " }
		for k, v in pairs( o ) do
			table.insert( out, ModUtil.ToString.Key( k ) )
			table.insert( out, ' = ' )
			table.insert( out, ModUtil.ToString.Deep( v, seen ) )
			table.insert( out , ", " )
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " )"
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
	if type( o ) == "table" and not seen[ o ] and o ~= _G and o ~= _ENV and ( first or not ModUtil.Mods.Inverse[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "( " }
		for k, v in pairs( o ) do
			if v ~= _G and v ~= _ENV and not ModUtil.Mods.Inverse[ v ] then
				table.insert( out, ModUtil.ToString.Key( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToString.DeepNoNamespaces( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " )"
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
	if type( o ) == "table" and not seen[ o ] and ( first or o == _G or o == _ENV or ModUtil.Mods.Inverse[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "( " }
		for k, v in pairs( o ) do
			if v == _G or v == _ENV or ModUtil.Mods.Inverse[ v ] then
				table.insert( out, ModUtil.ToString.Key( k ) )
				table.insert( out, ' = ' )
				table.insert( out, ModUtil.ToString.DeepNamespaces( v, seen ) )
				table.insert( out , ", " )
			end
		end
		if #out > 2 then table.remove( out ) end
		return table.concat( out ) .. " )"
	else
		return ModUtil.ToString.Value( o )
	end
end

function ModUtil.MapVars( mapFunc, ... )
	local out = { }
	local args = table.pack( ... )
	for i = 1, args.n do
		table.insert( out, mapFunc( args[ i ] ) )
	end
	return table.unpack( out )
end

function ModUtil.Table.MapCopy( tableArg, mapFunc )
	local out = { }
	for k, v in pairs( tableArg ) do
		out[ k ] = mapFunc( v )
	end
	return out
end

function ModUtil.Table.Map( tableArg, mapFunc )
	for k, v in pairs( tableArg ) do
		tableArg[ k ] = mapFunc( v )
	end
end

function ModUtil.String.Join( sep, ... )
	local out = {}
	local args = table.pack( ... )
	out[ 1 ] = args[ 1 ]
	for i = 2, args.n do
		table.insert( out, sep )
		table.insert( out, args[ i ] )
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

function ModUtil.Table.UnKeyed( tableArg )
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
	level = level or 1
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
	level = level or 1
	local text
	text = ModUtil.ToString.Deep( debug.getinfo( level + 1 ) )
	ModUtil.Print( "Debug Info:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
end

function ModUtil.Print.Namespaces( level )
	level = level or 1
	local text
	ModUtil.Print("Namespaces:")
	text = ModUtil.ToString.DeepNamespaces( ModUtil.Locals( level + 1 ) )
	ModUtil.Print( "\t" .. "Locals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNamespaces( ModUtil.UpValues( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNamespaces( _ENV )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
end

function ModUtil.Print.Variables( level )
	level = level or 1
	local text
	ModUtil.Print("Variables:")
	text = ModUtil.ToString.DeepNoNamespaces( ModUtil.Locals( level + 1 ) )
	ModUtil.Print( "\t" .. "Locals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNoNamespaces( ModUtil.UpValues( level + 1 ) )
	ModUtil.Print( "\t" .. "UpValues:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
	text = ModUtil.ToString.DeepNoNamespaces( _ENV )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
end

--[[
	Call a function with the provided arguments
	instead of halting when an error occurs it prints the entire error traceback
--]]
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
--]]
function ModUtil.Array.Slice( state, start, stop, step )
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
	Safely retrieve the a value from deep inside a table, given
	an array of indices into the table.

	For example, if indexArray is { "a", 1, "c" }, then
	Table[ "a" ][ 1 ][ "c" ] is returned. If any of Table[ "a" ],
	Table[ "a" ][ 1 ], or Table[ "a" ][ 1 ][ "c" ] are nil, then nil
	is returned instead.

	Table			 - the table to retrieve from
	indexArray	- the list of indices
--]]
function ModUtil.IndexArray.Get( baseTable, indexArray )
	local node = baseTable
	for _, key in ipairs( indexArray ) do
		if type( node ) ~= "table" then
			return nil
		end
		local nodeType = ModUtil.Nodes.Inverse[ key ]
		if nodeType then
			node = ModUtil.Nodes.Data[ nodeType ].Get( node )
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
--]]
function ModUtil.IndexArray.Set( baseTable, indexArray, value )
	if next( indexArray ) == nil then
		return false -- can't set the input argument
	end
	local n = #indexArray -- change to shallow copy + table.remove later
	local node = baseTable
	for i = 1, n - 1 do
		local key = indexArray[ i ]
		if not ModUtil.Table.New( node, key ) then return false end
		local nodeType = ModUtil.Nodes.Inverse[ key ]
		if nodeType then
			node = ModUtil.Nodes.Data[ nodeType ].Get( node )
		else
			node = node[ key ]
		end
	end
	local key = indexArray[ n ]
	local nodeType = ModUtil.Nodes.Inverse[ key ]
	if nodeType then
		return ModUtil.Nodes.Data[ nodeType ].Set( node, value )
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
--]]
function ModUtil.Table.NilMerge( inTable, nilTable )
	for nilKey, nilVal in pairs( nilTable ) do
		local inVal = inTable[ nilKey ]
		if type( nilVal ) == "table" and type( inVal ) == "table" then
			ModUtil.Table.NilMerge( inVal, nilVal )
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
--]]
function ModUtil.Table.Merge( inTable, setTable )
	for setKey, setVal in pairs( setTable ) do
		local inVal = inTable[ setKey ]
		if type( setVal ) == "table" and type( inVal ) == "table" then
			ModUtil.Table.Merge( inVal, setVal )
		else
			inTable[ setKey ] = setVal
		end
	end
end

function ModUtil.IndexArray.Map( baseTable, indexArray, map, ... )
	ModUtil.IndexArray.Set( baseTable, indexArray, map( ModUtil.IndexArray.Get( baseTable, indexArray ), ... ) )
end

--[[
	Concatenates two index arrays, in order.

	a, b - the index arrays
--]]
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
	ModUtil.IndexArray.Map( _ENV, ModUtil.Path.IndexArray( path ), map, ... )
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
--]]
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
--]]
function ModUtil.Path.Get( path, base )
	return ModUtil.IndexArray.Get( base or _ENV, ModUtil.Path.IndexArray( path ) )
end

--[[
	Safely get set a value to a Path.

	For example, ModUtil.Path.Set( "a.b.c", 1 ) sets a.b.c = 1.
	If either a or a.b is nil, they are created.

	path - the path to get the value
	base - (optional) The table to retreive the value from.
				 If not provided, retreive a global.
--]]
function ModUtil.Path.Set( path, value, base )
	return ModUtil.IndexArray.Set( base or _ENV, ModUtil.Path.IndexArray( path ), value )
end

-- Metaprogramming Shenanigans

local stackLevelProperty
stackLevelProperty = {
	here = function( self )
		local thread = getObjectData( self, "thread" )
		local cursize = getObjectData( self, "level" ) + 1
		while debug.getinfo( thread, cursize, "f" ) do
			cursize = cursize + 1
		end
		return cursize - getObjectData( self, "size" ) - 1
	end,
	top = function( self )
		local thread = getObjectData( self, "thread" )
		local level = getObjectData( self, "level" )
		local cursize = level + 1
		while debug.getinfo( thread, cursize, "f" ) do
			cursize = cursize + 1
		end
		return cursize - level - 1
	end,
	there = function( self ) return getObjectData( self, "level" ) end,
	bottom = function( self ) return getObjectData( self, "size" ) end,
	co = function( self ) return getObjectData( self, "thread" ) end,
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
		return getObjectData( self, "thread" ) == getObjectData( other, "thread" )
		and getObjectData( self, "size" ) == getObjectData( other, "size")
		and getObjectData( self, "level" ) == getObjectData( other, "level")
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
		return ModUtil.ObjectDataProxy( { level = level, size = size, thread = thread }, ModUtil.Metatables.StackLevel )
	end
end

ModUtil.Metatables.StackLevels = {
	__index = function( self, level )
		return ModUtil.StackLevel( ( level or 0 ) + getObjectData( self, "level" ).here )
	end,
	__newindex = function( ) end,
	__len = function( self )
		return getObjectData( self, "level" ).bottom
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
	return ModUtil.ObjectDataProxy( { level = ModUtil.StackLevel( level or 0 ) }, ModUtil.Metatables.StackLevels )
end


local excludedUpValueNames = ToLookup{ "_ENV" }

ModUtil.Metatables.UpValues = {
	__index = function( self, name )
		if excludedUpValueNames[ name ] then return end
		local func = getObjectData( self, "func" )
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
		local func = getObjectData( self, "func" )
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
	__len = function( )
		return 0
	end,
	__next = function( self, name )
		local func = getObjectData( self, "func" )
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
	__inext = function( ) end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return function( ) end, self
	end
}

setmetatable( ModUtil.UpValues, {
	__call = function( _, func )
		if type( func ) ~= "function" then
			func = debug.getinfo( ( func or 1 ) + 1, "f" ).func
		end
		return ModUtil.ObjectDataProxy( { func = func }, ModUtil.Metatables.UpValues )
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
		tbl = { }
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
		local func =  getObjectData( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			local id = debug.upvalueid( func, idx )
			setUpValueIdData( id, func, idx )
			return id
		end
	end,
	__newindex = function( self, idx, value )
		local func = getObjectData( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			local func2, idx2 = getUpValueIdData( value )
			debug.upvaluejoin( func, idx, func2, idx2 )
			return
		end
	end,
	__len = function( self )
		return debug.getinfo( getObjectData( self, "func" ), 'u' ).nups
	end,
	__next = function ( self, idx )
		local func = getObjectData( self, "func" )
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
	return ModUtil.ObjectDataProxy( { func = func }, ModUtil.Metatables.UpValues.Ids )
end

ModUtil.Metatables.UpValues.Values = {
	__index = function( self, idx )
		local name, value = debug.getupvalue( getObjectData( self, "func" ), idx )
		if name and not excludedUpValueNames[ name ] then
			return value
		end
	end,
	__newindex = function( self, idx, value )
		local func = getObjectData( self, "func" )
		local name = debug.getupvalue( func, idx )
		if name and not excludedUpValueNames[ name ] then
			debug.setupvalue( func, idx, value )
			return
		end
	end,
	__len = function( self )
		return debug.getinfo( getObjectData( self, "func" ), 'u' ).nups
	end,
	__next = function ( self, idx )
		local func = getObjectData( self, "func" )
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
	return ModUtil.ObjectDataProxy( { func = func }, ModUtil.Metatables.UpValues.Values )
end

ModUtil.Metatables.UpValues.Names = {
	__index = function( self, idx )
		local name = debug.getupvalue( getObjectData( self, "func" ), idx )
		if name and not excludedUpValueNames[ name ] then
			return name
		end
	end,
	__newindex = function( ) end,
	__len = ModUtil.Metatables.UpValues.Values.__len,
	__next = function ( self, idx )
		local func = getObjectData( self, "func" )
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
	return ModUtil.ObjectDataProxy( { func = func }, ModUtil.Metatables.UpValues.Names )
end

ModUtil.Metatables.UpValues.Stacked = {
	__index = function( self, name )
		if excludedUpValueNames[ name ] then return end
		for _, level in pairs( getObjectData( self, "levels" ) ) do
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
		for _, level in pairs( getObjectData( self, "levels" ) ) do
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
		local levels = getObjectData( self, "levels" )
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
		return function( ) end, self
	end
}

function ModUtil.UpValues.Stacked( level )
	return ModUtil.ObjectDataProxy( { levels = ModUtil.StackLevels( ( level or 1 ) ) }, ModUtil.Metatables.UpValues.Stacked )
end

local excludedLocalNames = ToLookup{ "(*temporary)", "(for generator)", "(for state)", "(for control)" }

ModUtil.Metatables.Locals = {
	__index = function( self, name )
		if excludedLocalNames[ name ] then return end
		local level = getObjectData( self, "level" )
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
		local level = getObjectData( self, "level" )
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
		local level = getObjectData( self, "level" )
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
	__call = function( _, level )
		return ModUtil.ObjectDataProxy( { level = ModUtil.StackLevel( ( level or 1 ) + 1 ) }, ModUtil.Metatables.Locals )
	end
} )

ModUtil.Metatables.Locals.Values = {
	__index = function( self, idx )
		local name, value = getObjectData( self, "level" ).getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				return value
			end
		end
	end,
	__newindex = function( self, idx, value )
		local level = getObjectData( self, "level" )
		local name = level.getlocal( idx )
		if name then
			if not excludedLocalNames[ name ] then
				level.setlocal( idx, value )
			end
		end
	end,
	__len = function( self )
		local level = getObjectData( self, "level" )
		local idx = 1
		while level.getlocal( level, idx ) do
			idx = idx + 1
		end
		return idx - 1
	end,
	__next = function( self, idx )
		idx = idx or 0
		idx = idx + 1
		local name, val = getObjectData( self, "level" ).getlocal( idx )
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
	for i, value in pairs( ModUtil.Locals.Values( level ) ) do
		-- stuff
	end
--]]
function ModUtil.Locals.Values( level )
	return ModUtil.ObjectDataProxy( { level = ModUtil.StackLevel( ( level or 1 ) + 1 ) }, ModUtil.Metatables.Locals.Values )
end

ModUtil.Metatables.Locals.Names = {
	__index = function( self, idx )
		local name = getObjectData( self, "level" ).getlocal( idx )
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
		local name = getObjectData( self, "level" ).getlocal( idx )
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
	for i, name in pairs( ModUtil.Locals.Names( level ) ) do
		-- stuff
	end
--]]
function ModUtil.Locals.Names( level )
	return ModUtil.ObjectDataProxy( { level = ModUtil.StackLevel( ( level or 1 ) + 1 ) }, ModUtil.Metatables.Locals.Names )
end

ModUtil.Metatables.Locals.Stacked = {
	__index = function( self, name )
		if excludedLocalNames[ name ] then return end
		for _, level in pairs( getObjectData( self, "levels" ) ) do
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
		for _, level in pairs( getObjectData( self, "levels" ) ) do
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
		local levels = getObjectData( self, "levels" )
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
		return function( ) end, self
	end
}

--[[
	Access to local variables, in the current function and callers.
	The most recent definition with a given name on the call stack will
	be used.

	For example, if your function is called from CreateTraitRequirements,
	you could access its 'local screen' as ModUtil.Locals.Stacked( ).screen
	and its 'local hasRequirement' as ModUtil.Locals.Stacked( ).hasRequirement.
--]]
function ModUtil.Locals.Stacked( level )
	return ModUtil.ObjectDataProxy( { levels = ModUtil.StackLevels( level or 1 ) }, ModUtil.Metatables.Locals.Stacked )
end

-- Entangled Data Structures

ModUtil.Metatables.Entangled = { }

ModUtil.Metatables.Entangled.Map = {

	Data = {
		__index = function( self, key )
			return getObjectData( self, "Map" )[ key ]
		end,
		__newindex = function( self, key, value )
			local data = getObjectData( self, "Map" )
			local prevValue = data[ key ]
			data[ key ] = value
			local preImage = getObjectData( self, "PreImage" )
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
			return #getObjectData( self, "Map" )
		end,
		__next = function( self, key )
			return next( getObjectData( self, "Map" ), key )
		end,
		__inext = function( self, idx )
			return inext( getObjectData( self, "Map" ), idx )
		end,
		__pairs = function( self )
			return qrawpairs( self )
		end,
		__ipairs = function( self )
			return qrawipairs( self )
		end
	},

	PreImage = {
		__index = function( self, value )
			return getObjectData( self, "PreImage" )[ value ]
		end,
		__newindex = function( self, value, keys )
			getObjectData( self, "PreImage" )[ value ] = keys
			local data = getObjectData( self, "Map" )
			for key in pairs( data ) do
				data[ key ] = nil
			end
			for key in ipairs( keys ) do
				data[ key ] = value
			end
		end,
		__len = function( self )
			return #getObjectData( self, "PreImage" )
		end,
		__next = function( self, key )
			return next( getObjectData( self, "PreImage" ), key )
		end,
		__inext = function( self, idx )
			return inext( getObjectData( self, "PreImage" ), idx )
		end,
		__pairs = function( self )
			return qrawpairs( self )
		end,
		__ipairs = function( self )
			return qrawipairs( self )
		end
	},

	Unique = {

		Data = {
			__index = function( self, key )
				return getObjectData( self, "Data" )[ key ]
			end,
			__newindex = function( self, key, value )
				local data, inverse = getObjectData( self, "Data" ), getObjectData( self, "Inverse" )
				if value ~= nil then
					local k = inverse[ value ]
					if k ~= key  then
						if k ~= nil then
							data[ k ] = nil
						end
						inverse[ value ] = key
					end
				end
				if key ~= nil then
					local v = data[ key ]
					if v ~= value then
						if v ~= nil then
							inverse[ v ] = nil
						end
						data[ key ] = value
					end
				end
			end,
			__len = function( self )
				return #getObjectData( self, "Data" )
			end,
			__next = function( self, key )
				return next( getObjectData( self, "Data" ), key )
			end,
			__inext = function( self, idx )
				return inext( getObjectData( self, "Data" ), idx )
			end,
			__pairs = function( self )
				return qrawpairs( self )
			end,
			__ipairs = function( self )
				return qrawipairs( self )
			end
		},

		Inverse = {
			__index = function( self, value )
				return getObjectData( self, "Inverse" )[ value ]
			end,
			__newindex = function( self, value, key )
				local data, inverse = getObjectData( self, "Data" ), getObjectData( self, "Inverse" )
				if value ~= nil then
					local k = inverse[ value ]
					if k ~= key then
						if k ~= nil then
							data[ k ] = nil
						end
						inverse[ value ] = key
					end
				end
				if key ~= nil then
					local v = data[ key ]
					if v ~= value then
						if v ~= nil then
							inverse[ v ] = nil
						end
						data[ key ] = value
					end
				end
			end,
			__len = function( self )
				return #getObjectData( self, "Inverse" )
			end,
			__next = function( self, value )
				return next( getObjectData( self, "Inverse" ), value )
			end,
			__inext = function( self, idx )
				return inext( getObjectData( self, "Inverse" ), idx )
			end,
			__pairs = function( self )
				return qrawpairs( self )
			end,
			__ipairs = function( self )
				return qrawipairs( self )
			end
		}

	}

}

ModUtil.Entangled.Map = {
	Unique = { }
}

setmetatable( ModUtil.Entangled.Map, {
	__call = function( )
		local data, preImage = { }, { }
		data, preImage = { Data = data, PreImage = preImage }, { Data = data, PreImage = preImage }
		data = ModUtil.ObjectDataProxy( data, ModUtil.Metatables.Entangled.Map.Data )
		preImage = ModUtil.ObjectDataProxy( preImage, ModUtil.Metatables.Entangled.Map.PreImage )
		return { Data = data, Index = preImage, PreImage = preImage }
	end
} )

setmetatable( ModUtil.Entangled.Map.Unique, {
	__call = function( )
		local data, inverse = { }, { }
		data, inverse = { Data = data, Inverse = inverse }, { Data = data, Inverse = inverse }
		data = ModUtil.ObjectDataProxy( data, ModUtil.Metatables.Entangled.Map.Unique.Data )
		inverse = ModUtil.ObjectDataProxy( inverse, ModUtil.Metatables.Entangled.Map.Unique.Inverse )
		return { Data = data, Index = inverse, Inverse = inverse }
	end
} )

-- Context Managers ( EXPERIMENTAL ) ( BROKEN )

ModUtil.Context = { }

local threadContexts = { }
setmetatable( threadContexts, { __mode = "kv" } )

ModUtil.Metatables.Context = {
	__call = function( self, callContext, ... )

		local thread = coroutine.running( )

		local contextInfo = {
			call = callContext,
			wrap = function( ... ) callContext( ... ) end,
			parent = threadContexts[ thread ],
			thread = thread
		}

		threadContexts[ thread ] = contextInfo

		contextInfo.context = self
		contextInfo.args = table.pack( ... )
		contextInfo.data = { }
		contextInfo.params = table.pack( getObjectData( self, "callContextProcessor" )( contextInfo ) )

		local penv = threadEnvironments[ thread ]
		local env = setmetatable( { }, { __index = ( penv or _G ), __newindex = ( penv or _G ) } )
		threadEnvironments[ thread ] = env

		contextInfo.response = table.pack( contextInfo.wrap( table.unpack( contextInfo.params ) ) )

		if getObjectData( self, "postCall" ) then
			contextInfo.final = table.pack( getObjectData( self, "postCall" )( contextInfo ) )
		end

		threadEnvironments[ thread ] = penv
		threadContexts[ thread ] = contextInfo.parent

		if contextInfo.final then
			return table.unpack( contextInfo.final )
		end
	end
}

setmetatable( ModUtil.Context, {
	__call = function( _, callContextProcessor, postCall )
		return ModUtil.ObjectDataProxy( { callContextProcessor = callContextProcessor, postCall = postCall }, ModUtil.Metatables.Context )
	end
} )

ModUtil.Context.Data = ModUtil.Context( function( info )
	local tbl = info.args[ 1 ]
	info.env = setmetatable( { }, {
		__index = function( _, key ) return tbl[ key ] or __G[ key ] end,
		__newindex = tbl
	} )
end )

ModUtil.Context.Meta = ModUtil.Context( function( info )
	local tbl = ModUtil.Nodes.Data.Metatable.New( info.args[ 1 ] )
	info.env = setmetatable( { }, {
		__index = function( _, key ) return tbl[ key ] or __G[ key ] end,
		__newindex = tbl
	} )
end )

local fenvData = setmetatable( { }, { __mode = "k" } )

ModUtil.Context.Env = ModUtil.Context( function( info )
	local func = info.args[ 1 ]
	local fenv = fenvData[ func ]
	if not fenv then
		fenv = getfenv( func ) or { }
		fenvData[ func ] = fenv
	end
	setfenv( func, setmetatable( { }, {
		__index = function( _, key )
			local val
			local env = threadEnvironments[ coroutine.running( ) ]
			if env then
				val = env[ key ]
			end
			if val ~= nil then return val end
			val = fenv[ key ]
			if val ~= nil then return val end
			return _G[ key ]
		end,
		__newindex = function( _, key, val )
			local env = threadEnvironments[ coroutine.running( ) ]
			if env and env[ key ] ~= nil then
				env[ key ] = val
			elseif fenv[ key ] ~= nil then
				fenv[ key ] = val
			end
			_G[ key ] = val
		end
	} ) )
	info.env = setmetatable( { }, {
		__index = function( _, key ) return fenv[ key ] or __G[ key ] end,
		__newindex = fenv
	} )
end )

ModUtil.Context.Call = ModUtil.Context(
	function( info )
		local meta
		local penv = threadEnvironments[ info.thread ]
		local func = info.args[ 1 ]

		meta = {
			__index = function( _, key )
				local data = fenvData[ func ]
				if data then
					local val = data[ key ]
					if val ~= nil then return val end
				end
				return ( penv or _G )[ key ]
			end,
			__newindex = function( _, key, val )
				local data = fenvData[ func ]
				if data and data[ key ] ~= nil then
					data[ key ] = val
				else
					( penv or _G )[ key ] = val
				end
			end
		}

		local env = setmetatable( { }, meta )
		info.env = setmetatable( { }, { __index = env, __newindex = ModUtil.RawInterface( env ) } )

		info.data.penv = penv
		info.data.env = env
		info.data.func = func
	end,
	function ( info )
		threadEnvironments[ info.thread ] = info.env
		local ret = table.pack( info.data.func( table.unpack( info.args, 2, info.args.n ) ) )
		threadEnvironments[ info.thread ] = info.penv
		return table.unpack( ret )
	end
)

-- Special traversal nodes

ModUtil.Nodes = ModUtil.Entangled.Map.Unique( )

function ModUtil.Nodes.New( parent, key )
	local nodeType = ModUtil.Nodes.Inverse[ key ]
	if nodeType then
		return ModUtil.Nodes.Data[ nodeType ].New( parent )
	end
	local tbl = parent[ key ]
	if type( tbl ) ~= "table" then
		tbl = { }
		parent[ key ] = tbl
	end
	return tbl
end

ModUtil.Nodes.Data.Metatable = {
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

ModUtil.Nodes.Data.Call = {
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

ModUtil.Nodes.Data.UpValues = {
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

-- Identifier System

ModUtil.Identifiers = ModUtil.Entangled.Map.Unique( )
setmetatable( getObjectData( ModUtil.Identifiers.Data, "Inverse" ), { __mode = "k" } )
setmetatable( getObjectData( ModUtil.Identifiers.Inverse, "Data" ), { __mode = "v" } )

ModUtil.Identifiers.Inverse._G = _G
ModUtil.Identifiers.Inverse.ModUtil = ModUtil

ModUtil.Mods = ModUtil.Entangled.Map.Unique( )
setmetatable( getObjectData( ModUtil.Mods.Data, "Inverse" ), { __mode = "k" } )
setmetatable( getObjectData( ModUtil.Mods.Inverse, "Data" ), { __mode = "v" } )
ModUtil.Mods.Data.ModUtil = ModUtil

-- Function Wrapping, Overriding, Referral

local wrapCallbacks = { }
setmetatable( wrapCallbacks, { __mode = "k" } )
local overrides = { }
setmetatable( overrides, { __mode = "k" } )

function ModUtil.Wrap( base, wrap, mod )
	local obj = { Base = base, Wrap = wrap, Mod = mod }
	local func = function( ... ) return wrap( base, ... ) end
	wrapCallbacks[ func ] = obj
	return func
end

function ModUtil.Unwrap( obj )
	local callback = wrapCallbacks[ obj ]
	return callback and callback.Base or obj
end

function ModUtil.Rewrap( obj )
	local node = wrapCallbacks[ obj ]
	if not node then return ModUtil.Overriden( obj ) end
	return ModUtil.Wrap( ModUtil.Rewrap( node.Base ), node.Wrap, node.Mod )
end

function ModUtil.Override( base, value, mod )
    local obj = { Base = ModUtil.Original( base ), Mod = mod }
    overrides[ value ] = obj
    return ModUtil.Rewrap( value )
end

function ModUtil.Overriden( obj )
	local node = wrapCallbacks[ obj ]
	if not node then return obj end
	return ModUtil.Original( node.Base )
end

function ModUtil.Original( obj )
	local node = wrapCallbacks[ obj ] or overrides[ obj ]
	if not node then return obj end
	return ModUtil.Original( node.Base )
end

function ModUtil.ReferFunction( obtainer, ... )
	local args = table.pack( ... )
	return function( ... )
		return obtainer( table.unpack( args ) )( ... )
	end
end

ModUtil.Metatables.ReferTable = {
	__index = function( self, key )
		return getObjectData( self, "obtain" )( )[ key ]
	end,
	__newindex = function( self, key, value )
		getObjectData( self, "obtain" )( )[ key ] = value
	end,
	__call = function( self, ... )
		return getObjectData( self, "obtain" )( )( ... )
	end,
	__len = function( self )
		return #getObjectData( self, "obtain" )( )
	end,
	__next = function( self, key )
		return next( getObjectData( self, "obtain" )( ), key )
	end,
	__inext = function( self, idx )
		return inext( getObjectData( self, "obtain" )( ), idx )
	end,
	__pairs = function( self )
		return pairs( getObjectData( self, "obtain" )( ) )
	end,
	__ipairs = function( self )
		return ipairs( getObjectData( self, "obtain" )( ) )
	end
}

function ModUtil.ReferTable( obtainer, ... )
	local args = table.pack( ... )
	local obtain = function( )
		return obtainer( table.unpack( args ) )
	end
	return ModUtil.ObjectDataProxy( { obtain = obtain }, ModUtil.Metatables.ReferTable )
end

---

function ModUtil.IndexArray.Wrap( baseTable, indexArray, wrapFunc, mod )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Wrap, wrapFunc, mod )
end

function ModUtil.IndexArray.Unwrap( baseTable, indexArray )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Unwrap )
end

function ModUtil.IndexArray.Rewrap( baseTable, indexArray )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Rewrap )
end

function ModUtil.IndexArray.Override( baseTable, indexArray, value, mod )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Override, value, mod )
end

function ModUtil.IndexArray.Overriden( baseTable, indexArray )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Overriden )
end

function ModUtil.IndexArray.Original( baseTable, indexArray )
	ModUtil.IndexArray.Map( baseTable, indexArray, ModUtil.Original )
end

function ModUtil.IndexArray.ReferFunction( baseTable, indexArray )
	return ModUtil.ReferFunction( ModUtil.IndexArray.Get, baseTable, indexArray )
end

function ModUtil.IndexArray.ReferTable( baseTable, indexArray )
	return ModUtil.ReferTable( ModUtil.IndexArray.Get, baseTable, indexArray )
end

---

function ModUtil.Path.Wrap( path, wrapFunc, mod )
	ModUtil.Path.Map( path, ModUtil.Wrap, wrapFunc, mod )
end

function ModUtil.Path.Unwrap( path )
	ModUtil.Path.Map( path, ModUtil.Unwrap )
end

function ModUtil.Path.Rewrap( path )
	ModUtil.Path.Map( path, ModUtil.Rewrap )
end

function ModUtil.Path.Override( path, value, mod )
	ModUtil.Path.Map( path, ModUtil.Override, value, mod )
end

function ModUtil.Path.Overriden( path )
	ModUtil.Path.Map( path, ModUtil.Overriden )
end

function ModUtil.Path.Original( path )
	ModUtil.Path.Map( path, ModUtil.Original )
end

function ModUtil.Path.ReferFunction( path )
	return ModUtil.ReferFunction( ModUtil.Path.Get, path )
end

function ModUtil.Path.ReferTable( path )
	return ModUtil.ReferTable( ModUtil.Path.Get, path )
end

-- Internal access

do
	local ups = ModUtil.UpValues( function( )
	return _G,
		objectData, newObjectData, getObjectData,
		wrapCallbacks, overrides,
		threadEnvironments, fenvData, getEnv, replaceGlobalEnvironment
	end )
	setmetatable( ModUtil.Internal, { __index = ups, __newindex = ups } )
end

-- Final Actions

replaceGlobalEnvironment( )