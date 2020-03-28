-- IMPORT @ DEFAULT

--[[
Author: MagicGonads 
	Library to allow mods to be more compatible with eachother
	To include in your mod you must tell the user that they require this mod.
	
	To use add (before other mods) to the BOTTOM of DEFAULT
	"Import "../Mods/ModUtil/Scripts/ModUtil.lua""
	
	To optimise put after other mods (this is done automatically by importmods)
	"if ModUtil then if ModUtil.CollapseMarked then ModUtil.CollapseMarked() end end"
	at the BOTTOM of DEFAULT
]]

ModUtil = {
	AutoCollapse = true,
}
SaveIgnores["ModUtil"]=true

local MarkedForCollapse = {}

function ModUtil.InvertTable( Table )
    local inverseTable = {}
    for _,value in ipairs(tableArg) do
        inverseTable[value]=true
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

function ModUtil.CollapseMarked()
	for k,v in pairs(MarkedForCollapse) do
		k = CollapseTable(k)
	end
	MarkedForCollapse = {}
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
			if SetVal == nil and unkeyed then
				ModUtil.MarkForCollapse(InTable)
			end
		end
	end
end
