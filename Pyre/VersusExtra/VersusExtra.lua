ModUtil.RegisterMod( "VersusExtra" )

local config = {
	TeamA = {
		{
			Base = 1,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 2,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 20,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
	},
	TeamB = {
		{
			Base = 8,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 11,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 4,
			Bench = nil,
			NilTable = {},
			SetTable = {},
		},
	},
}
VersusExtra.config = config

local TeamExpansion = true
ModUtil.WrapBaseFunction( "PrepareLocalMPDraft", function(baseFunc, TeamAid, TeamBid )
	if TeamExpansion then
		local TeamAbench = League[TeamAid].TeamBench
		local TeamBbench = League[TeamBid].TeamBench
		local nA = #TeamAbench
		local nB = #TeamBbench
		for i,v in ipairs(config.TeamA) do
			local bench = TeamAbench
			if v.Bench then bench = League[v.Bench].TeamBench end
			local character = DeepCopyTable(bench[v.Base])
			ModUtil.MapNilTable(character,v.NilTable)
			ModUtil.MapSetTable(character,v.SetTable)
			character.CharacterIndex = nA+i
			TeamAbench[character.CharacterIndex] = character
		end
		for i,v in ipairs(config.TeamB) do
			local bench = TeamBbench
			if v.Bench then bench = League[v.Bench].TeamBench end
			local character = DeepCopyTable(bench[v.Base])
			ModUtil.MapNilTable(character,v.NilTable)
			ModUtil.MapSetTable(character,v.SetTable)
			character.CharacterIndex = nB+i
			TeamBbench[character.CharacterIndex] = character
		end
	end
	TeamExpansion = false
	return baseFunc( TeamAid, TeamBid )
end, VersusExtra)

ModUtil.WrapBaseFunction( "DisplayDraftScreen", function(baseFunc )
    local ret = baseFunc()
    SetMenuOptions({ Name = "RosterScreen", Item = "YButton", Properties = {OffsetY = 400} })
    return ret
end, VersusExtra)

ModUtil.WrapBaseFunction( "ViewTeam", function(baseFunc, team )
	local ret = baseFunc(team)
	SetMenuOptions({ Name = "RosterScreen", Item = "YButton", Properties = {OffsetY = 400} })
	return ret
end, VersusExtra)