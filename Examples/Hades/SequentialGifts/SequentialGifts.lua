ModUtil.Mod.Register( "SequentialGifts" )

ModUtil.Path.Wrap( "CanReceiveGift", function( base, npcData, ... )
	local name = GetGenusName( npcData )
	local record = CurrentRun.GiftRecord[ name ]
	CurrentRun.GiftRecord[ name ] = false
	local ret = table.pack( base( npcData, ... ) )
	CurrentRun.GiftRecord[ name ] = CurrentRun.GiftRecord[ name ] or record
	return table.unpack( ret )
end, SequentialGifts )