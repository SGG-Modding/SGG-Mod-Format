ModUtil.RegisterMod( "VersusExtra" )

local config = {
	TeamA = {
		{
			Base = 1,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 2,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 20,
			NilTable = {},
			SetTable = {},
		},
	},
	TeamB = {
		{
			Base = 8,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 11,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 4,
			NilTable = {},
			SetTable = {},
		},
	},
}

local TeamExpansion = true

ModUtil.WrapBaseFunction( "PrepareLocalMPDraft", function(baseFunc, TeamAid, TeamBid )
	if TeamExpansion then
		local TeamAbench = League[TeamAid].TeamBench
		local TeamBbench = League[TeamBid].TeamBench
		local nA = #TeamAbench
		local nB = #TeamBbench
		for i,v in ipairs(config.TeamA) do
			local character = DeepCopyTable(TeamAbench[v.Base])
			ModUtil.MapNilTable(character,v.NilTable)
			ModUtil.MapSetTable(character,v.SetTable)
			character.CharacterIndex = nA+i
			TeamAbench[nA+i] = character
		end
		for i,v in ipairs(config.TeamB) do
			local character = DeepCopyTable(TeamBbench[v.Base])
			ModUtil.MapNilTable(character,v.NilTable)
			ModUtil.MapSetTable(character,v.SetTable)
			character.CharacterIndex = nB+i
			TeamBbench[nB+i] = character
		end
	end
	TeamExpansion = false
	return baseFunc( TeamAid, TeamBid )
end, VersusExtra)
