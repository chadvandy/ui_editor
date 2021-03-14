local uied = core:get_static_object("ui_editor_lib")
local parser = uied.parser

local obj = {
    type = "UI_BaseClass",

    key_type = "none",
}
obj.__index = obj

-- TODO better tostring?
obj.__tostring = function(self) return self:get_type() end

function obj:new(o)
    o = o or {}
    setmetatable(o, self)

    o.data = o.data or {}
    o.key = o.key or nil

    o.parent = o.parent or nil

    o.uic = nil
    o.state = "invisible"

    return o
end

function obj:get_parent()
    return self.parent
end

function obj:set_parent(p)
    self.parent = p
end

function obj:filter_fields(key_filter, value_filter)
    local data = self.data

    for i = 1, #data do
        local inner = data[i]
        inner:filter_fields(key_filter, value_filter)
    end
end

function obj:get_type()
    return self.type
end

-- This is called whenever a header is pressed, which switches its state and triggers a change on all children fields and objects
function obj:switch_state()
    uied:log("Switching state for ["..self:get_key().."].")
    local state = self.state
    local new_state = ""
    local child_state = ""

    if state == "closed" then
        new_state = "open"
        child_state = "closed"
    elseif state == "open" then
        new_state = "closed"
        child_state = "invisible"
    end

    local ok, err = pcall(function()

    -- self.state = new_state
    self:set_state(new_state)

    local data = self:get_data()

    for i = 1, #data do
        local datum = data[i]

        if string.find(tostring(datum), "UI_Field") then
            -- if state is open, create
            if new_state == "open" then
                uied.ui:create_details_row_for_field(datum, self:get_uic())
            else -- closed; destroy
                -- uied:log("Trying to delete a field within obj ["..self:get_key().."].")
                -- -- uied.ui:delete_component(datum:get_uic())
                -- uied:log("Deleted field ["..datum:get_key().."]")
                -- datum.uic = nil
            end
        else
            datum:set_state(child_state)
        end
    end

    -- TODO error check
    -- local uic = self:get_uic()
    -- local parent = UIComponent(uic:Parent())
    -- local id = uic:Id()

    -- local canvas = UIComponent(parent:Find(id.."_canvas"))

    -- if new_state == "closed" then
    --     -- hide the listbox!
    --     -- resize it to puny so it fixes everything!
    --     canvas:SetVisible(false)
    --     canvas:Resize(canvas:Width(), 5)
    -- else
    --     canvas:SetVisible(true)
    -- end

end) if not ok then uied:log(err) end
end

-- This is only called through switch_state(), which will trigger on self as well as on all children.
function obj:set_state(state)
    self.state = state

    uied:log("Setting state of ["..self:get_key().."] to ["..state.."].")

    -- set the state of the header (invisible if inner?)
    local uic = self:get_uic()
    if is_uicomponent(uic) then
        if state == "open" then
            uic:SetVisible(true)
            uic:SetState("selected")
        elseif state == "closed" then
            uic:SetVisible(true)
            uic:SetState("active")
        elseif state == "invisible" then
            -- TODO hide all canvas and shit
            uic:SetVisible(false)
            uic:SetState("active")
        end
    end
end

function obj:set_uic(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end
    
    self.uic = uic
end

function obj:get_uic()
    local uic = self.uic
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    return uic
end

function obj:get_key()
    return self.key or "No Key Found"
end

function obj:get_data()
    return self.data
end

-- when created, assign the key Type+Index, ie. "Component1"
-- then, assign the key through add_data if the field is "name" or "ui-id"
-- if ui-id is added but name was already added, keep name.
function obj:set_key(key, new_key_type)
    uied:log("set_key() called on obj with type "..self:get_type())
    local key_type = self.key_type
    local current_key = self:get_key()

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

    uied:log("old key ["..current_key.."], new key ["..self.key.."].")
end

-- remove a field or object or collection from this object
function obj:remove_data(datum)
    uied:log("Remove data called! "..self:get_key().." is deleting data ["..datum:get_key().."].")
    local data = self:get_data()

    local new_table = {}

    for i = 1, #data do
        local inner = data[i]

        if inner == datum then
            uied:log("Inner found!")
        else
            new_table[#new_table+1] = inner
        end
    end

    -- replace the data field
    self.data = new_table
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

    uied:log("Add Data called, ["..self:get_key().."] is getting a fresh new ["..tostring(data).."] with key ["..data:get_key().."].")

    if self:get_key() == "dy_txt" then
        uied:log("VANDY VANDY VANDY")
        uied:log("Adding data to dy_txt, data is: "..tostring(data))
    end

    self.data[#self.data+1] = data

    data:set_parent(self)

    return data
end

function obj:add_data_table(fields)
    for i = 1, #fields do
        self:add_data(fields[i])
    end
end

function obj:decipher()
    uied:log("decipher called on "..self:get_key().." but the decipher method has not been overriden!")
    return
end

function obj:create_default()
    uied:log("create_default called on "..self:get_key().." but the create_default method has not been overriden!")
    return
end

return obj