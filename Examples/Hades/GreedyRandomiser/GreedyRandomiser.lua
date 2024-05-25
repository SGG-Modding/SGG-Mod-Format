ModUtil.Mod.Register( "GreedyRandomiser" )
-- Boon choice randomiser implemented a greedy way, likely to have bugs and incompatibilities

local loot, gift = { }, { }
for k, v in pairs( LootData ) do
	if v.GodLoot and not v.DebugOnly then
	  ModUtil.Table.Merge( loot, v )
	  ModUtil.Table.Merge( gift, GiftData[ k ] )
	end
end
LootData.RandomUpgrade = loot
GiftData.RandomUpgrade = gift

ModUtil.Path.Wrap( "CreateBoonLootButtons", function( base, lootData, ... )
  if LootData[ lootData.Name ].GodLoot and not LootData[ lootData.Name ].DebugOnly then
    ModUtil.Table.Merge( LootData.RandomUpgrade, LootData[ lootData.Name ] )
    ModUtil.Table.Merge( GiftData.RandomUpgrade, GiftData[ lootData.Name ] )
    lootData.Name = "RandomUpgrade"
  end
  return base( lootData, ... )
end, GreedyRandomiser )
