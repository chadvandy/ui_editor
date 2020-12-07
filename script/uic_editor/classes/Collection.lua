-- collection object is a special type of field that's just a full collection of smaller objects
-- used for collections of objects, such as "States" or "ComponentImages".

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local collection = {
    type = "UI_Collection",
}

function collection:__tostring()
    return "UI_Collection" -- TODO should this have the "UIED_" prepend?
end

function collection:new(key, val)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.key = key
    o.data = val

    o.state = "open"

    return o
end

function collection:filter_fields(key_filter, value_filter)
    local data = self.data

    for i = 1, #data do
        local inner = data[i]
        inner:filter_fields(key_filter, value_filter)
    end
end

-- TODO if collection:set_state() is called from collection:switch_state(), then hide children headers. else, don't hide them
function collection:switch_state()
    local state = self.state
    local new_state = "closed"

    if state == "closed" then
        new_state = "open"
    end

    self:set_state(new_state)
end

function collection:set_state(state)
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

        local canvas = parent:Find(id.."_canvas")

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

function collection:set_uic(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    self.uic = uic
end

function collection:get_uic()
    local uic = self.uic
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    return uic
end

function collection:get_type()
    return "UI_Collection"
end

function collection:get_hex()
    -- local data = self.data
    local len = #self.data

    

end

-- disable :set_key() on collection
function collection:set_key()
    return
end

function collection:get_key()
    return self.key
end

function collection:get_data()
    return self.data
end

function collection:add_data(new_field)
    -- TODO type check if it's a Field
    -- local key = new_field:get_key()

    self.data[#self.data+1] = new_field

    return new_field
end

function collection:add_data_table(fields)
    for i = 1, #fields do
        self:add_data(fields[i])
    end
end

return collection