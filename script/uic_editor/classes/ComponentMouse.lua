-- TODO this is "transitionmap", I believe


local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser
local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentMouse = {
    type = "UIED_ComponentMouse",
}

setmetatable(ComponentMouse, BaseClass)

ComponentMouse.__index = ComponentMouse
ComponentMouse.__tostring = BaseClass.__tostring

function ComponentMouse:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentMouse:decipher()
    local v = parser.root_uic:get_version()

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("mouse_state", "hex", 4)
    deciph("state_ui-id", "hex", 4)

    if v >= 122 and v < 130 then
        deciph("b_sth", "hex", 16)
    end

    deciph("b0", "hex", 8)

    parser:decipher_collection("ComponentMouseSth", self)

    return self
end

return ComponentMouse