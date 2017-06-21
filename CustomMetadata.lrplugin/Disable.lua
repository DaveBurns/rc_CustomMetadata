--[[
        Disable.lua
--]]

if rawget( _G, 'app' ) then
    app:logInfo( "Your custom metadata has been disabled and shan't be available until plugin is re-enabled." )
end
