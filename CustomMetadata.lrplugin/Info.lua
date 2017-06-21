--[[
        Info.lua
--]]

return {
    appName = "Custom Metadata",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.CustomMetadata", -- for update checking (which isn't supported for this plugin - for good reason).
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc Custom Metadata",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/CustomMetadataLrPlugin/",
    LrPluginInfoProvider = "SpecialManager.lua",
    LrToolkitIdentifier = "com.robcole.lightroom.CustomMetadata", -- *** THIS MUST MATCH PREVIOUS VALUE OR YOUR METADATA WILL SEEM TO HAVE "DISAPPEARED".
    LrInitPlugin = "Init.lua",
    LrEnablePlugin = "Enable.lua",
    LrDisablePlugin = "Disable.lua",
    LrMetadataProvider = "Metadata.lua",
    LrExportFilterProvider = {
        title = "Transfer Custom Metadata",
        file = "ExtendedExportFilter.lua",
        id = "com.robcole.exportfilter.CustomMetadata",
    },
    LrExportMenuItems = {
        { title="&Sync Custom Metadata", file="mManualSync.lua" },
        { title="&Define Group", file="mDefineGroup.lua" },
        { title="&Add to Group", file="mAddToGroup.lua" },
        { title="&Remove from Group", file="mRemoveFromGroup.lua" },
        { title="&Select Group", file="mSelectGroup.lua" },
        { title="&Delete Group", file="mDeleteGroup.lua" },
        { title="&Collect Group", file="mCollectGroup.lua" },
    },
    VERSION = { major=4, minor=6, revision=1, build = 0 },
}
