--[[
        ExtendedExportFilter.lua
        
        Unlike most classes prefixed by the name "Extended...", this class is not (yet) extending the base export filter class.
        
        Still, one day there probably will be... ###3
--]]


local ExtendedExportFilter = {}

local dbg, dbgf = Object.getDebugFunction( 'ExtendedExportFilter' )



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExtendedExportFilter._updateFilterStatus( props, name, value )
    app:call( Call:new{ name="Update Filter Status", guard=App.guardSilent, main=function( context )
        local message = nil
        repeat
      	
      	    app:show( name )
      	
        	if name == 'blah' then
        	    if value then
        	        message = "Can't do it..."
        	        break
        	    end
        	--elseif
        	--else
    	    end
            
        until true	
    	if message then
    		-- Display error.
	        props.LR_cantExportBecause = message
    
    	else
    		-- All required fields and been populated so enable Export button, reset message and set error status to false.
	        props.LR_cantExportBecause = nil
	        
    	end
    end } )
end




--- This optional function adds the observers for our required fields metachoice and metavalue so we can change
--  the dialog depending if they have been populated.
--
function ExtendedExportFilter.startDialog( propertyTable )

	-- propertyTable:addObserver( 'LR_ui_enableMinimizeMetadata', ExtendedExportFilter._updateFilterStatus ) - cant watch for lr-props
	--ExtendedExportFilter._updateFilterStatus( propertyTable )

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExtendedExportFilter.sectionForFilterInDialog( f, propertyTable )
	
	return {
		title = app:getAppName(),
		f:row {
			f:static_text {
				title = "Assures custom metadata is transferred to exported photos.",
			},
		},
    }
	
end



ExtendedExportFilter.exportPresetFields = {
	-- { key = 'metadata', default = 'all' },
}



local warning1 = false
local warning2 = false
local custMetaTbl = nil
local maxWait


--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
function ExtendedExportFilter.shouldRenderPhoto( exportSettings, photo )

    if exportSettings.LR_reimportExportedPhoto then
        -- good
    else
        if not warning1 then
            app:logWarning( "*** Not being reimported into catalog - can't export." )
            app:show{ warning="Photos must be added to catalog to export with ^1 post-process action inline.", app:getAppName() }
            warning1 = true
        end
        return false
    end

    if custMetaTbl ~= nil then
        return true
    else
        if maxWait == nil then
            maxWait = app:getPref( 'maxWait' )
            if maxWait ~= nil then
                if type( maxWait ) == 'number' then
                    if maxWait < 3 then
                        app:logWarning( "Max wait seems too short." )
                    elseif maxWait > 360 then
                        app:logWarning( "Max wait seems excessive." )
                    end
                else
                    app:logErr( "Max wait must be number - defaulting to 60." )
                    maxWait = 60
                end
            else
                app:logWarning( "Max wait not configured - defaulting to 60." )
                maxWait = 60
            end
        end
    
        if not warning2 then
            custMetaTbl = app:getPref( 'exportCustomMetadata' )
            if custMetaTbl ~= nil then
                if type( custMetaTbl ) ~= 'table' then
                    custMetaTbl = nil
                    app:logWarning( "*** Custom metadata must be lua table - can't export." )
                    app:show{ warning="Custom metadata configured for transfer must be table to export with ^1 post-process action inline.", app:getAppName() }
                    warning2 = true
                end
            else
                app:logWarning( "*** Custom metadata must configured - can't export." )
                app:show{ warning="Custom metadata must be configured for transfer to export with ^1 post-process action inline.", app:getAppName() }
                warning2 = true
            end
        end
    end

    if custMetaTbl then    
        --Debug.lognpp( exportSettings )
        return true
    else
        return false
    end

end



--- Post process rendered photos.
--
function ExtendedExportFilter.postProcessRenderedPhotos( functionContext, filterContext )

    local exportSettings = filterContext.propertyTable

    -- Debug.lognpp( exportSettings )

    local n = 0
    local photos = {}
    local savePhotos = {}
    
    local function transferCustomMetadata( fromPhoto, toPhoto )
        local cMeta = custMeta:getMetadata( fromPhoto, _PLUGIN.id ) -- get (plugin) metadata, never nil.
        --Debug.lognpp( "cMeta", cMeta )
        if not tab:isEmpty( cMeta ) then
            --Debug.logn( "Got cmeta" )
            for id, xfr in pairs( cMeta ) do
                --Debug.logn( id, xfr )
                if xfr then
                    --Debug.logn( id, cMeta[id] )
                    local xfrd, orNot = custMeta:update( toPhoto, id, cMeta[id], nil, true, 10 ) -- nil => no version, true => no-throw, 10 tries will be ignored.
                    if xfrd then
                        --Debug.logn( "xfrd n chgd" )
                    elseif orNot then
                        app:logWarning( "Unable to transfer custom metadata item, error message: ^1", orNot )
                    else
                        --Debug.logn( "xfrd but not chgd" )
                    end
                end
            end
        else
            app:logVerbose( "No custom metadata for photo." )
        end
    end
    
    for sourceRendition, renditionToSatisfy in filterContext:renditions() do
        repeat
            local success, pathOrMessage = sourceRendition:waitForRender()
            if success then
                --Debug.logn( "Source \"rendition\" created at " .. pathOrMessage )
                if pathOrMessage ~= renditionToSatisfy.destinationPath then
                    app:logWarning( "Destination path mixup, expected '^1', but was '^2'", renditionToSatisfy.destinationPath, pathOrMessage )
                end
            else -- problem exporting original, which in my case is due to something in metadata blocks that Lightroom does not like.
                app:logWarning( "Unable to export '^1' to original format, error message: ^2. This may not cause a problem with this export, but does indicate a problem with the source photo.", renditionToSatisfy.destinationPath, pathOrMessage )
                pathOrMessage = renditionToSatisfy.destinationPath
            end    
            app:call( Call:new{ name="Post-Process Rendered Photo", main=function( context )

                photos[#photos + 1] = { sourceRendition.photo, pathOrMessage }
                app:logVerbose( "^1 to receive metadata", pathOrMessage )
            
            end, finale=function( call, status, message )
                if status then
                    --Debug.logn( "didone" ) -- errors are not automatically logged for base calls, just services.
                else
                    app:logErr( message ) -- errors are not automatically logged for base calls, just services.
                end
            end } )
        until true
    end
    
    if #photos > 0 then
        app:call( Call:new{ name="Copying Custom Metadata to Exported Photos", async=true, main=function( call )
            call.scope = LrProgressScope {
                title = "Transferring Custom Metadata",
                caption = "Please wait...",
                functionContext = call.context,
            }
            call.saveSel = cat:saveSelPhotos()
            local s, m = cat:update( 20, call.name, function( context, phase )
                local function wait( path, index )
                    assert( maxWait ~= nil, "No max wait" )
                    local startTime = LrDate.currentTime()
                    repeat
                        local photo = cat:findPhotoByPath( path )
                        if photo then
                            return photo
                        elseif ( LrDate.currentTime() - startTime ) > maxWait then
                            break
                        end
                        LrTasks.sleep( .1 )
                    until false
                    return nil
                end
                local i1 = ( phase - 1 ) * 1000 + 1
                local i2 = math.min( phase * 1000, #photos )
                for i = i1, i2 do
                    repeat
                        v = photos[i]
                        local fromPhoto = v[1]
                        local toPath = v[2]
                        local toPhoto = wait( toPath, i )
                        if toPhoto then
                            app:logVerbose( "Transferring custom metadata to '^1'", toPath )
                        else
                            app:log( str:fmt( "Exported, but not added to catalog: ^1", toPath ) )
                            break
                        end
                        
                        assert( custMetaTbl ~= nil, "No custom metadata table" )
                        transferCustomMetadata( fromPhoto, toPhoto )
                        app:log( "Transferred custom metadata to '^1'", toPath )
                        
                        savePhotos[#savePhotos + 1] = toPhoto
                        n = n + 1
                    until true
                    if call:isQuit() then
                        return true
                    else
                        call.scope:setPortionComplete( i, #photos )
                    end
                end
                if i2 < #photos then
                    return false
                end
            end )
            if s then
                -- splatt-n-doobie
            else
                error( m )
            end
        
        end, finale=function( call, status, message )
            if call.saveSel then
                cat:restoreSelPhotos( call.saveSel )
            end
            app:log()
            if status then
                app:log( "^1 received custom metadata as configured", str:plural( n, "photo" ) )
                if call:isCanceled() then
                    app:log( "Canceled." )
                elseif call:isAborted() then
                    app:log( "Aborted." )
                else
                    app:log( "Done." )
                end
            else
                app:logErr( message ) -- errors are not automatically logged for base calls, just services.
            end
            app:log( "\n\n" )
            
            --Debug.showLogFile()
            
        end } )
    else
        app:log( "No photos passed through for metadata transfer this export." )
    end
end



return ExtendedExportFilter
