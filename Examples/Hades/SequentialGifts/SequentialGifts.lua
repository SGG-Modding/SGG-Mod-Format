ModUtil.RegisterMod( "SequentialGifts" )

ModUtil.WrapBaseFunction( "CanReceiveGift", function( baseFunc, npcData, ... )
	local name = GetGenusName( npcData )
	local record = CurrentRun.GiftRecord[ name ]
	CurrentRun.GiftRecord[ name ] = false
	local ret = table.pack( baseFunc( npcData, ... ) )
	CurrentRun.GiftRecord[ name ] = CurrentRun.GiftRecord[ name ] or record
	return table.unpack( ret )
end, SequentialGifts )