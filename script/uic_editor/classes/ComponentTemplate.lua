local uied = core:get_static_object("ui_editor_lib")
local BaseClass = uied:get_class("BaseClass")

local parser = uied.parser

local ComponentTemplate = {
    type = "UIED_ComponentTemplate",
}

local function dec(key, format, k, obj)
    uied:log("decoding field with key ["..key.."] and format ["..format.."], within "..ComponentTemplate.type)
    return parser:dec(key, format, k, obj)
end

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

    -- local obj = uied:new_obj("ComponentTemplate")

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

    uied:log("Deciphering ComponentTemplate template children!")
    parser:decipher_collection("ComponentTemplateChild", self)
    
    uied:log("Deciphering ComponentTemplate component collection!")
    parser:decipher_collection("Component", self, true)

    return self
end




return ComponentTemplate