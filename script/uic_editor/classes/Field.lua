-- this is the Lua object for the "uic_field" bit of data within the UIC layout files.
-- this is done for a few reasons: to store accessible data easily in tables like this (which are easy to garbage collect), to make it more accessible and less hard-coded, and it's partially just for the fun of it if I'm being honest

-- TODO resolve if I even need them to be a separate obj like this (leaning towards probably yes)

-- TODO make this comparable to BaseClass - use data as a table instead of value as a changable type; use an array 

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local uic_field = {}

function uic_field:__tostring()
    return "UI_Field" -- TODO this shouldn't be "UIED" should it?
end

function uic_field:new(key, value, hex)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.key = key
    o.value = value
    o.hex = hex

    return o
end

function uic_field:get_key()
    return self.key
end

function uic_field:get_value()
    return self.value
end

function uic_field:get_hex()
    return self.hex or "no hex found"
end

function uic_field:get_is_deciphered()
    return self.is_deciphered
end

-- returns the localised text + tooltip text for this field, using the "key" field
function uic_field:get_display_text()
    local key = self:get_key()

    local text = effect.get_localised_string("layout_parser_"..key.."_text")
    local tt   = effect.get_localised_string("layout_parser_"..key.."_tt")

    local value = self:get_value()
    local value_str
    if is_table(value) then

        -- construct the string from the table
        local str = ""
        for k,v in pairs(value) do
            str = str .. tostring(k) .. ": ".. tostring(v) .. " "
        end
        value_str = str
    else
        value_str = tostring(value)
    end

    if not text or text == "" then
        text = key
    end
    
    if not tt or tt == "" then
        tt = "Tooltip not found"
    end

    return text,tt,value_str
end

-- function uic_field:display()
--     local list_box = ui_editor_lib.display_data.list_box
--     local x_margin = ui_editor_lib.display_data.x_margin
--     local default_h = ui_editor_lib.display_data.default_h

--     if not is_uicomponent(list_box) then
--         ModLog("display called on field ["..self:get_key().."], but the list box don't exist yo")
--         return false
--     end

--     -- TODO get this working betterer for tables

--     local key = self:get_key()
--     local type_text,tooltip_text,value_text = self:get_display_text()

--     local row_uic = UIComponent(list_box:CreateComponent(key, "ui/campaign ui/script_dummy"))

--     row_uic:SetCanResizeWidth(true) row_uic:SetCanResizeHeight(true)
--     row_uic:Resize(list_box:Width() * 0.95 - x_margin, default_h)
--     row_uic:SetCanResizeWidth(false) row_uic:SetCanResizeHeight(false)
--     row_uic:SetInteractive(true)

--     row_uic:SetDockingPoint(0)
--     row_uic:SetDockOffset(x_margin, 0)

--     row_uic:SetTooltipText(tooltip_text, true)

--     local left_text_uic = UIComponent(row_uic:CreateComponent("left_text_uic", "ui/vandy_lib/text/la_gioconda/unaligned"))
--     left_text_uic:Resize(row_uic:Width() * 0.3, row_uic:Height() * 0.9)
--     left_text_uic:SetStateText("[[col:white]]"..type_text.."[[/col]]")
--     left_text_uic:SetVisible(true)
--     left_text_uic:SetDockingPoint(4)
--     left_text_uic:SetDockOffset(5, 0)

--     left_text_uic:SetTooltipText(tooltip_text, true)
    
--     local right_text_uic = UIComponent(row_uic:CreateComponent("right_text_uic", "ui/vandy_lib/text/la_gioconda/unaligned"))
--     right_text_uic:Resize(row_uic:Width() * 0.65, row_uic:Height() * 0.9)
--     right_text_uic:SetStateText("[[col:white]]"..value_text.."[[/col]]")
--     right_text_uic:SetVisible(true)
--     right_text_uic:SetDockingPoint(6)
--     right_text_uic:SetDockOffset(-20, 0)

--     right_text_uic:SetTooltipText(self:get_hex(), true)
-- end

return uic_field