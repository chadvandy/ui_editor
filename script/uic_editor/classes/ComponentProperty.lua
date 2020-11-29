local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentProperty = {
    type = "ComponentProperty",
}

setmetatable(ComponentProperty, BaseClass)

ComponentProperty.__index = ComponentProperty
ComponentProperty.__tostring = BaseClass.__tostring

function ComponentProperty:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.data = {}
    o.key = nil

    return o
end

function ComponentProperty:decipher()
    local v = parser.root_uic:get_version()

    -- local obj = ui_editor_lib.new_obj("ComponentProperty")

    local function deciph(key, format, k)
        dec(key, format, k, self)
    end

    -- TODO rename
    deciph("str1", "str", -1)
    deciph("str2", "str", -1)

    return self
end

return ComponentProperty