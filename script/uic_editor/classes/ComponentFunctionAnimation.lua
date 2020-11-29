local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local parser = ui_editor_lib.parser
local function dec(key, format, k, obj)
    ModLog("decoding field with key ["..key.."] and format ["..format.."]")
    return parser:dec(key, format, k, obj)
end

local ComponentFunctionAnimation = {
    type = "ComponentFunctionAnimation",
}

setmetatable(ComponentFunctionAnimation, BaseClass)

ComponentFunctionAnimation.__index = ComponentFunctionAnimation
ComponentFunctionAnimation.__tostring = BaseClass.__tostring



function ComponentFunctionAnimation:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.data = {}
    o.key = nil

    return o
end

-- TODO do this later :)
function ComponentFunctionAnimation:decipher()
    local v = parser.root_uic:get_version()

    -- local obj = ui_editor_lib.new_obj("ComponentFunctionAnimation")

    local function deciph(key, format, k)
        dec(key, format, k, self)
    end

    if v >= 110 and v < 130 then

    end
end

return ComponentFunctionAnimation