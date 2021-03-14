local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentImage = {
    type = "UIED_ComponentImage",
}

setmetatable(ComponentImage, BaseClass)

ComponentImage.__index = ComponentImage
ComponentImage.__tostring = BaseClass.__tostring

function ComponentImage:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentImage:create_default()
    local ui_id = parser:regenerate_uiid()
    local img_path = "00 00"

    local w = "00 00 00 00"
    local h = "00 00 00 00"

    local unknonwn_bool = "00"

    
end

function ComponentImage:decipher()
    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- first 4 are the ui-id
    -- the UI-ID
    deciph("ui-id","hex",4)

    -- image path (can be optional)
    deciph("img_path", "str", -1)

    -- get the width + height
    deciph("w", "int32", 4)
    deciph("h", "int32", 4)

    -- TODO decode
    deciph("unknown_bool", "hex", 1)

    return self
end

return ComponentImage