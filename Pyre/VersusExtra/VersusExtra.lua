ModUtil.RegisterMod( "VersusExtra" )

local config = {
	TeamA = {
		BaseCount = 21,
		{
			Base = 20,
			Bench = 12,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 2,
			Bench = 11,
			NilTable = {},
			SetTable = {},
		},
		{
			Base = 8,
			Bench = 5,
			NilTable = {},
			SetTable = {},
		},
	},
}
config.TeamB = config.TeamA
VersusExtra.config = config

function VersusExtra.CopyCharacterTeamData( character, copyteam )
	character.MaskHue = copyteam.MaskHue 
	character.MaskSaturationAddition = copyteam.MaskSaturationAddition
	character.MaskValueAddition = copyteam.MaskValueAddition
	character.MaskHue2 = copyteam.MaskHue2
	character.MaskSaturationAddition2 = copyteam.MaskSaturationAddition2
	character.MaskValueAddition2 = copyteam.MaskValueAddition2
	character.UsePhantomShader = copyteam.UsePhantomShader
end

function VersusExtra.AddCharacter( addteam, data, index )
	local copyteam = League[data.Bench]
	local character = DeepCopyTable(copyteam.TeamBench[data.Base])
	
	VersusExtra.CopyCharacterTeamData( character, copyteam )
	
	ModUtil.MapNilTable(character,data.NilTable)
	ModUtil.MapSetTable(character,data.SetTable)
			
	if index == nil then
		index = #addteam.TeamBench + 1
	else
		for i = index, #addteam.TeamBench, 1 do
			addteam.TeamBench[i].CharacterIndex = addteam.TeamBench[i].CharacterIndex + 1
		end
	end
		
	character.TeamIndex = addteam.LeagueIndex
	character.CharacterIndex = index
	
	table.insert(addteam.TeamBench,character,index)
end

ModUtil.WrapBaseFunction( "PrepareLocalMPDraft", function(baseFunc, TeamAid, TeamBid )
	if #League[TeamAid].TeamBench == config.TeamA.BaseCount and #League[TeamAid].TeamBench == config.TeamA.BaseCount then
		local TeamA = League[TeamAid]
		local TeamB = League[TeamBid]
		for i = 1, #config.TeamA, 1 do
			local data = config.TeamA[i]
			if not data.Bench then data.Bench = TeamAid end
			VersusExtra.AddCharacter( TeamA, data )
		end
		for i = 1, #config.TeamB, 1 do
			local data = config.TeamB[i]
			if not data.Bench then data.Bench = TeamBid end
			VersusExtra.AddCharacter( TeamB, data )
		end
	end
	return baseFunc( TeamAid, TeamBid )
end, VersusExtra)

ModUtil.WrapBaseFunction( "DisplayDraftScreen", function(baseFunc, ...)
    local ret = baseFunc(...)
	if IsMultiplayerMatch() then
		SetMenuOptions({ Name = "RosterScreen", Item = "YButton", Properties = {OffsetY = 400} })
	end
    return ret
end, VersusExtra)

ModUtil.WrapBaseFunction( "ViewTeam", function(baseFunc, ...)
	local ret = baseFunc(...)
	if IsMultiplayerMatch() then
		SetMenuOptions({ Name = "RosterScreen", Item = "YButton", Properties = {OffsetY = 400} })
	end
	return ret
end, VersusExtra)
