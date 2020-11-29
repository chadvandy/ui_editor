-- this file doesn't actually do anything, it's not even loaded by the UI Editor library. It just contains the functions that are copy-pasted into each class type.
-- TODO I would like this to actually use inheritance, so each of these functions are actually loaded into each type instead of being copy-pasted

local obj = {
    type = "BaseClass",

    key_type = "none",
}
obj.__index = obj

-- TODO better tostring?
obj.__tostring = function(self) return self:get_type() end


-- TODO call BaseClass:new() through all Class:new() calls. Should help clear out any necessary field (like data/key)
function obj:new(o)
    o = o or {}
    setmetatable(o, self)

    o.data = {}

    return o
end

function obj:get_type()
    return "UIED_" .. self.type
end

-- TODO this; save the header UIC to the obj, and loop through all children when opening/closing this obj to set their child UIC visible/invisible
function obj:set_state()

end

function obj:set_uic()

end



function obj:get_key()
    return self.key or "No Key Found"
end

function obj:get_data()
    return self.data
end

-- TODO construct the key somehow
-- when created, assign the key Type+Index, ie. "Component1"
-- then, assign the key through add_data if the field is "name" or "ui-id"
-- if ui-id is added but name was already added, keep name.
function obj:set_key(key, new_key_type)
    ModLog("set_key() called on obj with type "..self:get_type())
    local key_type = self.key_type
    local current_key = self:get_key()

    -- TODO resolve dis
    new_key_type = new_key_type or "none"

    if key_type == new_key_type or key == self.key then
        -- already added
        return
    end

    -- if there's no current key_type, anything assigned is valid
    if key_type == "none" then
        self.key = key
        self.key_type = new_key_type
    -- if the current key_type is index, anything but none is valid
    elseif key_type == "index" then
        if new_key_type ~= "none" then
            self.key = key
            self.key_type = new_key_type
        end
    -- if the current key_type is ui-id, only "name" is valid
    elseif key_type == "ui-id" then
        if new_key_type == "name" then
            self.key = key
            self.key_type = new_key_type
        end
    -- if the current key_type is name, nothing is valid
    elseif key_type == "name" then
        -- do nuffin?
    end

    ModLog("old key ["..current_key.."], new key ["..self.key.."].")
end

function obj:add_data(data)
    -- TODO confirm that it's a valid obj

    -- if a Field is being added, check if it's a name or ui-id, then add it as key
    if string.find(tostring(data), "UI_Field") then
        if data:get_key() == "name" then
            self:set_key(data:get_value(), "name")
        elseif data:get_key() == "ui-id" then
            self:set_key(data:get_value(), "ui-id")
        end
    end

    ModLog("Add Data called, ["..self:get_key().."] is getting a fresh new ["..tostring(data).."] with key ["..data:get_key().."].")

    if self:get_key() == "dy_txt" then
        ModLog("VANDY VANDY VANDY")
        ModLog("Adding data to dy_txt, data is: "..tostring(data))
    end

    self.data[#self.data+1] = data

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