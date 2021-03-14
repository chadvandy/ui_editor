local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentFunctionAnimationTrigger = {
    type = "UIED_ComponentFunctionAnimationTrigger",
}

setmetatable(ComponentFunctionAnimationTrigger, BaseClass)

ComponentFunctionAnimationTrigger.__index = ComponentFunctionAnimationTrigger
ComponentFunctionAnimationTrigger.__tostring = BaseClass.__tostring

function ComponentFunctionAnimationTrigger:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentFunctionAnimationTrigger:decipher()
    local v = parser.root_uic:get_version()


    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("ui-id", "hex", 4)

    if v >= 125 and v < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("animation", "str", -1)
    deciph("state", "str", -1)
    deciph("property", "str", -1)

    return self
end

return ComponentFunctionAnimationTrigger