--[[
        SpecialManager.lua
        
        See '*** Instructions' below.
--]]


local SpecialManager, dbg, dbgf = Manager:newClass{ className='SpecialManager' }



--[[
        Constructor for extending class.
--]]
function SpecialManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function SpecialManager:new( t )
    return Manager.new( self, t )
end



--- Static function to initialize plugin preferences (not framework preferences) - both global and non-global.
--
function SpecialManager.initPrefs()
    -- Init global prefs:
    app:initGlobalPref( 'csvInWithSources', false )
    app:initGlobalPref( 'csvFolderOrFile', LrPathUtils.child( cat:getCatDir(), _PLUGIN.id ) )
    app:initGlobalPref( 'csvIsFolder', true )
    app:registerPreset( "Parse ExpressionMedia XMP", 2 )
    -- Init local prefs:
    -- Init base prefs:
    Manager.initPrefs()
end



function SpecialManager:startDialogMethod( props )
    app:initPref( 'testData', "Test-Data" )
    Manager.startDialogMethod( self, props )
end



function SpecialManager:_promptForExportImportCsv( which, photos, call )

    local sub_1 -- substitution #1 for ui
    local sub_2 -- substitution #2 for ui
    local panel
    local folder
    local file
    if which == 'Export' then
        sub_1 = "to contain"
        sub_2 = "for"
        panel = LrDialogs.runSavePanel
    elseif which == 'Import' then
        sub_1 = "containing"
        sub_2 = "with"
        panel = LrDialogs.runOpenPanel
    else
        app:callingError( "which?" )
    end
    
    local vi = {}
    vi[#vi + 1] =
        vf:row {
            vf:checkbox {
                bind_to_object = prefs, -- props,
                title = str:fmt( "^1 individual csv files alongside source photos (\"sidecar\"-style)", which ),
                value = app:getGlobalPrefBinding( 'csvInWithSources' ),
            }
        }
    vi[#vi + 1] = vf:spacer { height = 15 }
    vi[#vi + 1] = 
        vf:static_text {
            title = str:fmt( "Select folder ^1 csv files, or single csv file:", sub_2 )
        }
    vi[#vi + 1] =
        vf:row {                            
            vf:edit_field {
                bind_to_object = prefs,
                width_in_chars = 40,
                value = app:getGlobalPrefBinding( 'csvFolderOrFile' ),
                enabled = LrBinding.negativeOfKey( app:getGlobalPrefKey( 'csvInWithSources' ) ),
            },
            vf:push_button {
                bind_to_object = prefs,
                title = "Browse",
                props = prefs,
                tooltip = str:fmt( "Select folder ^1 individual files for each photo, or select file ^1 entries for each photo.", sub_1 ),
                enabled = LrBinding.negativeOfKey( app:getGlobalPrefKey( 'csvInWithSources' ) ),
                action = function( button )
                    app:call( Call:new{ name=button.title, async=true, guard=App.guardVocal, main=function( call )
                        -- local props = button.props
                        local initDir
                        local fof = app:getGlobalPref( 'csvFolderOrFile' )
                        if str:is( fof ) then
                            initDir = LrPathUtils.parent( fof )
                        end
                        local f = panel {
                            title = str:fmt( "Choose Folder or File for ^1ing CSV", which ),
                            prompt = which,
                            canChooseFiles = true,
                            canChooseDirectories = true,
                            canCreateDirectories = ( which == "Export" ),
                            allowsMultipleSelection = false,
                            fileTypes = "csv",
                            accessoryView = nil,
                            initialDirectory = initDir,
                        }
                        if f ~= nil then
                            if which == 'Export' then
                                -- browser prompts for overwrite when its a save panel.
                                local fe = LrFileUtils.exists( f )
                                if fe == 'directory' then
                                    folder = f
                                    app:setGlobalPref( 'csvFolderOrFile', folder )
                                    app:setGlobalPref( 'csvIsFolder', true )
                                elseif fe == 'file' then
                                    file = f
                                    app:setGlobalPref( 'csvFolderOrFile', file )
                                    app:setGlobalPref( 'csvIsFolder', false )
                                elseif LrStringUtils.lower( LrPathUtils.extension( f ) ) == 'csv' then
                                    file = f
                                    app:setGlobalPref( 'csvFolderOrFile', file )
                                    app:setGlobalPref( 'csvIsFolder', false )
                                else
                                    app:error( "Invalid selection: ^1", f )
                                end                                     
                            else
                                if #f > 0 then
                                    local ft = LrFileUtils.exists( f[1] )
                                    if ft=='file' then
                                        file = f[1]            
                                        app:setGlobalPref( 'csvFolderOrFile', file )
                                        app:setGlobalPref( 'csvIsFolder', false )
                                    elseif ft == 'directory' then
                                        folder = f[1]
                                        app:setGlobalPref( 'csvFolderOrFile', folder )
                                        app:setGlobalPref( 'csvIsFolder', true )
                                    else
                                        error( "selection disappeared!" )
                                    end
                                else
                                    call:cancel()
                                end
                            end
                        else
                            call:cancel()
                        end
                        
                    end } )
                end,
            },
        }
    local answer = app:show{ confirm="^1 metadata for ^2? (note: you can define items to be included/excluded by editing \"advanced settings\" in plugin manager)",
        subs = { which, str:plural( #photos, "photo" ) },
        viewItems = vi,
        buttons = { dia:btn( "OK", 'ok' ) },
    }
    if answer == 'ok' then
        -- all set.
    else
        call:cancel()
    end

end



--- Read (all) custom metadata for chosen photos, from xmp.
--
--  @usage runs complete as an asynchronous service.
--  @usage presently expects files in sidecar (same dir as photo) - embedded xmp not supported, but could be (with a little help from exiftool..).
--
function SpecialManager:readFromXmp()
    app:service{ name="Custom Metadata - Read from XMP", async=true, progress=true, guard=App.guardVocal, function( call )
        local pluginId = _PLUGIN.id
        if not _PLUGIN.enabled then
            app:show{ warning="Plugin must be enabled in plugin manager (hint: 'Enable' button in 'Status' section)." }
            call:cancel()
            return
        end
        
        local finder = app:getPref( 'findCustomMetadataInXmp' ) or error( "'findCustomMetadataInXmp' is not defined in \"advanced settings\" - consider re-reading the instructions ;-}." )
        local getter = app:getPref( 'getNextItemInXmp' ) or error( "'getNextItemInXmp' is not defined in \"advanced settings\"." ) -- but the previous, *is* - hmm..
        local parser = app:getPref( 'parseNameAndValueFromXmpData' ) or error( "'parseNameAndValueFromXmpData' is not defined in \"advanced settings\"." )

        -- initial prompt - reflect state in progress scope.        
        local targetPhotos = dia:promptForTargetPhotos { -- target photos may be those selected, visible in filmstrip, whole catalog, or most-selected only.
            prefix = "Read custom metadata from extended xmp corresponding to",
            viewItems = nil,--vi,
            accItems = nil,
            returnComponents = nil,
            call = call,
        }
        if call:isQuit() then -- user canceled or program aborted.
            return
        end
        -- acquire baseline metadata for all prospectives, and attend to progress scope.
        local cache = lrMeta:createCache{ photos=targetPhotos, rawIds={ 'path', 'isVirtualCopy', 'fileFormat' }, fmtIds={ 'copyName' }, call=call }
        call:setCaption( "Scrutinizing prospective photos.." )
        local recs = {}
        for i, p in ipairs( targetPhotos ) do
            local photo = p
            repeat
                local rawPath = cache:getRaw( p, 'path' )
                local path = LrPathUtils.standardizePath( rawPath )
                if rawPath ~= path then -- for me, it always is the same, but dunno - if somebody's using monkey business or Lr mobile..
                    app:logV( "Photo path in catalog (^1) is not the same when standardized: ^2", rawPath, path )
                end
                local name = cat:getPhotoNameDisp( p, true, cache )
                local fmt = cache:getRaw( p, 'fileFormat' )
                app:log( "Considering ^1", name )
                if cache:getRaw( p, 'isVirtualCopy' ) then
                    app:log( "Virtual copy skipped." )
                    break
                end
                if fmt == 'VIDEO' then
                    app:log( "Video skipped." )
                    break
                end
                local xmp = LrPathUtils.addExtension( path, "xmp" )
                if LrFileUtils.exists( xmp ) then
                    recs[#recs + 1] = { photo=photo, xmp=xmp, path=path }
                    app:log( "Getting from xmp file with added extension." )
                else
                    local lookedHere = xmp
                    local xmp = LrPathUtils.replaceExtension( path, "xmp" )
                    if LrFileUtils.exists( xmp ) then
                        if fmt == 'RAW' then
                            recs[#recs + 1] = { photo=photo, xmp=xmp, path=path, }
                            app:log( "Getting from standard (extended) xmp sidecar." )
                        elseif fmt == 'DNG' then
                            recs[#recs + 1] = { photo=photo, xmp=xmp, path=path }
                            app:log( "Getting from DNG xmp sidecar." )
                        else
                            app:log( "*** xmp sidecars for ^1 files is not supported - skipping it.", fmt )
                        end
                    else
                        if LrFileUtils.exists( path ) then
                            app:log( "*** Photo file exists, but xmp sidecar does not (condsidered '^1' then '^2', but neither file exists) - skipping photo.", lookedHere, xmp )
                        else
                            app:log( "*** Photo file is missing, and no xmp sidecar exists either (condsidered '^1' then '^2', but neither exists) - skipping photo.", lookedHere, xmp )
                        end
                    end              
                end
            until true
        end
        if #recs == 0 then
            app:show{ info="None have eligible xmp sidecars - name must be filename.ext.xmp (with extension - any file-type, but not virtual copy), or filename.xmp (without extension - raw and/or dng only).", call=call }
            return
        end
        
        -- got some photos with xmp to read..
        call:setCaption( "Reading custom metadata from xmp" )
        app:log( "Reading custom metadata for plugin (^2): ^1", pluginId, str:plural( #recs, "photo" ) )
        
        local specsById = {}
        local specsByTitle = {}
        local specs, nuh = custMeta:getMetadataSpecs( true ) -- true => re-read (probably no need to assure re-reading, but doesn't hurt).
        if specs then -- uh-huh
            local n = 0
            for i, spec in ipairs( specs ) do
                if str:is( spec.id ) then
                    specsById[spec.id] = spec
                    specsByTitle[spec.title] = spec
                    n = n + 1
                else
                    error( "bad metadata spec" )
                end
            end
            if n > 0 then
                app:log( "^1 defined in plugin module: ^1", str:pluralize( n, "metadata item" ) )
            else
                app:logE( "No metadata items defined in plugin module." )
                return
            end
        else -- nuh-uh
            app:logE( nuh )
            return
        end
        
        
        -- process array of recorded info (photo, xmp, path).
        for i, rec in ipairs( recs ) do
            repeat
                local changes = 0
                local photoPath = rec.path
                local photoFilename = LrPathUtils.leafName( photoPath )
                local file = rec.xmp
                local photo = rec.photo
                local metaXml
                local errm
                local content
                app:log()
                app:log( "Considering reading custom metadata for ^1", photoPath )
                if fso:existsAsFile( file ) then
                    content, errm = fso:readFile( file ) -- c = content or error message
                    if content then
                        if str:is( content ) then
                            metaXml, errm = xml:parseXml( content ) -- just a time consuming sanity check at this point, since xml content is being handled (parsed) as a string.
                            -- in the future, could be handled via conventional xml techniques..
                            if not metaXml then
                                app:logE( errm )
                                break
                            else    
                                app:log( "Source of xmp info (validated xml format): ^1", file ) -- no longer considered verbose, since this is such a critical piece of info.
                            end
                        else
                            -- do not throw error since one file error should not the whole operation deny...
                            app:logE( "No content in '^1' - you may need to delete it before custom metadata can be transferred to '^2'", file, photoPath )
                            break
                        end
                    else
                        -- do not throw error since one file error should not the whole operation deny...
                        app:logE( "Unable to read xmp file, error message: ^1 - custom metadata not transferred to ^2", errm, photoPath ) -- error message includes offending file-path.
                        break
                    end
                else
                    app:log( "Saved custom metadata file does not exist: ^1", file )
                    break
                end
                
                if str:is( content ) then
                    local parsePos, orNoParsePos = finder{ xmpContent=content, parsePosition=1, metadataSpecs=specsById, metadataSpecsByTitle=specsByTitle }
                    if parsePos then
                        local changes = 0
                        
                        -- process whatever was returned by parser for id (must be string) and value (can be anything, although typically string).
                        -- log error/warning if anything fishy (nothing returned, and shouldn't throw an error).
                        local function processData( id, value, version )
                            if version ~= nil then
                                app:logV( "*** Processing versioned data, name/ID: ^1, value(s): ^2, version: ^3", id, value, version )
                            else
                                app:logV( "Processing data, name/ID: ^1, value(s): ^2", id, value )
                            end
                            if not str:is( id ) then
                                app:logE( "No data ID" )
                                return
                            end
                            if value == nil then -- technially, nil is allowed, but may be a yellow flag..
                                app:logV( "*** value is nil" )
                            end
                            if specsById[id] then
                                local s, m = custMeta:update( photo, id, value, version, true, 20 ) -- version is typically (but not necessarily) nil, no-throw=true, 20 tries max.
                                if s ~= nil then -- definitive
                                    if s then
                                        app:logV( "'^1' changed from '^2' to '^3'", id, str:to( m ), str:to( value ) )
                                        changes = changes + 1
                                    else
                                        -- not changed.
                                    end
                                else
                                    app:logE( m )
                                end
                            else
                                app:logW( "Metadata with ID='^1' is not defined.", id )
                            end
                        end
                        
                        local sanity = 10000 -- start plenty sane.
                        repeat
                            parsePos, errm = getter{ xmpContent=content, parsePosition=parsePos, metadataSpecs=specsById, metadataSpecsByTitle=specsByTitle }
                            if parsePos then
                                local newParsePos, name, value, version = parser{ xmpContent=content, parsePosition=parsePos, metadataSpecs=specsById, metadataSpecsByTitle=specsByTitle } -- could return optional version number in future..
                                if newParsePos then
                                    processData( name, value, version ) -- name is ID.
                                    parsePos = newParsePos
                                else
                                    app:logW( "No processable data parsed from element - ^1", name ) -- name is errm.
                                    -- continue parsing where we left off.
                                end
                                sanity = sanity - 1 -- lose a little sanity
                                if sanity == 0 then -- no sanity left - insane..
                                    app:logE( "Too many items gotten - \"getter\" (getNextItemInXmp function) needs to return nil or false at some point.." )
                                    break
                                end
                            else
                                app:log( "No more elements - ^1", errm ) -- may not be an error, but "print" whatever was returned.
                                break
                            end
                        until false
                        app:log( "^1 changed.", str:pluralize( changes, "metadata item" ) )
                    else
                        app:logW( "No custom metadata found - ^1", orNoParsePos )
                    end
                else
                    app:logW( "No custom metadata items for '^1' are present in '^2'", photoPath, file )
                end
            until true
        end
    end }
end



function SpecialManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    if app.prefMgr then
        appSection.bind_to_object = props
    else
        appSection.bind_to_object = prefs
    end
    
	appSection.title = app:getAppName() .. " Management"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()

    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Backup as XML",
                width = share 'button_width',
                action = function( button )
                    custMeta:save()
                end,
            },
            vf:static_text {
                title = "Saves custom metadata from catalog to individual files.",
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Restore from XML",
                width = share 'button_width',
                action = function( button )
                    custMeta:read()
                end,
            },
            vf:static_text {
                title = "Reads custom metadata from saved files to catalog.",
            },
        }
        
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Read from xmp sidecar",
                width = share 'button_width',
                action = function( button )
                    self:readFromXmp()
                end,
            },
            vf:static_text {
                title = "Reads custom metadata from *extended* xmp sidecar created by app\nsupporting custom metadata extensions.",
            },
        }
		
	appSection[#appSection + 1] = 
		vf:row {
			vf:push_button {
				title = "Transfer Metadata",
				width = share 'button_width',
				action = function( button )
				    app:call( Service:new{ name=button.title, async=true, main = function( service )
                        service.nUpd = 0
                        service.nNot = 0
    
				        local targetPhotos = catalog:getTargetPhotos()
				        local allPhotos = catalog:getAllPhotos()

                        props['clearSourceMetadata'] = false
				        local viewItems = {
				            vf:row { bind_to_object = props,
				                vf:checkbox {
				                    title = 'Clear source metadata after transfer',
				                    value = bind 'clearSourceMetadata',
				                }
				            }
				        }
				        
                        local answer = app:show{ confirm="Transfer metadata for ^1, or ^2 (whole catalog)? (Hint: click 'Cancel' if you haven't configured the transfer by editing \"advanced settings\" in plugin manager.",
                            subs = { str:plural( #targetPhotos, "target photo", true ), str:plural( #allPhotos, "photo", true  ) },
                            viewItems = viewItems,
                            buttons = { dia:btn( "Yes - Target Photos Only", 'ok' ), dia:btn( "Yes - All Photos In Catalog", 'other' ) },
                        }
                        local clear = props['clearSourceMetadata']
                        assert( clear ~= nil and type( clear ) == 'boolean', "not good" )
                        local photos
                        if answer == 'cancel' then
                            service:cancel()
                            return
                        elseif answer == 'ok' then
                            photos = targetPhotos
                        elseif answer == 'other' then
                            photos = allPhotos
                        else
                            app:error( "bad answer" )
                        end

                        local xRaw = app:getPref( 'transferRawMetadata' )
                        if xRaw == nil then
                            xRaw = {}
                        else
                            assert( type( xRaw ) == 'table', "transferRawMetadata must be table" )
                        end
                        local xFmt = app:getPref( 'transferFormattedMetadata' )
                        if xFmt == nil then
                            xFmt = {}
                        else
                            assert( type( xFmt ) == 'table', "transferFormattedMetadata must be table" )
                        end
                        local xPlugin = app:getPref( 'transferPluginMetadata' )
                        local pluginId
                        if xPlugin == nil then
                            xPlugin = {}
                        else
                            assert( type( xPlugin ) == 'table', "transferPluginMetadata must be table" )
                            pluginId = xPlugin.pluginId
                        end
                        
                        local function upd( context )
                        
                            local scope = LrProgressScope {
                                title = "Transferring metadata",
                                caption = "please wait",
                                functionContext = context,
                            }

                            for i, photo in ipairs( photos ) do
                            
                                for rawName, propTbl in pairs( xRaw ) do
                                    local propName = propTbl[1]
                                    local clearVal = propTbl[2]
                                    local value = photo:getRawMetadata( rawName )
                                    local chg, msg = custMeta:update( photo, propName, value, nil, true ) -- nil => current version, true => no-throw.
                                    if chg ~= nil then
                                        if chg then
                                            -- app:logV( "Changed
                                            service.nUpd = service.nUpd + 1
                                        else
                                            service.nNot = service.nNot + 1
                                        end
                                        if clear then
                                            photo:setRawMetadata( rawName, clearVal )
                                        end
                                    else
                                        app:logE( msg )
                                    end
                                end
                                for fmtName, propTbl in pairs( xFmt ) do
                                    local propName = propTbl[1]
                                    local clearVal = propTbl[2]
                                    local value = photo:getFormattedMetadata( fmtName )
                                    local chg, msg = custMeta:update( photo, propName, value, nil, true ) -- nil => current version, true => no-throw.
                                    if chg ~= nil then
                                        if chg then
                                            service.nUpd = service.nUpd + 1
                                        else
                                            service.nNot = service.nNot + 1
                                        end
                                        if clear then
                                            photo:setRawMetadata( fmtName, clearVal )
                                        end
                                    else
                                        app:logE( msg )
                                    end
                                end
                                if str:is( pluginId ) then
                                    app:log( "Transferring metadata from ^1", pluginId )
                                    if clear then
                                        app:log( "Clearing source plugin's metadata is not supported." )
                                    end
                                    local me = custMeta:getMetadata( photo, pluginId ) -- get plugin metadata as lookup table.
                                    for i, spec in ipairs( xPlugin ) do
                                        local sourceId = spec.sourceId
                                        local targetId = spec.targetId
                                        --local sourceClear = spec.sourceClear
                                        local value = me[sourceId]
                                        local chg, msg = custMeta:update( photo, targetId, value, nil, true ) -- nil => current version, true => no-throw.
                                        if chg ~= nil then
                                            if chg then
                                                service.nUpd = service.nUpd + 1
                                            else
                                                service.nNot = service.nNot + 1
                                            end
                                            -- no clearing...
                                        else
                                            app:logE( msg )
                                        end
                                    end
                                else
                                    app:log( "No plugin metadata to transfer" )
                                end
                                        
                            end
                        end                        
                        local s, m
                        if clear then
                            s, m = cat:update( 20, "Transfer and clear metadata", upd )
                        else
                            s, m = cat:updatePrivate( 20, upd )
                        end
                        if not s then
                            app:error( m:gsub( "Info.lua", str:to( app.infoLua.LrMetadataProvider ) ) )
                        end
                    end, finale=function( service, status, message )
                        if status and not service:isCanceled() then
                            app:show{ info="^1 photo properties updated, ^2 unchanged.", service.nUpd, service.nNot }
                        -- else let normal error handling prevail.
                        end
                    end } )
				end
			},
			vf:static_text {
				title = str:format( "Transfer metadata from previous fields to new custom metadata fields." ),
			},
		}
	appSection[#appSection + 1] = 
		vf:row {
			vf:push_button {
				title = "Export CSV",
				width = share 'button_width',
				action = function( button )
				    app:call( Service:new{ name=button.title, async=true, main = function( service )
				        service.nExported = 0
                        local inWithSources
                        local exportToDir
                        local exportToFile
                        local values -- keys/values.
                        local names
                        local buf = {}
                        local rawMeta
                        local fmtMeta
                        local sep = app:getPref( 'exportCsvDelim' ) or ','
                        local wrap = app:getPref( 'exportCsvWrap' ) or ''
                        
				        local function exportValues( photo )
				            local path = rawMeta[photo].path
				            local isVirtual = rawMeta[photo].isVirtualCopy
				            local copyName
				            local dir
				            local leaf = LrPathUtils.leafName( path )
				            local filename
			                if isVirtual then
				                copyName = fmtMeta[photo].copyName
                                filename = LrPathUtils.replaceExtension( str:fmt( "^1 (^2)", leaf, copyName ), "vc_custom_metadata.csv" )
			                else
			                    copyName = ""
			                    filename = LrPathUtils.replaceExtension( leaf, "custom_metadata.csv" )
			                end
				            local vals
				            if inWithSources then -- sidecar.
                                names = { 'filename', 'copyName' }
                                vals = { LrPathUtils.leafName( path ), copyName }
                            else
				                names = { 'path', 'copyName' }
				                vals = { path, copyName }
                            end
				            for k, v in tab:sortedPairs( values ) do
				                names[#names + 1] = k
				                vals[#vals + 1] = wrap .. str:to( v ) .. wrap
				            end
				            if str:is( exportToFile ) then -- single file
				                if #buf == 0 then
				                    buf[1] = table.concat( names, sep )
				                end
				                buf[#buf + 1] = table.concat( vals, sep )
				            else
				                if str:is( exportToDir ) then
                                    dir = exportToDir				            
				                elseif inWithSources then
				                    dir = LrPathUtils.parent( path )
				                else
				                    error( "not sure about dir" ) -- ?###2
				                end
				                local file = LrPathUtils.child( dir, filename )
    				            local c = table.concat( names, "," ) .. "\n" .. table.concat( vals, "," ) .. "\n"
    				            if str:is( c ) then
        				            -- app:show( c )
        				            local s, m = fso:writeFile( file, c, not inWithSources ) -- assure dir if not in with sources.
        				            if s then
        				                app:log( "Wrote ^1", file )
        				            else
        				                app:logErr( m )
        				            end
        				        else
        				            app:logErr( "Double-check those values." )
        				        end
        				    end
				        end -- of export-values function.
				        
				        -- beginning of main function execution.
                        local photos = catalog:getTargetPhotos() -- selected or all if none selected.
                        if #photos == 0 then
                            app:show{ warning="no photos" }
                            service:cancel()
                            return
                        end
                        local exportCsv = app:getPref( 'exportCsv' )
                        rawMeta = cat:getBatchRawMetadata( photos, { 'path', 'isVirtualCopy' } )
                        fmtMeta = cat:getBatchFormattedMetadata( photos, { 'copyName' } )
                        if exportCsv ~= nil then
                            assert( type( exportCsv ) == 'table', "exportCsv should be table" )
                            self:_promptForExportImportCsv( "Export", photos, service )
                            inWithSources = app:getGlobalPref( 'csvInWithSources' )
                            if inWithSources then
                                exportToDir = nil
                                exportToFile = nil
                            else
                                local isFolder = app:getGlobalPref( 'csvIsFolder' )
                                Debug.pause( isFolder )
                                if isFolder then
                                    exportToDir = app:getGlobalPref( 'csvFolderOrFile' )
                                    exportToFile = nil
                                else
                                    exportToFile = app:getGlobalPref( 'csvFolderOrFile' )
                                    exportToDir = nil
                                end
                            end
                            --Debug.pause( inWithSources, exportToDir, exportToFile )
                            if service:isCanceled() then
                                return
                            end
                            local yc = 0
                            local scope = LrProgressScope {
                                title = "Exporting custom metadata as csv",
                                caption = "Please wait...",
                                functionContext = service.context,
                            }
                            Debug.pause( exportToFile )
                            for i, photo in ipairs( photos ) do
                                values = {}
                                
                                for k, v in pairs( exportCsv ) do
                                    if v then
                                        local value = photo:getPropertyForPlugin( _PLUGIN, k )
                                        if value == nil then
                                            value = ""
                                        else -- value converted to string when exported.
                                            service.nExported = service.nExported + 1
                                        end
                                        values[k] = value
                                    end
                                end
                                                                
                                exportValues( photo )
                                
                                scope:setPortionComplete( i, #photos )
                                yc = app:yield( yc )
                            end
                            if str:is( exportToFile ) then
                                local c = table.concat( buf, "\n" )
                                Debug.pause()
                                local s, m = fso:writeFile( exportToFile, c, true ) -- true => assure dir.
                                if s then
                                    app:log( "File written: ^1", exportToFile )
                                else
                                    app:error( m )
                                end
                            else
                                -- nuthin' to add...                            
                            end
                            scope:setCaption( "Done." )
                        else
                            app:show{ warning="No items are configured to be exported - please configure using plugin-manager/edit-advanced-settings." }
                            service:cancel()
                        end
                    end, finale=function( service, status, message )
                        if status and not service:isCanceled() then
                            app:show{ info="^1 exported.", str:plural( service.nExported, "\"non-blank\" property" ) }
                        end
                    end } )
				end
			},
			vf:static_text {
				title = str:format( "Export custom metadata to csv (with dir/file options)" ),
			},
		}
	appSection[#appSection + 1] = 
		vf:row {
			vf:push_button {
				title = "Import CSV",
				width = share 'button_width',
				action = function( button )
				    app:call( Service:new{ name=button.title, async=true, main = function( call )
				        call.nUpdated = 0
				        call.nUnchanged = 0
				        local importCsv
				        local inWithSources
                        local importFromDir
                        local importFromFile
                        local importStream
                        local nameLine
                        local valueLine
                        local copyName
                        local buf = {}
                        local names
                        local rawMeta
                        local fmtMeta
                        
				        local function importValues( photoOrLine )
				            local path
				            local dir
				            local photo
				            local line
				            local copyName
				            local isVirtual
				            local leaf
				            if type( photoOrLine ) == 'string' then -- line (import-from-file)
				                line = photoOrLine
				                if nameLine == nil then
				                    nameLine = line
        				            names = str:split( nameLine, "," )
        				            if #names < 2 then
        				                app:error( "Bad csv file - no path or copy-name" )
        				            else
        				                if names[1] == 'path' then
        				                    if names[2] == 'copyName' then
        				                        -- good
        				                        return
        				                    else
        				                        app:error( "Bad csv file - no copy-name" )
        				                    end
        				                else
        				                    app:error( "Bad csv file - no path name" )
        				                end
        				            end
				                    return
				                else
        				            valueLine = line
        				        end
				            else
				                photo = photoOrLine
				                path = rawMeta[photo].path
				                leaf = LrPathUtils.leafName( path )
				                isVirtual = rawMeta[photo].isVirtualCopy
				                if isVirtual then
				                    copyName = photo:getFormattedMetadata( 'copyName' )
				                    app:log( "Virtual photo path: ^1, copy-name: ^2", path, copyName )
				                else
				                    copyName = ""
				                    app:log( "Photo path: ^1", path )
				                end
    				            if str:is( importFromDir ) then
    				                dir = importFromDir
    				            else
    				                dir = LrPathUtils.parent( path )
    				            end
    				            local filename
    				            
    				            if isVirtual then
    				                filename = LrPathUtils.replaceExtension( leaf, "vc_custom_metadata.csv" )
    				            else
        				            filename = LrPathUtils.replaceExtension( leaf, "custom_metadata.csv" )
        				        end
    				            local file = LrPathUtils.child( dir, filename )
    				            app:log( "CSV path: ^1", file )
    				            local index
    				            local file = LrPathUtils.child( dir, filename )
    				            if fso:existsAsFile( file ) then
      				                local c, m = fso:readFile( file )
        				            if c then
        				                local lines = str:split( c, "\n" ) -- trims \r if necessary.
        				                if #lines == 0 then
        				                    app:logW( "No lines" )
        				                    return
        				                elseif lines == 1 then
        				                    app:logW( "Not enough lines" )
        				                    return
        				                elseif lines == 2 then
        				                    nameLine = lines[1]
        				                    valueLine = lines[2]
        				                elseif #lines == 3 then
        				                    if not str:is( lines[3] ) then
        				                        nameLine = lines[1]
        				                        valueLine = lines[2]
        				                    else
        				                        app:logErr( "should be only one non-blank line" )
        				                        return
        				                    end
        				                else
        				                    app:logErr( "too many lines" )
        				                    return
        				                end
        				                names = str:split( nameLine, "," )
        				            else
        				                app:logW( "No content - ^1", str:to( m ) )
        				                return
        				            end
                                else
      				                app:logV( "No file" )
      				                return
                                end        				        
        				    end
	                        local vals = str:split( valueLine, ',' )
	                        local index
	                        if #names > 0 then
	                            if #vals ~= #names then
	                                app:logErr( "Number of values should be ^1 but is ^2", #names, #vals )
	                                return
	                            end
	                            if str:is( importFromFile ) then -- single file
                                    -- local names = str:split( vals[1], '=' )
                                    if #vals < 2 then
                                        app:logW( "no path or copy-name value." )
                                        return
                                    else
	                                    path = vals[1]
	                                    copyName = vals[2]
	                                end
	                                if str:is( path ) then
	                                    app:log( path )
	                                else
	                                    app:logErr( "No photo path in csv" )
	                                    return
	                                end
	                                photo = cat:findPhotoByPath( path, copyName, rawMeta, fmtMeta )
	                                
	                                if photo then
	                                    app:log( "Photo path: ^1", path )
	                                    index = 2
	                                else
	                                    app:logW( "Photo not found." )
	                                    return
	                                end
	                            else
	                                index = 1
	                                app:logV( "not importing from single file" )
	                            end
	                            if index <= #vals then
	                                while index <= #vals do
                                        local name = names[index]
                                        local value = vals[index]
                                        if str:is( name ) then
                                            if name == 'copyName' then
                                                if str:is( value ) then
                                                    if value == copyName then
                                                        app:logV( "Virtual copy name: ^1", value )
                                                    else
                                                        app:logW( "Virtual copy name mismatch, expected: '^1', instead of: '^2'", copyName, value )
                                                    end
                                                else
                                                    if str:is( copyName ) then
                                                        app:logW( "Copy name expected." )
                                                    else
                                                        app:logV( "No copy name expected - none found: good." )
                                                    end
                                                end
                                            elseif importCsv[name] then -- inclusion specified.
                                                local s, m = custMeta:update( photo, name, value, nil, true ) -- nil => no-version, true => no-throw, tries ignored when cat-wrapped.
                                                if s ~= nil then -- property either set or didn't need to be.
                                                    if s then
                                                        app:log( "Updated field ^1 from ^2 to ^3", name, m, value )
                                                        call.nUpdated = call.nUpdated + 1
                                                    else
                                                        app:logV( "Field ^1 was already ^2", name, value )
                                                        call.nUnchanged = call.nUnchanged + 1
                                                    end
                                                else
                                                    app:logErr( m )
                                                end
                                            elseif index == 1 then -- path/name field
                                                app:logV( "Path is taken from actual filename, not first column data: ^1", value )
                                            else
                                                app:logV( "Field ^1 is being skipped.", name )
                                            end
                                        else
                                            app:logV( "Missing field name" )
                                        end
                                        index = index + 1
                                    end -- while
                                else
                                    app:logV( "No names/values." )
                                end
                            else
                                app:logV( "No items." )
                            end
				        end -- of import-values function.
				        
				        -- beginning of main import function.
                        local photos = catalog:getTargetPhotos() -- selected or all if none selected.
                        if #photos == 0 then
                            app:show{ warning="no photos" }
                            call:cancel()
                            return
                        end
                        importCsv = app:getPref( 'importCsv' )
                        rawMeta = cat:getBatchRawMetadata( photos, { 'path', 'isVirtualCopy', 'virtualCopies' } )
                        fmtMeta = cat:getBatchFormattedMetadata( photos, { 'copyName' } )
                        if importCsv then
                            self:_promptForExportImportCsv( "Import", photos, call )
                            if call:isCanceled() then
                                return
                            end
                            inWithSources = app:getGlobalPref( 'csvInWithSources' )
                            if inWithSources then
                                importFromDir = nil
                                importFromFile = nil
                            else
                                local isFolder = app:getGlobalPref( 'csvIsFolder' )
                                if isFolder then
                                    importFromDir = app:getGlobalPref( 'csvFolderOrFile' )
                                    importFromFile = nil
                                else
                                    importFromFile = app:getGlobalPref( 'csvFolderOrFile' )
                                    importFromDir = nil
                                end
                            end
    
                            assert( inWithSources or importFromDir or importFromFile, "no import source" )
                        
                            local yc = 0
                            local scope = LrProgressScope {
                                title = "Importing custom metadata as csv",
                                caption = "Please wait...",
                                functionContext = call.context,
                            }
                            local s, m = cat:updatePrivate( 30, function( context, phase )
                                if str:is( importFromFile ) then -- single file
                                    scope:setIndeterminate( true )
                                    for line in io.lines( importFromFile ) do -- auto-opens/closes file.
                                        importValues( line )
                                        if scope:isCanceled() then
                                            break
                                        else
                                            -- scope:setPortionComplete( i, #photos )
                                            yc = app:yield( yc )
                                        end
                                    end
                                else
                                    for i, photo in ipairs( photos ) do
                                        importValues( photo )
                                        if scope:isCanceled() then
                                            break
                                        else
                                            scope:setPortionComplete( i, #photos )
                                            yc = app:yield( yc )
                                        end
                                    end
                                end
                            end )
                            if s then
                                scope:setCaption( "Done." )
                            else
                                scope:setCaption( "Done, but errors..." )
                                app:error( m ) -- keeps from misleading stat.
                            end
                        else
                            app:show{ warning="No items are configured to be imported - please configure using plugin-manager/edit-advanced-settings." }
                            call:cancel()
                        end
                    end, finale=function( call, status, message )
                        if status and not call:isCanceled() then
                            app:show{ info="^1 updated, ^2 unchanged.", str:plural( call.nUpdated, "\"non-blank\" property", true ), call.nUnchanged }
                        end
                    end } )
				end
			},
			vf:static_text {
				title = str:format( "Import custom metadata to csv (with dir/file options)" ),
			},
		}
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    return sections
end



return SpecialManager
