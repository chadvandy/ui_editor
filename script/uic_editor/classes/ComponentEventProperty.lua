local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentEventProperty = {
    type = "ComponentEventProperty",
}

setmetatable(ComponentEventProperty, BaseClass)

ComponentEventProperty.__index = ComponentEventProperty
ComponentEventProperty.__tostring = BaseClass.__tostring

function ComponentEventProperty:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentEventProperty:decipher()
    local v = parser.root_uic:get_version()

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("property_name", "str", -1)
    deciph("property_value", "str", -1)

    return self
end

return ComponentEventProperty