local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentProperty = {
    type = "UIED_ComponentProperty",
}

setmetatable(ComponentProperty, BaseClass)

ComponentProperty.__index = ComponentProperty
ComponentProperty.__tostring = BaseClass.__tostring

function ComponentProperty:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentProperty:decipher()
    local v = parser.root_uic:get_version()

    -- local obj = uied:new_obj("ComponentProperty")

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- TODO rename
    deciph("str1", "str", -1)
    deciph("str2", "str", -1)

    return self
end

return ComponentProperty