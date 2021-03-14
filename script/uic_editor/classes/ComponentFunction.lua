local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentFunction = {
    type = "UIED_ComponentFunction",
}

setmetatable(ComponentFunction, BaseClass)

ComponentFunction.__index = ComponentFunction
ComponentFunction.__tostring = BaseClass.__tostring

function ComponentFunction:new(o)
    o = BaseClass:new(o)

    setmetatable(o, self)

    return o
end

function ComponentFunction:decipher()
    local v = parser.root_uic:get_version()

    -- local obj = uied:new_obj("ComponentFunction")

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("name", "str", -1)

    deciph("b0", "hex", 2)

    parser:decipher_collection("ComponentFunctionAnimation", self)

    if v >= 91 and v <= 93 then
        deciph("b1", "hex", 2)
    elseif v >= 95 and v < 97 then
        deciph("b1", "hex", 2)
    elseif v >= 97 and v < 100 then
        deciph("str_sth", "str")
    elseif v >= 110 and v < 130 then
        deciph("str_sth", "str")
        deciph("b1", "str")
    end

    return self
end


return ComponentFunction