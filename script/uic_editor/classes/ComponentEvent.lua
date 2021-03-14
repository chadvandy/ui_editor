local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentEvent = {
    type = "UIED_ComponentEvent",
}

setmetatable(ComponentEvent, BaseClass)

ComponentEvent.__index = ComponentEvent
ComponentEvent.__tostring = BaseClass.__tostring

function ComponentEvent:new(o)
    o = BaseClass:new(o)

    setmetatable(o, self)

    return o
end

function ComponentEvent:decipher()
    local v = parser.root_uic:get_version()

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    -- three strings - callback_id, context_object_id, context_function_id
    deciph("callback_id", "str", -1)
    deciph("context_object_id", "str", -1)
    deciph("context_function_id", "str", -1)

    -- potential child - ComponentEventProperties, which is two strings
    --- TODO prove that this is accurate!
    if v >= 120 then
        parser:decipher_collection("ComponentEventProperty", self)
    end

    return self
end


return ComponentEvent