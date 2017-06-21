--[[
        SpecialObjectFactory.lua
        
        Creates special objects used in the guts of the framework.
        
        This is what you edit to change the classes of non-global objects,
        that you have extended.
--]]
local SpecialObjectFactory, dbg, dbgf = ObjectFactory:newClass{ className = 'SpecialObjectFactory', register = false }


function SpecialObjectFactory:newClass( t )
    return ObjectFactory.newClass( self, t )
end

function SpecialObjectFactory:new( t )
    local o = ObjectFactory.new( self, t )
    return o
end

function SpecialObjectFactory:newObject( className, ... )
    if className == 'Manager' then
        return SpecialManager:new( ... )
    elseif className == 'ExportDialog' then
        return SpecialExport:newDialog( ... )
    elseif className == 'Export' then
        return SpecialExport:newExport( ... )
    else
        return ObjectFactory.newObject( self, className, ... )
    end
end

return SpecialObjectFactory 