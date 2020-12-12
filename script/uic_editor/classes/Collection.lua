-- collection object is a special type of field that's just a full collection of smaller objects
-- used for collections of objects, such as "States" or "ComponentImages".

local ui_editor_lib = core:get_static_object("ui_editor_lib")
local BaseClass = ui_editor_lib:get_class("BaseClass")

local Collection = {
    type = "UI_Collection",
}

setmetatable(Collection, BaseClass)

Collection.__index = Collection
Collection.__tostring = BaseClass.__tostring

function Collection:new(key, val)
    local o = BaseClass:new()
    
    setmetatable(o, self)

    o.key = key
    o.data = val

    o.state = "closed"

    return o
end


function Collection:filter_fields(key_filter, value_filter)
    local data = self.data

    for i = 1, #data do
        local inner = data[i]
        inner:filter_fields(key_filter, value_filter)
    end
end

function Collection:set_uic(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    self.uic = uic
end

function Collection:get_uic()
    local uic = self.uic
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    return uic
end

function Collection:get_hex()
    -- local data = self.data
    local len = #self.data

    local hex = ui_editor_lib.parser:int32_to_chunk(len)

    return hex
end

-- disable :set_key() on collection
function Collection:set_key()
    return
end

-- function Collection:get_key()
--     return self.key
-- end

-- function Collection:get_data()
--     return self.data
-- end

-- function Collection:add_data(new_field)
--     -- TODO type check if it's a Field
--     -- local key = new_field:get_key()

--     self.data[#self.data+1] = new_field

--     return new_field
-- end

-- function Collection:add_data_table(fields)
--     for i = 1, #fields do
--         self:add_data(fields[i])
--     end
-- end

return Collection