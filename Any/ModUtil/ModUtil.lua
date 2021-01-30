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
	},

}
SaveIgnores[ "ModUtil" ] = true

-- Extended Global Utilities (assuming lua 5.2)

local error, pcall, xpcall = error, pcall, xpcall

local debug, type, table = debug, type, table
local function getname()
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
		error( "bad argument #1 to '" .. getname() .. "'(table expected got " .. type( i ) ..")", 2 )
	end

	if i == nil then
		i = 0
	elseif type( i ) ~= "number" then
		error( "bad argument #2 to '" .. getname() .. "'(number expected got " .. type( i ) ..")", 2 )
	elseif i < 0 then
		error( "bad argument #2 to '" .. getname() .. "'(index out of bounds, too low)", 2 )
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

table.rawinsert = table.insert
-- table.insert that respects metamethods
function table.insert( list, pos, value )
	local last = #list
	if value == nil then
		value = pos
		pos = last + 1
	end
	if pos < 1 or pos > last + 1 then
		error( "bad argument #2 to '" .. getname() .. "' (position out of bounds)", 2 )
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
		error( "bad argument #2 to '" .. getname() .. "' (position out of bounds)", 2 )
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

-- Environment Context (EXPERIMENTAL)

-- bind to locals to minimise environment recursion and improve speed
local
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, tostring
	=
	rawset, rawlen, ModUtil, getmetatable, setmetatable, pairs, ipairs, coroutine,
		rawpairs, rawipairs, qrawpairs, qrawipairs, tostring

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
local envNodeInfo = { [ surrogateEnvironments ] = { data = __G, depth = 0, parent = nil } }
setmetatable( envNodeInfo, { __mode = "k" } )
local envNodeMeta = {
	__mode = "k",
	__gc = function( self )
		envNodeInfo[ self ] = nil
	end,
	__index = ModUtil.RawInterface( surrogateEnvironments ), -- may need to remove this
	__call = function( self )
		return envNodeInfo[ self ].data
	end,
	__len = function( self )
		return envNodeInfo[ self ].depth
	end,
	__unm = function( self )
		return envNodeInfo[ self ].parent
	end
}
setmetatable( surrogateEnvironments, envNodeMeta )

local getinfo = debug.getinfo
local function getenv( level )
	level = ( level or 1 ) + 1
	local stack = { }
	local index = { }
	local l = level
	local info = getinfo( l, "f" )
	while info do
		local i, func = l - level, info.func
		stack[ i ], index[ func ] = func, i
		l = l + 1
		info = getinfo( l, "f" )
	end
	l = l - level - 1
	local diffNode
	local envNode
	for i = l, 1, -1 do
		envNode = ( envNode or surrogateEnvironments )[ stack[ i ] ] or surrogateEnvironments
		if envNode ~= surrogateEnvironments then
			diffNode = envNode
		end
	end
	return ( diffNode or surrogateEnvironments )( )
end

local function replaceGlobalEnvironment( )

	local meta = {
		__index = function( _, key )
			local value = getenv( 2 )[ key ]
			if value ~= nil then return value end
			local t = type( key )
			if t == "function" or t == "table" then
				return key
			end
		end,
		__newindex = function( _, key, value )
			getenv( 2 )[ key ] = value
		end,
		__len = function( )
			return #getenv( 2 )
		end,
		__next = function( _, key )
			return next( getenv( 2 ), key )
		end,
		__inext = function( _, key )
			return inext( getenv( 2 ), key )
		end,
		__pairs = function( )
			return pairs( getenv( 2 ) )
		end,
		__ipairs = function( )
			return ipairs( getenv( 2 ) )
		end
	}

	debug.setmetatable( __G._G, meta )
end

replaceGlobalEnvironment()

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
		local path = ModUtil.Mods.Inverse[ parent ]
		if path ~= nil then
			path = path .. '.'
		else
			path = ''
		end
		path = path .. modName
		ModUtil.Mods.Data[ path ] = mod
		ModUtil.Identifiers.Inverse[ path ] = mod
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
	local identifier = ModUtil.Identifiers.Data[ o ]
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
	local identifier = ModUtil.Identifiers.Data[ o ]
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
	if type( o ) == "table" and not seen[ o ] and o ~= __G and o ~= __G._G and ( first or not ModUtil.Mods.Inverse[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			if v ~= __G and v ~= __G._G and not ModUtil.Mods.Inverse[ v ] then
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
	if type( o ) == "table" and not seen[ o ] and ( first or o == __G or o == __G._G or ModUtil.Mods.Inverse[ o ] ) then
		seen[ o ] = true
		local out = { ModUtil.ToString.Value( o ), "{ " }
		for k, v in pairs( o ) do
			if v == __G or v == __G._G or ModUtil.Mods.Inverse[ v ] then
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
	text = ModUtil.ToString.DeepNamespaces( getenv( level + 1 ) )
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
	text = ModUtil.ToString.DeepNoNamespaces( getenv( level + 1 ) )
	ModUtil.Print( "\t" .. "Globals:" .. "\t" .. text:sub( 1 + text:find( ">" ) ) )
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
]]
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
]]
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
]]
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
	ModUtil.IndexArray.Map( _G, ModUtil.Path.IndexArray( path ), map, ... )
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

-- Metaprogramming Shenanigans

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
	__call = function( _, func )
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
	__call = function( _, level )
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
	local locals = { levels = ModUtil.StackLevels( level or 1 ) }
	setmetatable( locals, ModUtil.Metatables.Locals.Stacked )
	return locals
end

-- Entangled Data Structures

ModUtil.Metatables.Entangled = { }

ModUtil.Metatables.Entangled.Map = {

	Data = {
		__index = function( self, key )
			return rawget( self, "Map" )[ key ]
		end,
		__newindex = function( self, key, value )
			local data = rawget( self, "Map" )
			local prevValue = data[ key ]
			data[ key ] = value
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
	},

	PreImage = {
		__index = function( self, value )
			return rawget( self, "PreImage" )[ value ]
		end,
		__newindex = function( self, value, keys )
			rawget( self, "PreImage" )[ value ] = keys
			local data = rawget( self, "Map" )
			for key in pairs( data ) do
				data[ key ] = nil
			end
			for key in ipairs( keys ) do
				data[ key ] = value
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
	},

	Unique = {

		Data = {
			__index = function( self, key )
				return rawget( self, "Data" )[ key ]
			end,
			__newindex = function( self, key, value )
				local data, inverse = rawget( self, "Data" ), rawget( self, "Inverse" )
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
		},

		Inverse = {
			__index = function( self, value )
				return rawget( self, "Inverse" )[ value ]
			end,
			__newindex = function( self, value, key )
				local data, inverse = rawget( self, "Data" ), rawget( self, "Inverse" )
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
				return #rawget( self, "Inverse" )
			end,
			__next = function( self, value )
				return next( rawget( self, "Inverse" ), value )
			end,
			__inext = function( self, idx )
				return inext( rawget( self, "Inverse" ), idx )
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
		setmetatable( data, ModUtil.Metatables.Entangled.Map.Data )
		setmetatable( preImage, ModUtil.Metatables.Entangled.Map.PreImage )
		return { Data = data, Index = preImage, PreImage = preImage }
	end
} )

setmetatable( ModUtil.Entangled.Map.Unique, {
	__call = function( )
		local data, inverse = { }, { }
		data, inverse = { Data = data, Inverse = inverse }, { Data = data, Inverse = inverse }
		setmetatable( data, ModUtil.Metatables.Entangled.Map.Unique.Data )
		setmetatable( inverse, ModUtil.Metatables.Entangled.Map.Unique.Inverse )
		return { Data = data, Index = inverse, Inverse = inverse }
	end
} )

-- Context Managers (EXPERIMENTAL)

ModUtil.Context = { }

ModUtil.Metatables.Environment = {
	__index = function( self, key )
		if key == "_G" then
			return rawget( self, "global" ) or self
		end
		local value = rawget( self, "data" )[ key ]
		if value ~= nil then
			return value
		end
		return ( rawget( self, "fallback" ) or _G )[ key ]
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
		local data, value = rawget( self, "data" ), nil
		repeat
			key, value = next( data, key )
			if key == "_G" then
				return rawget( self, "global" ) or self
			end
		until value ~= nil or key == nil
		return key, value
	end,
	__inext = function( self, idx )
		local data, value = rawget( self, "data" ), nil
		repeat
			idx, value = next( data, idx )
		until value ~= nil or idx == nil
		return idx, value
	end,
	__pairs = function( self )
		return qrawpairs( self )
	end,
	__ipairs = function( self )
		return qrawipairs( self )
	end
}

local threadContexts = { }
setmetatable( threadContexts, { __mode = "kv" } )

ModUtil.Metatables.Context = {
	__call = function( self, callContext, ... )

		local thread = coroutine.running( )

		local contextInfo = {
			call = callContext,
			wrap = function( ... ) callContext( ... ) end,
			parent = threadContexts[ thread ]
		}

		threadContexts[ thread ] = contextInfo

		contextInfo.context = self
		contextInfo.args = table.pack( ... )
		local processed = table.pack( rawget( self, "callContextProcessor" )( contextInfo, ... ) )
		contextInfo.params = table.pack( table.unpack( processed, 2, processed.n ) )
		contextInfo.data = processed[ 1 ]

		contextInfo.envNode = { }
		setmetatable( contextInfo.envNode, envNodeMeta )
		envNodeInfo[ contextInfo.envNode ] = { data = contextInfo.data, parent = surrogateEnvironments, depth = 1 }
		surrogateEnvironments[ contextInfo.wrap ] = contextInfo.envNode
		contextInfo.wrap( table.unpack( contextInfo.params ) )

		threadContexts[ thread ] = contextInfo.parent
	end
}

setmetatable( ModUtil.Context, {
	__call = function( _, callContextProcessor )
		local context = { callContextProcessor = callContextProcessor }
		setmetatable( context, ModUtil.Metatables.Context )
		return context
	end
} )

ModUtil.Context.Data = ModUtil.Context( function( info )
	local env = { data = info.args[ 1 ] }
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Meta = ModUtil.Context( function( info )
	local env = { data = ModUtil.Nodes.Data.Metatable.New( info.args[ 1 ] ) }
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

ModUtil.Context.Call = ModUtil.Context( function( info )
	local stack = { }
	local l = 1
	while info and info.context == ModUtil.Context.Call do
		stack[ l ] = info.args[ 1 ]
		l = l + 1
		info = info.parent
	end
	l = l - 1
	ModUtil.Print( l, ModUtil.ToString.Deep( stack ))
	local envNode = surrogateEnvironments
	for i = l, 1, -1 do
		local func = stack[ i ]
		if not envNode[ func ] then
			local env = { }
			env._G = env
			setmetatable( env, { __index = envNode( ) } )
			local node = { }
			envNodeInfo[ node ] = { data = env, parent = envNode, depth = #envNode + 1 }
			envNode[ func ] = node
			setmetatable( node, envNodeMeta )
		end
		envNode = envNode[ func ]
	end
	ModUtil.Print( l, ModUtil.ToString.Deep( stack ))
	local env = { data = envNode( ) }
	setmetatable( env, ModUtil.Metatables.Environment )
	return env
end )

-- Special traversal nodes (EXPERIMENTAL)

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
setmetatable( rawget( ModUtil.Identifiers.Data, "Inverse" ), { __mode = "k" } )
setmetatable( rawget( ModUtil.Identifiers.Inverse, "Data" ), { __mode = "v" } )

ModUtil.Identifiers.Inverse._G = _G
ModUtil.Identifiers.Inverse.ModUtil = ModUtil

ModUtil.Mods = ModUtil.Entangled.Map.Unique( )
setmetatable( rawget( ModUtil.Mods.Data, "Inverse" ), { __mode = "k" } )
setmetatable( rawget( ModUtil.Mods.Inverse, "Data" ), { __mode = "v" } )
ModUtil.Mods.Data.ModUtil = ModUtil

-- Function Wrapping, Overriding, Referral

ModUtil.Internal.WrapCallbacks = { }
setmetatable( ModUtil.Internal.WrapCallbacks, { __mode = "k" } )
ModUtil.Internal.Overrides = { }
setmetatable( ModUtil.Internal.Overrides, { __mode = "k" } )

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

function ModUtil.Override( base, value, mod )
    local obj = { Base = ModUtil.OriginalValue( base ), Mod = mod }
    ModUtil.Internal.Overrides[ value ] = obj
    return ModUtil.Rewrap( value )
end

function ModUtil.Overriden( obj )
	local node = ModUtil.Internal.WrapCallbacks[ obj ]
	if not node then return obj end
	return ModUtil.Original( node.Base )
end

function ModUtil.Original( obj )
	local node = ModUtil.Internal.WrapCallbacks[ obj ] or ModUtil.Internal.Overrides[ obj ]
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
	__index = function( self, value )
		return rawget( self, "obtain" )( )[ value ]
	end,
	__newindex = function( self, value, key )
		rawget( self, "obtain" )( )[ value ] = key
	end,
	__len = function( self )
		return #rawget( self, "obtain" )( )
	end,
	__next = function( self, value )
		return next( rawget( self, "obtain" )( ), value )
	end,
	__inext = function( self, idx )
		return inext( rawget( self, "obtain" )( ), idx )
	end,
	__pairs = function( self )
		return pairs( rawget( self, "obtain" )( ) )
	end,
	__ipairs = function( self )
		return ipairs( rawget( self, "obtain" )( ) )
	end
}

function ModUtil.ReferTable( obtainer, ... )
	local args = table.pack( ... )
	local obtain = function( )
		return obtainer( table.unpack( args ) )
	end
	local referTable = { obtain = obtain }
	setmetatable( referTable, ModUtil.Metatables.ReferTable )
	return referTable
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