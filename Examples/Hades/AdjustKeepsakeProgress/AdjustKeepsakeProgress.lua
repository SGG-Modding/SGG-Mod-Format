ModUtil.RegisterMod( "AdjustKeepsakeProgress" )

local config = {
    -- Write any expression you want for the new keepsake progress to increase by
    Adjustment = " ... + 1 " 
    -- "..." is the amount the progress increases by normally
}

AdjustKeepsakeProgress.Config = setmetatable( { }, { 
    __index = config,
    __newindex = function( _, key, value )
        config[ key ] = value
        if key == "Adjustment" then
            AdjustKeepsakeProgress.GenerateAdjustmentFunction( )
        end
    end
} )

function AdjustKeepsakeProgress.GenerateAdjustmentFunction( )
    AdjustKeepsakeProgress.AdjustmentFunction = load( "local _ENV = { }; return " .. AdjustKeepsakeProgress.Config.Adjustment )
end

AdjustKeepsakeProgress.Config.Adjustment = config.Adjustment

ModUtil.WrapBaseFunction( "IncrementTableValue", function( baseFunc, tbl, key, amount, ... )
    if tbl and tbl == ModUtil.PathGet( "GameState.KeepsakeChambers" ) then
        DebugPrint{ Text = " INFO@AdjustKeepsakeProgress: Adjusted keepsake progress for " .. key .. " as: " .. AdjustKeepsakeProgress.Config.Adjustment }
        return baseFunc( tbl, key, AdjustKeepsakeProgress.AdjustmentFunction( amount or 1 ) )
    end
    return baseFunc( tbl, key, amount, ... )
end, AdjustKeepsakeProgress )