--[[
    ModUtil Main
    Components of ModUtil that depend on loading after Main.lua
]]

--- bind to locals to minimise environment recursion and improve speed
local ModUtil, pairs, ipairs, table, SaveIgnores, _G
    = ModUtil, pairs, ipairs, table, SaveIgnores, ModUtil.Internal._G

-- Management

SaveIgnores[ "ModUtil" ] = true

--[[
	Create a namespace that can be used for the mod's functions
	and data, and ensure that it doesn't end up in save files.

	modName - the name of the mod
	parent	- the parent mod, or nil if this mod stands alone
--]]
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
--]]
local function forceClosed( triggerArgs )
	for _, v in pairs( ModUtil.Anchors.CloseFuncs ) do
		v( nil, nil, triggerArgs )
	end
	ModUtil.Anchors.CloseFuncs = { }
	ModUtil.Anchors.Menu = { }
end
OnAnyLoad{ function( triggerArgs ) forceClosed( triggerArgs ) end }

local funcsToLoad = { }

local function loadFuncs( triggerArgs )
	for _, v in pairs( funcsToLoad ) do
		v( triggerArgs )
	end
	funcsToLoad = { }
end
OnAnyLoad{ function( triggerArgs ) loadFuncs( triggerArgs ) end }

--[[
	Run the provided function once on the next in-game load.

	triggerFunction - the function to run
--]]
function ModUtil.LoadOnce( triggerFunction )
	table.insert( funcsToLoad, triggerFunction )
end

--[[
	Cancel running the provided function once on the next in-game load.

	triggerFunction - the function to cancel running
--]]
function ModUtil.CancelLoadOnce( triggerFunction )
	for i, v in ipairs( funcsToLoad ) do
		if v == triggerFunction then
			table.remove( funcsToLoad, i )
		end
	end
end

-- Internal Access

do
	local ups = ModUtil.UpValues( function( )
		return forceClosed, funcsToLoad, loadFuncs
	end )
	rawset( ModUtil.Internal, "Main", setmetatable( { }, { __index = ups, __newindex = ups } ) )
end