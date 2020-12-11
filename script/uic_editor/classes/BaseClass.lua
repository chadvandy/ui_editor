local ui_editor_lib = core:get_static_object("ui_editor_lib")
local parser = ui_editor_lib.parser

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

    o.uic = nil
    o.state = "open"

    return o
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

-- if ui_editor_lib.is_large_file then
--     ui_editor_lib:log("Header pressed!")
--     local data = obj:get_data()
    
--     for i = 1, #data do
--         local datum = data[i]
--         if string.find(tostring(datum), "UI_Field") then
--             -- TODO make this cleaner, too
--             ui_obj:create_details_row_for_field(datum, obj:get_uic())
--         end
--     end

--     local list_box = ui_obj.details_data.list_box
--     list_box:Layout()
-- else

function obj:switch_state()
    local state = self.state
    local new_state = "closed"

    if state == "closed" then
        new_state = "open"
    end

    self:set_state(new_state)
end

function obj:set_state(state)
    self.state = state

    local data = self:get_data()

    if ui_editor_lib.is_large_file then
        for i = 1, #data do
            local datum = data[i]

            -- only trigger on Field children
            if string.find(tostring(datum), "UI_Field") then
                -- if state is open, create
                if state == "open" then
                    ui_editor_lib.ui:create_details_row_for_field(datum, self:get_uic())
                else -- closed; destroy
                    ui_editor_lib.ui:delete_component(datum:get_uic())
                end
            end
        end

        -- TODO error check
        local uic = self:get_uic()
        local parent = UIComponent(uic:Parent())
        local id = uic:Id()

        local canvas = UIComponent(parent:Find(id.."_canvas"))

        if state == "closed" then
            -- hide the listbox!
            canvas:SetVisible(false)
        else
            canvas:SetVisible(true)
        end
    else
        for i = 1, #data do
            local inner = data[i]
            inner:set_state(state)
        end
    end
  
    -- set the state of the header (invisible if inner?)
    local uic = self.uic
    if is_uicomponent(uic) then
        if state == "open" then
            uic:SetState("selected")
        else
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
    ui_editor_lib:log("set_key() called on obj with type "..self:get_type())
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

    ui_editor_lib:log("old key ["..current_key.."], new key ["..self.key.."].")
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

    ui_editor_lib:log("Add Data called, ["..self:get_key().."] is getting a fresh new ["..tostring(data).."] with key ["..data:get_key().."].")

    if self:get_key() == "dy_txt" then
        ui_editor_lib:log("VANDY VANDY VANDY")
        ui_editor_lib:log("Adding data to dy_txt, data is: "..tostring(data))
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
    ui_editor_lib:log("decipher called on "..self:get_key().." but the decipher method has not been overriden!")
    return
end

function obj:create_default()
    ui_editor_lib:log("create_default called on "..self:get_key().." but the create_default method has not been overriden!")
    return
end

return obj