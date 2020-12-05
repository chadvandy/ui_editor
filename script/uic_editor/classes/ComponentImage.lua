local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ui_editor_lib.log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentImage = {
    type = "ComponentImage",
}

setmetatable(ComponentImage, BaseClass)

ComponentImage.__index = ComponentImage
ComponentImage.__tostring = BaseClass.__tostring

function ComponentImage:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentImage:decipher()
    -- local obj = ui_editor_lib.classes.ComponentImage:new()

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- first 4 are the ui-id
    -- the UI-ID
    deciph("ui-id","hex",4)

    -- image path (can be optional)
    deciph("img_path", "str", -1)

    -- get the width + height
    deciph("w", "int16", 4)
    deciph("h", "int16", 4)

    -- TODO decode
    deciph("unknown_bool", "hex", 1)

    return self
end

return ComponentImage