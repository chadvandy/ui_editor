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

-- -- TODO turn this into a ui_panel method???
-- function container:display()
--     -- first thing to do here is create the new expandable_row_header
--     local list_box = ui_editor_lib.display_data.list_box
--     local x_margin = ui_editor_lib.display_data.x_margin
--     local default_h = ui_editor_lib.display_data.default_h

--     if not is_uicomponent(list_box) then
--         -- errmsg
--         return false
--     end

--     -- TODO figure out how to save all the rows to the header
--     -- create the header_uic for the holder of the UIC

--     local header_uic = UIComponent(list_box:CreateComponent(self:get_key(), "ui/vandy_lib/expandable_row_header"))
--     header_uic:SetCanResizeWidth(true)
--     header_uic:SetCanResizeHeight(false)
--     header_uic:Resize(list_box:Width() * 0.95 - x_margin, header_uic:Height())
--     header_uic:SetCanResizeWidth(false)

--     if not default_h then ui_editor_lib.display_data.default_h = header_uic:Height() end

--     header_uic:SetDockingPoint(0)
--     header_uic:SetDockOffset(x_margin, 0)

--     -- TODO set a tooltip on the header uic entirely

--     local dy_title = find_uicomponent(header_uic, "dy_title")
--     dy_title:SetStateText(self:get_key())

--     -- move the x_margin over a bit
--     ui_editor_lib.display_data.x_margin = x_margin + 10

--     -- loop through every field in "data" and call its own display() method
--     local data = self:get_data()
--     for i = 1, #data do
--         local d_obj = data[i]
--         -- local d_key = d.key -- needed?
--         -- local d_obj = d.value

--         d_obj:display()
--     end

--     -- move the x_margin back to where it began here, after doing the internal loops
--     ui_editor_lib.display_data.x_margin = x_margin
-- end


return container