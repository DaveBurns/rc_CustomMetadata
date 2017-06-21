--[[
        Metadata.lua
        
        See '*** Instructions' below for how to customize to your liking...
--]]


local metadataTable = {} -- return table
local photoMetadata = {} -- photo metadata definition table



--[[
        *** Instructions:
        
            - Delete whichever fields you don't want.
            - Add more fields if you like.
            - rename fields to suit.
            - change field properties, or not.
            
            For more info read "The Guide":         http://www.adobe.com/devnet/photoshoplightroom/pdfs/lightroom_sdk_guide.pdf
            Lua language reference:                 http://www.lua.org/manual/
            SDK Download:                           http://www.adobe.com/devnet/photoshoplightroom/

        photo-metadata field property definitions:
            
            id - used by plugin code only, but must consist of only letters, digits, and the underscore character, but must begin with a letter.
            version - only need to bump this if Lightroom isn't taking your changes, OR you want to use it in the update function.
            
            title => add to library panel with this name/label (pre-requisite for searchable)
            searchable => add to library filters (pre-requisite for browsable)
            browsable => add to smart collections
            
            dataType - string or enum are the only things that make sense @LR3.5.
                Hopefully Adobe will add boolean, number, and date soon.
                Tip: you can handle boolean (true/false) as enums for now.
            
        *** IMPORTANT NOTE: If you modify the plugin algorithm code, remember to always convert browsable data (except enum) to string before writing,
                            else smart collections will appear broken to the user.            
--]]

            -- *** Do not change id of this field (or be sure to change id in advanced settings too):
photoMetadata[#photoMetadata + 1] = { id='groups', version=1, dataType='string', title='Groups', searchable=true, browsable=true }
            -- Group "properties" - same format as regular properties, except using cr/lf as property separator, and double-cr/lf as group separator:
               -- name={group-name}
               -- rep={photo-filename}|me
               -- id={uuid of rep}
               -- type={HDR|Pano|...}
            -- *** THIS FIELD IS FOR PROGRAMMATIC ACCESS ONLY AND SHOULD NOT BE EDITED BY USER.

photoMetadata[#photoMetadata + 1] = { id='my_properties', version=3, dataType='string', title='Properties', searchable=true, browsable=true }
			-- Format (by personal convention only - not mandated): key1=value1; key2; key3=value; ... (value optional)
			-- initial application: Lr collection definition support.
            -- example use to support collections:
                -- TreatAs=RAW|JPG
            -- This field can be used any way you like - think of it as a miscellenous field with a more catchy title...

photoMetadata[#photoMetadata + 1] = { id='my_notes_private', version=1, title='Notes (Private)', dataType='string', searchable=true, browsable=true }
			-- notes for photograph manager's eyes only - never exported.
			-- motivation: to be able to have a field for personal comments that will never be seen by others who aquire an exported copy.

photoMetadata[#photoMetadata + 1] = { id='my_notes_public', version=1, title='Notes (Public)', dataType='string', searchable=true, browsable=true }
			-- notes for all to see - exported.
			-- motivation: comments specifically targeted to receiver of exported copy - this may be the only custom metadata field exported.

photoMetadata[#photoMetadata + 1] = { id='my_to_do', version=1, title='To Do', dataType='string', searchable=true, browsable=true }
			-- "To do" notes... - often used in conjunction with the red label...

photoMetadata[#photoMetadata + 1] = { id='my_edit_history', version=2, title='Edit Notes', dataType='string', searchable=true, browsable=true }
			-- use this instead of workflow fields for:
			   -- edit history notes
			   -- reminders for editing in future
			   -- editing closed - handed off to another (real or virtual) copy.

photoMetadata[#photoMetadata + 1] = { id='my_source_notes', version=2, title='Acquisition Notes', dataType='string', searchable=true, browsable=true }
			-- source of master image file, examples:
			  -- capture date estimated
              -- photo-of-photo
              -- scan-of-photo.
              -- Acquired from friend.
              -- Photo setup - teleconverters, extension tubes, shot-from-tripod, lighting...

photoMetadata[#photoMetadata + 1] = { id='my_content_notes', version=2, title='Content Details', dataType='string', searchable=true, browsable=true }
			-- Acts as an extension to IPTC 'Image' block, the former of which I use thusly:
			   -- 'Scene': one level of refinement of 'Location'.
               -- 'Intellectual Genre': Fairly freeform, may have a "Keyword Summary" flavor, or maybe a "More specific than keywords" flavor, but generally short-n-sweet.
			-- Subject/content details are any notes about the content that does not fit in other fields as my convention dictates.

photoMetadata[#photoMetadata + 1] = { id='my_states', version=1, title='State', dataType='enum', values = { { value=nil, title='No action required' }, { value='todo', title='Action required' } }, searchable=true, browsable=true }
            -- Defaults to 'No action required'.
            -- Allows one to check/set photo status...
            -- (note to self: version 2 may already be taken in my small test catalog).
            -- I don't use this field, since just checking if 'To Do' text contains 'a e i o u', satisfies the "action required" criteria for me, and I usually set the red label if it's "urgent".
            
photoMetadata[#photoMetadata + 1] = { id='my_url', version=1, title='Reference URL', dataType='url', searchable=true, browsable=true }
            -- Defaults to 'No action required'.
            -- Allows one to check/set photo status...
            -- (note to self: version 2 may already be taken in my small test catalog).
            -- I don't use this field, since just checking if 'To Do' text contains 'a e i o u', satisfies the "action required" criteria for me, and I usually set the red label if it's "urgent".
            
--[[
        Update metadata from previous schema to new schema, if need be.
        
        No sense of having this until if/when schema version is bumped...
--]]        
-- local function updateFunc( catalog, previousSchemaVersion )
-- end



metadataTable.metadataFieldsForPhotos = photoMetadata
metadataTable.schemaVersion = 1
-- metadataTable.updateFromEarlierSchemaVersion = updateFunc



return metadataTable
    

