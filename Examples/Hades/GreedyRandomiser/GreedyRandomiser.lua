ModUtil.RegisterMod( "GreedyRandomiser" )
-- Boon choice randomiser implemented a greedy way, likely to have bugs and incompatibilities

local loot, gift = { }, { }
for k, v in pairs( LootData ) do
	if v.GodLoot and not v.DebugOnly then
	  ModUtil.MapSetTable( loot, v )
	  ModUtil.MapSetTable( gift, GiftData[ k ] )
	end
end
LootData.RandomUpgrade = loot
GiftData.RandomUpgrade = gift

ModUtil.WrapBaseFunction( "CreateBoonLootButtons", function( baseFunc, lootData, ... )
  if LootData[ lootData.Name ].GodLoot and not LootData[ lootData.Name ].DebugOnly then
    ModUtil.MapSetTable( LootData.RandomUpgrade, LootData[ lootData.Name ] )
    ModUtil.MapSetTable( GiftData.RandomUpgrade, GiftData[ lootData.Name ] )
    lootData.Name = "RandomUpgrade"
  end
  return baseFunc( lootData, ... )
end, GreedyRandomiser )
