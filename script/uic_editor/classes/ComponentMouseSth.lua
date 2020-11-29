local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib.get_class("BaseClass")

local ComponentMouseSth = {
    type = "ComponentMouseSth",
}

setmetatable(ComponentMouseSth, BaseClass)

ComponentMouseSth.__index = ComponentMouseSth
ComponentMouseSth.__tostring = BaseClass.__tostring



function ComponentMouseSth:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.data = {}
    o.key = nil

    return o
end

return ComponentMouseSth