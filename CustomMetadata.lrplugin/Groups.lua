--[[
        Groups.lua
--]]


local Groups, dbg, dbgf = Object:newClass{ className='Groups', register=true }



--- Constructor for extending class.
--
function Groups:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Groups:new( t )
    local o = Object.new( self, t )
    return o
end



function Groups:_init( call )

    self.call = call

    self.groupFieldId = app:getPref( 'groupFieldId' )
    if not str:is( self.groupFieldId ) then
        app:show{ warning="Group feature not implemented/configured." }
        call:cancel()
        return
    end

    local photos = cat:getFilmstripPhotos( app:getPref( "includeSubfolders" ), app:getPref( "ignoreIfBuried" ) )
    if photos == nil or #photos == 0 then
        if dia:isOk( "No photos found in active sources (its not an exact science...) - consider all photos in catalog?" ) then
            photos = catalog:getAllPhotos()
            if photos == nil or #photos == 0 then
                app:show{ warning="No photos in catalog." }
                call:cancel()
                return
            end
        else
            call:cancel()
            return
        end
    end
    self.filmstrip = photos
    
    local g, m = self:_read()
    if not g then
        if self.call:isCanceled() then
            return
        else
            app:error( m )
        end
    end
    self.g = g
    -- Debug.lognpp( g )
end



--- Get unique ID for group, from name and rep.
--
function Groups:_getGroupId( gName, repId )
    assert( str:is( gName ), "bad gname" )
    assert( str:is( repId ), "bad id" )
    return gName .. '_' .. repId
end



--  g is lookup table indexed by photo, elements are also lookup tables, indexed by group name, whose elements contain named group fields:
--
--      name, rep, id, type
--
--  @return groupId
--  @return groupSpec
--  @return message
--
function Groups:_prompt( tidbit, includeType, returnIfNoGroups )
    local groupId
    local groupSpec
    local s, m = app:call( Call:new{ name="Prompt for group specification", async=false, main=function( call )
        local gViewItem
        local tViewItem
        local g = self.g
        
        local props = LrBinding.makePropertyTable( call.context )
        
        local groupNameItems = {}
        local groupTypeItems = {}
        
        local gL = {}
        local tL = {}

        for photo, v in pairs( g ) do
            --Debug.logn( photo, v )
            for name, spec in pairs( v ) do
                local gId = self:_getGroupId( spec.name, spec.id )
                gL[gId] = spec
                if spec.type then
                    tL[spec.type] = true
                end
            end
        end

        local rL = {}        
        for gId, spec in pairs( gL ) do
            if rL[spec.name] == nil then
                groupNameItems[#groupNameItems + 1] = spec.name
                rL[spec.name] = spec
            else
                local photo = catalog:findPhotoByUuid( spec.id )
                local photoName = photo:getFormattedMetadata( 'fileName' )
                local rn = str:fmt( "^1 (^2)", spec.name, photoName )
                if rL[rn] == nil then
                    groupNameItems[#groupNameItems + 1] = rn
                    rL[rn] = spec
                else
                    app:logWarning( "Duplicate: " .. rn )
                end
            end
        end
        for typ, v in pairs( tL ) do
            groupTypeItems[#groupTypeItems + 1] = typ
        end
        
        if #groupNameItems > 0 then
            gViewItem = vf:combo_box {
                bind_to_object = props,
                value = bind 'groupName',
                width_in_chars = 20,
                items = groupNameItems,
                immediate = true, -- required for text entry to work
            }
        else
            if returnIfNoGroups then
                return
            end
            gViewItem = vf:edit_field {
                bind_to_object = props,
                value = bind 'groupName',
                width_in_chars = 20,
            }
        end
        
        if #groupTypeItems > 0 then
            tViewItem = vf:combo_box {
                bind_to_object = props,
                value = bind 'groupType',
                width_in_chars = 20,
                items = groupTypeItems,
                immediate = true, -- required for text entry to work
            }
        else
            tViewItem = vf:edit_field {
                bind_to_object = props,
                value = bind 'groupType',
                width_in_chars = 20,
            }                
        end
        
        local viewItems = {}
        local subtitle
        if includeType then
            subtitle = str:fmt( "Enter group name and type for ^1", tidbit )
        else
            subtitle = str:fmt( "Enter group name for ^1", tidbit )
        end
        viewItems[#viewItems + 1] =
            vf:row {
                vf:static_text {
                    title = subtitle
                },
            }
        viewItems[#viewItems + 1] = vf:spacer { height = 20 }
        viewItems[#viewItems + 1] =
            vf:row {
                vf:static_text {
                    title = "Group name",
                    width = share 'labels',
                },
                gViewItem,
            }
        local title
        if includeType then
            viewItems[#viewItems + 1] =
                vf:row {
                    vf:static_text {
                        title = "Group type",
                        width = share 'labels',
                    },
                    tViewItem,
                }
            title = "Select or enter group name & type"
        else
            title = "Select or enter group name"
        end
        viewItems[#viewItems + 1] = vf:spacer { height = 20 }
        viewItems[#viewItems + 1] = vf:separator { fill_horizontal = 1 }
        
        
        local args = {}
        args.title = title
        args.contents = vf:view( viewItems )
        local answer
        
        repeat
            answer = LrDialogs.presentModalDialog( args )
            if answer == 'ok' then
                local groupRef = props['groupName']
                local groupType = props['groupType'] -- may be nil
                if str:is( groupRef ) then
                    groupSpec = rL[groupRef]
                    if groupSpec == nil then
                        groupSpec = { name=groupRef, type=groupType } -- ref will be true (new) name in this case.
                        groupId = nil
                    else
                        if not str:is( groupSpec.type ) or str:is( groupType ) then
                            groupSpec.type = groupType
                        end
                        assert( str:is( groupSpec.name ), "bad spec name" )
                        groupId = self:_getGroupId( groupSpec.name, groupSpec.id )
                    end
                    break
                else
                    app:show{ warning="Group name must not be blank." }
                end
            elseif answer == 'cancel' then
                self.call:cancel()
                break
            else
                app:error( "bad answer" )
            end
        until false
        
    end } )
    if s then
        return groupId, groupSpec
    else
        return nil, nil, m
    end
end



--  returns lookup table indexed by photo, elements are also lookup tables, indexed by group name, whose elements contain named group fields:
--
--      name, rep, id, type
--
function Groups:_read()
    local g = {}
    local message = nil
    LrFunctionContext.callWithContext( "Read group info", function( context )
        local scope = LrProgressScope {
            title = "Gathering group info",
            caption = "Please wait",
            functionContext = context,
        }
        local photos = self.filmstrip
        local bp = catalog:batchGetPropertyForPlugin( photos, _PLUGIN.id, { self.groupFieldId } )
        local yc = 0
        for i, photo in ipairs( photos ) do
            scope:setPortionComplete( i, #photos )
            if scope:isCanceled() then
                self.call:cancel()
                g = nil
                return
            end
            yc = app:yield( yc )
            local gPhoto = {}
            -- local gMeta = photo:getPropertyForPlugin( _PLUGIN, self.groupFieldId, nil, true )
            local gMeta = bp[photo][self.groupFieldId]
            if gMeta ~= nil then
                local p = str:split( gMeta, "\n" ) -- will split cr/lf too, and trim cr as whitespace.
                local gProps = {}
                local grp = {}
                for i, v in ipairs( p ) do
                    if str:is( v ) then
                        local pa = str:split( v, "=" )
                        if #pa > 0 then
                            gProps[#gProps + 1] = pa
                        end
                    else -- separator
                        if #gProps > 0 then
                            --dbg( "new grp" )
                            grp[#grp + 1] = gProps
                            gProps = {}
                        end
                    end
                end
                if #gProps > 0 then
                    --dbg( "last grp" )
                    grp[#grp + 1] = gProps
                end
                for i, v in ipairs( grp ) do -- traverse groups
                    --dbg( "grp", i )
                    local gg = {}
                    for i2, v2 in ipairs( v ) do  -- traverse group properties
                        --Debug.lognpp( v2 )
                        gg[v2[1]] = v2[2] -- assign property lookup
                    end
                    if str:is( gg.name ) and str:is( gg.id ) then
                        local gId = self:_getGroupId( gg.name, gg.id )
                        if gPhoto[gId] then
                            app:logWarning( "Duplicate group: ^1 for photo: ^2", gId, photoPath )
                        else
                            gPhoto[gId] = gg
                        end
                    end
                end
                if not tab:isEmpty( gPhoto ) then
                    g[photo] = gPhoto
                end
            -- else this is normal when using batch mode and field is blank.
            end
        end
    end )
    return g, message
end



function Groups:_ungroup( photos, groupId, scope )
    local g = self.g
    local rawMeta = cat:getBatchRawMetadata( photos, { 'path' } )
    for i, photo in ipairs( photos ) do
        repeat
            local photoPath = rawMeta[photo].path
            local gPhoto = g[photo]
            if gPhoto == nil then
                gPhoto = {}
            end
            if gPhoto[groupId] then
                app:log( "^1 removed from group", photoPath )
            else
                --app:logVerbose( "^1 not in group", photoPath )
                break
            end
            gPhoto[groupId] = nil
            
            local b = {}
            for k, gp in pairs( gPhoto ) do
                b[#b + 1] = str:fmt( "name=^1\r\nrep=^2\r\nid=^3\r\ntype=^4", gp.name, gp.rep, gp.id, gp.type )
            end
            local s = table.concat( b, "\r\n\r\n" )
            --Debug.lognpp( s )
            local chg, errm = custMeta:update( photo, self.groupFieldId, s, nil, true )
            if chg ~= nil then
                -- Debug.pause( chg )
            else
                app:logErr( m )
            end
            
        until true
        
        scope:setPortionComplete( i, #photos )
        
    end
    
    scope:setPortionComplete( 1, 1 )
    LrTasks.yield()
    
end



function Groups:_getPhotosInGroup( groupId, scope )

    local photos = self.filmstrip
    local g = self.g
    local selPhotos = {}

    local repPhoto
    
    --local rawMeta = cat:getBatchRawMetadata( photos, { 'path' } ) -- overkill since its only used when duplicate rep.
    
    for i, photo in ipairs( photos ) do
        repeat
            
            local gPhoto = g[photo]
            if gPhoto == nil then
                break
            end
            
            if gPhoto[groupId] then
                selPhotos[#selPhotos + 1] = photo
                if gPhoto[groupId].rep == 'me' then
                    if repPhoto == nil then
                        repPhoto = photo
                    else
                        -- app:logWarning( "Duplicate representative: ^1 for group: ^2", rawMeta[photo].path, groupId )
                        app:logWarning( "Duplicate representative: ^1 for group: ^2", photo:getRawMetadata( 'path' ), groupId )
                    end 
                end
            end 
            
        until true
        
        scope:setPortionComplete( i, #photos )
            
    end
    
    scope:setPortionComplete( 1, 1 )
    LrTasks.yield()

    return repPhoto, selPhotos

end



-- def means defines group - remove all others not in group.
function Groups:group( def )
    app:call( Service:new{ name="Define a Photo Group", async=true, guard=App.guardVocal, main=function( call )
    
        self:_init( call )

        local g = self.g

        local groupId, groupSpec, m = self:_prompt( "grouping", true )
        if self.call:isCanceled() then
            return
        elseif m then
            app:show{ error=m }
            self.call:cancel()
            return
        -- else its OK if no groupId when defining a group.
        end
        local groupName = groupSpec.name
        local groupType = groupSpec.type -- may be nil

        local mostSelPhoto = catalog:getTargetPhoto()
        local mostSelPath = mostSelPhoto:getRawMetadata( 'path' )
        local mostSelName = LrPathUtils.leafName( mostSelPath )
        local mostSelId = mostSelPhoto:getRawMetadata( 'uuid' )
        
        local defPhotos = cat:getSelectedPhotos()
        local undefPhotos
        if def then
            if groupId then -- user is redefining an existing group
                app:log( "Redefining selected group: ^1 - ^2 (^3)", groupName, groupType, groupSpec.rep )
                local lookup = {}
                for i, photo in ipairs( defPhotos ) do
                    lookup[photo] = true
                end
                undefPhotos = {}
                for i, photo in ipairs( self.filmstrip ) do
                    if not lookup[ photo ] then
                        undefPhotos[#undefPhotos + 1] = photo
                    end
                end
            else
                app:log( "Defining a new group: ^1 - ^2", groupName, groupType )
            end
        else
            if groupId then
                app:log( "Adding to an existing group: ^1 - ^2", groupName, groupType )
                mostSelPhoto = nil
            else
                app:log( "Adding to a non-existing group, which is the equivalent of defining a group: ^1 - ^2", groupName, groupType )
            end
        end
        
        local scope = LrProgressScope {
            title = "Defining group",
            caption = str:fmt( "^1 - ^2", groupName, groupType ),
            functionContext = call.context,
        }
        
        local s, m = cat:updatePrivate( 20, function( context, phase )
            for i, photo in ipairs( defPhotos ) do -- should be relatively small set of photos (single phase should be fine). ###3
                repeat
                    local gPhoto = g[photo]
                    if gPhoto == nil then
                        gPhoto = {}
                    end
                    local gto
                    if photo == mostSelPhoto then
                        gto = { name=groupName, rep='me', id=mostSelId, type=groupType }
                    else
                        gto = { name=groupName, rep=mostSelName, id=mostSelId, type=groupType }
                    end
                    local newGroupId = self:_getGroupId( gto.name, gto.id )
                    if groupId ~= nil and groupId ~= newGroupId then
                        gPhoto[groupId] = nil -- kill previous definition
                    end
                    if gPhoto[newGroupId] then
                        -- dbg( "updating group", newGroupId )
                    else
                        -- dbg( "new group", newGroupId )
                    end
                    gPhoto[newGroupId] = gto
                    
                    local b = {}
                    for k, gp in pairs( gPhoto ) do
                        if str:is( gp.type ) then
                            b[#b + 1] = str:fmt( "name=^1\r\nrep=^2\r\nid=^3\r\ntype=^4", gp.name, gp.rep, gp.id, gp.type )
                        else
                            b[#b + 1] = str:fmt( "name=^1\r\nrep=^2\r\nid=^3", gp.name, gp.rep, gp.id )
                        end
                    end
                    local s = table.concat( b, "\r\n\r\n" )
                    --Debug.lognpp( s )
                    local chg, errm = custMeta:update( photo, self.groupFieldId, s, nil, true )
                    if chg ~= nil then
                        -- Debug.pause( chg )
                    else
                        app:logErr( m )
                    end
                    
                until true
                scope:setPortionComplete( i, #defPhotos )
            end
            if undefPhotos then -- groupId is not nil
                local rawMeta = cat:getBatchRawMetadata( undefPhotos, { 'uuid', 'path' } )
                for i, photo in ipairs( undefPhotos ) do
                    local path = rawMeta[photo].path
                    local uuid = rawMeta[photo].uuid
                    -- Debug.logn( i, LrPathUtils.leafName( path ) )
                    repeat
                        local gPhoto = g[photo]
                        if gPhoto == nil then
                            gPhoto = {}
                        end
                        local b = {}
                        local removed = false
                        for k, gp in pairs( gPhoto ) do
                            local rep = gp.id
                            if gp.rep == 'me' then
                                rep = uuid
                            end
                            local testGroupId = self:_getGroupId( gp.name, rep )
                            if groupId ~= testGroupId then
                                app:logVerbose( "Not removing photo from group, groupId: ^1, testGroupId: ^2", groupId, testGroupId )
                                if str:is( gp.type ) then
                                    b[#b + 1] = str:fmt( "name=^1\r\nrep=^2\r\nid=^3\r\ntype=^4", gp.name, gp.rep, gp.id, gp.type )
                                else
                                    b[#b + 1] = str:fmt( "name=^1\r\nrep=^2\r\nid=^3", gp.name, gp.rep, gp.id )
                                end
                            else
                                app:logVerbose( "Removing photo ^1 from group ^2 (rep: ^3) - group-id:", path, groupName, gp.rep, groupId )
                                removed = true
                            end
                        end
                        if not removed then
                            break -- no point in updating metadata if nothing changed.
                        end
                        local s = table.concat( b, "\r\n\r\n" )
                        --Debug.lognpp( s )
                        local chg, errm = custMeta:update( photo, self.groupFieldId, s, nil, true )
                        if chg ~= nil then
                            -- Debug.pause( chg )
                        else
                            app:logErr( m )
                        end
                        
                    until true
                    scope:setPortionComplete( i, #undefPhotos )
                end
            end
        end )
        
        --Debug.showLogFile()
        
        if not s then
            scope:setCaption( m )
            app:error( m )
        else
            scope:setPortionComplete( 1, 1 )
            scope:setCaption( "finished" )
        end
    
    end } )
end



-- remove selected photos from group
function Groups:removeFromGroup()
    app:call( Service:new{ name="Remove selected photos from group", async=true, guard=App.guardVocal, main=function( call )
    
        self:_init( call )
        
        local groupId, groupSpec, m = self:_prompt( "ungrouping" )
        if self.call:isCanceled() then
            return
        elseif m then
            app:show{ error=m }
            self.call:cancel()
            return
        elseif not groupId then
            app:show{ warning="None of the photos in the currently active sources are in a group." }
            self.call:cancel() -- not really a cancellation... ###3
            return
        end
        local groupName = groupSpec.name
        local groupType = groupSpec.type

        local photos = cat:getSelectedPhotos()
        
        local s, m = cat:updatePrivate( 20, function( context, phase )
            local scope = LrProgressScope {
                title = "Removing selected photos from group",
                caption = str:fmt( "^1 - ^2", groupName, groupType ),
                functionContext = context,
            }
            
            self:_ungroup( photos, groupId, scope )
            
        end )
        
        --Debug.showLogFile()
        
        if not s then
            app:error( m )
        end
    
    end } )
end



function Groups:select()
    app:call( Service:new{ name="Select a Photo Group", async=true, guard=App.guardVocal, main=function( call )

        self:_init( call )
        
        local groupId, groupSpec, m = self:_prompt( "selection", false, true ) -- false => don't include type, true => return if no groups
        if self.call:isCanceled() then
            return
        elseif m then
            app:show{ error=m }
            self.call:cancel()
            return
        elseif not groupId then
            app:show{ warning="None of the photos in the currently active sources are in a group." }
            self.call:cancel() -- not really a cancellation... ###3
            return
        end
        local groupName = groupSpec.name
        local groupType = groupSpec.type

        local scope = LrProgressScope {
            title = "Selecting photos in group",
            caption = str:fmt( "^1 - ^2", groupName, groupType ),
            functionContext = call.context,
        }
        
        local repPhoto, selPhotos = self:_getPhotosInGroup( groupId, scope ) -- based on flimstrip photos
        
        if #selPhotos > 0 then
            local mostSelPhoto
            local tidbit = ""
            if repPhoto == nil then
                mostSelPhoto = selPhotos[1]
                app:show{ warning="Representative photo not found for group '^1' - selecting first photo instead.", groupName }
            else
                mostSelPhoto = repPhoto
                tidbit = " - representative photo is most selected"
            end
            local s, m = cat:setSelectedPhotos( mostSelPhoto, selPhotos )
            if s then
                app:show{ info="Group '^1' photos should be selected now^2.", groupName, tidbit, actionPrefKey = "Group selected prompt" }
            else
                app:show{ warning="Unable to select all photos in '^1' group.", groupName }
            end
        else
            app:show{ warning="No photos found to select in group '^1'.", groupName }
        end
        
        --Debug.showLogFile()
        
    end } )
end



-- remove all photos from group
function Groups:delete()
    app:call( Service:new{ name="Delete a Photo Group", async=true, guard=App.guardVocal, main=function( call )
    
        self:_init( call )
    
        local groupId, groupSpec, m = self:_prompt( "deletion", false, true ) -- false => don't include type, true => return if no groups
        if self.call:isCanceled() then
            return
        elseif m then
            app:show{ error=m }
            self.call:cancel()
            return
        elseif not groupId then
            app:show{ warning="None of the photos in the currently active sources are in a group." }
            self.call:cancel() -- not really a cancellation... ###3
            return
        end
        local groupName = groupSpec.name
        local groupType = groupSpec.type

        local scope = LrProgressScope {
            title = "Deleting a group",
            caption = str:fmt( "^1 - ^2", groupName, groupType ),
            functionContext = call.context,
        }
        
        local repPhoto, grpPhotos = self:_getPhotosInGroup( groupId, scope ) -- based on filmstrip
        
        if #grpPhotos > 0 then
            local s, m = cat:updatePrivate( 20, function( context, phase )
            
                scope:setCaption( "finalizing" )
                self:_ungroup( grpPhotos, groupId, scope ) -- sets portion complete
                
            end )
            
            --Debug.showLogFile()
            
            if not s then
                scope:setCaption( m )
                app:error( m )
            else
                scope:setPortionComplete( 1, 1 )
                scope:setCaption( "finished" )
            end
        else
            app:show{ warning="No photos found to delete in group '^1'.", groupName }
        end
        
        --Debug.showLogFile()
        
    end } )

end



function Groups:collect()
    app:call( Service:new{ name="Collect a Photo Group", async=true, guard=App.guardVocal, main=function( call )

        self:_init( call )    
        
        local groupId, groupSpec, m = self:_prompt( "deletion", false, true ) -- false => don't include type, true => return if no groups
        if self.call:isCanceled() then
            return
        elseif m then
            app:show{ error=m }
            self.call:cancel()
            return
        elseif not groupId then
            app:show{ warning="None of the photos in the currently active sources are in a group." }
            self.call:cancel() -- not really a cancellation... ###3
            return
        end
        local groupName = groupSpec.name
        local groupType = groupSpec.type

        local scope = LrProgressScope {
            title = "Collecting photos in group",
            caption = str:fmt( "^1 - ^2", groupName, groupType ),
            functionContext = call.context,
        }
        
        local repPhoto, selPhotos = self:_getPhotosInGroup( groupId, scope ) -- based on filmstrip photos

        local coll = cat:assurePluginCollection( "Quick Group" ) -- error if no can do.
        
        local s, m = cat:update( 20, "Collecting group", function( context, phase )
            coll:removeAllPhotos()
        end )
        if not s then
            app:error( m )
        end
        
        if #selPhotos > 0 then
        
            scope:setPortionComplete( 0, 1 )
            scope:setCaption( "finalizing" )
                
            if s then
                s, m = cat:update( 20, "Collecting group", function( context, phase )
                    coll:addPhotos( selPhotos )
                end )
                if s then
                    catalog:setActiveSources{ coll }
                    cat:clearViewFilter( true ) -- no-yield/sleep.
                else
                end
            else
            end
            
            --Debug.showLogFile()
            
            if not s then
                scope:setCaption( m )
                app:error( m )
            else
                scope:setPortionComplete( 1, 1 )
                scope:setCaption( "finished" )
            end
        else
            app:show{ warning="No photos found to collect in group '^1'.", groupName }
        end
        
        --Debug.showLogFile()
        
    end } )

end



return Groups