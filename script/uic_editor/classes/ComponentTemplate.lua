local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentTemplate = {
    type = "ComponentTemplate",
}

setmetatable(ComponentTemplate, BaseClass)

ComponentTemplate.__index = ComponentTemplate
ComponentTemplate.__tostring = BaseClass.__tostring



function ComponentTemplate:new(o)
    o = BaseClass:new(o)
    setmetatable(o, self)

    return o
end

function ComponentTemplate:decipher()
    local v = parser.root_uic:get_version()

    -- local obj = ui_editor_lib.new_obj("ComponentTemplate")

    local function deciph(key, format, k)
        return dec(key, format, k, self)
    end

    deciph("name", "str")

    if v >= 110 and v < 130 then
        deciph("ui-id", "hex", 4)

        if v >= 122 then
            deciph("b_sth", "hex", 16)
        end
    end

    parser:decipher_collection("ComponentTemplateChild", self)

    parser:decipher_collection("Component", self)

    return self
end




return ComponentTemplate