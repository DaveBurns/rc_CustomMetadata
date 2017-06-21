--[[
        ExtendedUpdater.lua
        
        Note: this could encapsulate check-for-update and uninstall too, but doesn't, yet.
              Main idea is for plugin hook to extend without extending app object.
--]]


local ExtendedUpdater, dbg, dbgf = Updater:newClass{ className= 'ExtendedUpdater', register=true }



--- Constructor for extending class.
--
--  @param      t       initial table - optional.
--
function ExtendedUpdater:newClass( t )
    return Updater.newClass( self, t )
end



--- Constructor for new instance object.
--      
--  @param      t       initial table - optional.
--
--  @usage      construct enhanced updater with custom copy and/or purge exclusion lists.<br>
--              exclusions are lua regex patterns, and will be applied to sub-path relative to lrplugin dir.
--
function ExtendedUpdater:new( t )
    local copyExcl = nil -- nothing universally excluded
    local purgeExcl = nil -- table of purge exclusions, or nil for default ("Preferences/*" are excluded by default).
    local o = Updater.new( self, { copyExcl=copyExcl, purgeExcl=purgeExcl } )
    return o
end



function ExtendedUpdater:isCopyExcluded( subPath )
    local targ = LrPathUtils.child( self.target, subPath )
    local fn = LrPathUtils.leafName( targ )
    if fn == 'Info.lua' then
        if self.me ~= self.src then
            return true -- don't overwrite metadata.lua file if it already exists in the target - handle as special migration.
        end
    elseif fn == 'Metadata.lua' then
        --if fso:existsAsFile( targ ) then
        --    return true -- don't overwrite metadata.lua file if it already exists in the target - handle as special migration.
        --end
        if self.me ~= self.src then
            return true
        end
    end
    return false
end



--- Migrate special plugin files.
--
--  @usage  self-me is -plugin-path, self-src is source path of update (lrplugin folder), self-target is update target (lrplugin path) in modules folder.
--
function ExtendedUpdater:migrateSpecials()
    local errs = 0
    if self.me ~= self.src then -- info.lua was not copied.
        app:log( "Migrating info.lua file." )
        local infoMe = LrPathUtils.child( self.me, "Info.lua" ) -- will exist.
        local infoTarg = LrPathUtils.child( self.target, "Info.lua" ) -- may or may not exist
        local infoSrc = LrPathUtils.child( self.src, "Info.lua" ) -- will exist and be different than me.
        if fso:existsAsFile( infoMe ) then
            local sf, infoLuaMe = pcall( dofile, infoMe )
            local st, infoLuaSrc = pcall( dofile, infoSrc )
            if sf then
                if st then
                    if infoLuaMe.LrToolkitIdentifier ~= infoLuaSrc.LrToolkitIdentifier then
                        local c, m = fso:readFile( infoSrc )
                        if c then
                            -- we have the source data
                            assert( type( c )=='string', "c not string" )
                            assert( type( infoLuaSrc.LrToolkitIdentifier )=='string', "infoLuaSrc.LrToolkitIdentifier not string" )
                            assert( type( infoLuaMe.LrToolkitIdentifier )=='string', "infoLuaMe.LrToolkitIdentifier not string" )
                            local s1 = infoLuaSrc.LrToolkitIdentifier:gsub( "%.", "%." ) -- escape dot characters.
                            local newC, subs = c:gsub( "LrToolkitIdentifier%s*=%s*[\'\"]" .. s1 .. "[\'\"]", "LrToolkitIdentifier = '" .. infoLuaMe.LrToolkitIdentifier .. "'" )
                            if subs > 0 then
                                local s, m = fso:writeFile( infoTarg, newC )
                                if s then
                                    app:log( "^1 written.", infoTarg )
                                    app:log( "LrToolkitIdentifier migrated from ^1, so it remains '^2'", infoMe, infoLuaMe.LrToolkitIdentifier )
                                else
                                    app:logErr( "Unable to write Info.lua, error message: ", m )
                                    errs = errs + 1
                                end
                            else
                                app:logErr( "Unable to migrate LrToolkitIdentifier from previous plugin - please report problem and update plugin manually for now." )
                                errs = errs + 1
                            end
                        else
                            app:logErr( "Unable to read Info.lua file: ^1 - please report problem and update plugin manually for now.", infoTarg )
                            errs = errs + 1                
                        end
                    else
                        local s, m = fso:copyFile( infoSrc, infoTarg, true, true )
                        if s then
                            app:log( "LrToolkitIdentifier has not changed (^1) - previous metadata will be supported by updated plugin.", infoLuaMe.LrToolkitIdentifier )
                        else
                            app:logErr( "Unable to copy Info.lua file, error message: ", m )
                            errs = errs + 1                
                        end
                    end
                else
                    app:logErr( "Unable to parse Info.lua to file: ^1 - please report problem and update plugin manually for now.", infoTarg )
                    errs = errs + 1                
                end                
            else
                app:logErr( "Unable to parse Info.lua from file: ^1 - please report problem and update plugin manually for now.", infoMe )
                errs = errs + 1                
            end                
        else
            app:logErr( "Info file does not exist: ^1", infoMe )
            errs = errs + 1
        end
    -- else if I am the source, my info file should be OK
    end
    if self.me ~= self.target and self.me ~= self.src then
        local metaDefFrom = LrPathUtils.child( self.me, "Metadata.lua" )
        local metaDefTo = LrPathUtils.child( self.target, "Metadata.lua" )
        if fso:existsAsFile( metaDefFrom ) then
            local s, m = fso:copyFile( metaDefFrom, metaDefTo, false, true )
            if s then
                app:log( "Copied ^1 to ^2", metaDefFrom, metaDefTo )
            else
                app:logErr( "Unable to copy metadata def file, error message: ^1", m )
                errs = errs + 1
            end
        else
            app:logErr( "Metadata def file does not exist: ^1", metaDefFrom )
            errs = errs + 1
        end
    else
        app:log( "Migrating metadata.lua file is not deemed necessary." )
    end
    return errs
end



return ExtendedUpdater
