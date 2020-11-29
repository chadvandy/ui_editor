-- container object is a special type of field that's just a full collection of smaller objects
-- used for collections of objects, such as "States" or "ComponentImages".

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local container = {
    type = "UI_Container",
}

function container:__tostring()
    return "UI_Container" -- TODO should this have the "UIED_" prepend?
end

function container:new(key, val)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.key = key
    o.data = val

    return o
end

function container:set_state(state)
    local data = self:get_data()

    for i = 1, #data do
        local inner = data[i]
        inner:set_state(state)
    end

    -- set the state of the header (invisible if inner?)
end

function container:set_uic(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    self.uic = uic
end

function container:get_uic()
    local uic = self.uic
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    return uic
end

function container:get_type()
    return "UI_Container"
end

-- disable :set_key() on container
function container:set_key()
    return
end

function container:get_key()
    return self.key
end

function container:get_data()
    return self.data
end

function container:add_data(new_field)
    -- TODO type check if it's a Field
    -- local key = new_field:get_key()

    self.data[#self.data+1] = new_field

    return new_field
end

function container:add_data_table(fields)
    for i = 1, #fields do
        self:add_data(fields[i])
    end
end

return container