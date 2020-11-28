-- this file doesn't actually do anything, it's not even loaded by the UI Editor library. It just contains the functions that are copy-pasted into each class type.
-- TODO I would like this to actually use inheritance, so each of these functions are actually loaded into each type instead of being copy-pasted

local obj = {
    type = "UIED_BaseClass",
    data = {},

}
obj.__index = obj

function obj:new(o)
    o = o or {}
    setmetatable(o, self)
    return o
end

function obj:get_type()
    return self.type
end

-- TODO this
function obj:__tostring()
    return "BaseClass"
end

-- TODO construct the key somehow
-- when created, assign the key Type+Index, ie. "Component1"
-- then, assign the key through add_data if the field is "name" or "ui-id"
-- if ui-id is added but name was already added, keep name.
function obj:get_key()
    return self.key
end

function obj:add_data(data)
    -- TODO confirm that it's a valid obj

    local key = data:get_key()

    self.data[#self.data+1] = {key=key,value=data}

    return data
end

function obj:add_data_table(fields)
    for i = 1, #fields do
        self:add_data(fields[i])
    end
end

function obj:decipher()
    ModLog("decipher called on "..self:get_key().." but the decipher method has not been overriden!")
end


return obj