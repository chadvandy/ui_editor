-- the actual physical for the UI, within the game.
-- weird concept, right?

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local ui_obj = {
    new_button = nil,
    opened = false,

    panel = nil,
    details_data = {},

    row_index = 1,
    rows_to_objs = {},
}

function ui_obj:delete_component(uic)
    if not is_uicomponent(self.dummy) then
        self.dummy = core:get_or_create_component("script_dummy", "ui/campaign ui/script_dummy")
    end

    local dummy = self.dummy

    if is_uicomponent(uic) then
        dummy:Adopt(uic:Address())
    elseif is_table(uic) then
        for i = 1, #uic do
            local test = uic[i]
            if is_uicomponent(test) then
                dummy:Adopt(test:Address())
            else
                -- ERROR WOOPS
            end
        end
    end

    dummy:DestroyChildren()
end


function ui_obj:init()
    local new_button
    if __game_mode == __lib_type_campaign or __game_mode == __lib_type_battle then
        local button_group = find_uicomponent(core:get_ui_root(), "menu_bar", "buttongroup")
        new_button = UIComponent(button_group:CreateComponent("button_ui_editor", "ui/templates/round_small_button"))

        new_button:SetTooltipText("UI Editor", true)
        --new_button:SetImagePath()

        new_button:PropagatePriority(button_group:Priority())

        button_group:Layout()
    elseif __game_mode == __lib_type_frontend then
        local button_group = find_uicomponent(core:get_ui_root(), "sp_frame", "menu_bar")

        new_button = UIComponent(button_group:CreateComponent("button_ui_editor", "ui/templates/round_small_button"))
        new_button:SetTooltipText("UI Editor", true)

        button_group:Layout()
    end

    if not new_button then return end

    self.button = new_button

    core:add_listener(
        "ui_editor_opened",
        "ComponentLClickUp",
        function(context)
            return UIComponent(context.component) == self.button
        end,
        function(context)
            self:button_pressed()
        end,
        true
    )
end

-- 
function ui_obj:button_pressed()
    if self.opened then
        self:close_panel()
    else
        self:open_panel()
    end
end

function ui_obj:close_panel()
    -- close the panel
    local panel = self.panel

    self:delete_component(panel)

    self.panel = nil
    self.opened = false
end

function ui_obj:open_panel()
    -- open da panel
    local panel = self.panel

    if is_uicomponent(panel) then
        panel:SetVisible(true)
    else
        self:create_panel()
    end
end

function ui_obj:create_panel()
    local root = core:get_ui_root()
    local panel = UIComponent(root:CreateComponent("ui_editor", "ui/ui_editor/frame"))

    panel:SetVisible(true)

    ModLog("test 1")

    self.panel = panel

    --panel:PropagatePriority(5000)
    --panel:LockPriority()

    panel:SetCanResizeWidth(true) panel:SetCanResizeHeight(true)

    
    ModLog("test 2")

    local sw,sh = core:get_screen_resolution()
    panel:Resize(sw*0.95, sh*0.95)

    panel:SetCanResizeWidth(false) panel:SetCanResizeHeight(false)

    ModLog("test 3")

    -- edit the name
    local title_plaque = find_uicomponent(panel, "title_plaque")
    local title = find_uicomponent(title_plaque, "title")
    title:SetStateText("UI Editor")

    ModLog("test 4")

    -- hide stuff from the gfx window
    local comps = {
        find_uicomponent(panel, "checkbox_windowed"),
        find_uicomponent(panel, "ok_cancel_buttongroup"),
        find_uicomponent(panel, "button_advanced_options"),
        find_uicomponent(panel, "button_recommended"),
        find_uicomponent(panel, "dropdown_resolution"),
        find_uicomponent(panel, "dropdown_quality"),
    }

    ModLog("test 5")

    self:delete_component(comps)

    -- create the close button!   
    local close_button_uic = core:get_or_create_component("ui_editor_close", "ui/templates/round_medium_button", panel)
    local img_path = effect.get_skinned_image_path("icon_cross.png")
    close_button_uic:SetImagePath(img_path)
    close_button_uic:SetTooltipText("Close panel", true)

    ModLog("test 6")

    -- move to bottom center
    close_button_uic:SetDockingPoint(8)
    close_button_uic:SetDockOffset(0, -5)

    self:create_sections()
end

-- create the independent sections of the UI
-- top left (majority of the screen) will be the Testing Grounds, where the demo'd UI actually is located
-- center right will be the Details Screen, where the bits of the UI can be properly viewed/edited
-- bottom will be buttons and some other things (fullscreen mode, new UIC, load UIC, etcetcetc)
function ui_obj:create_sections()
    local panel = self.panel

    local testing_grounds = UIComponent(panel:CreateComponent("testing_grounds", "ui/vandy_lib/custom_image_tiled"))
    testing_grounds:SetState("custom_state_2")

    local ow,oh = panel:Dimensions()
    local w,h = ow*0.6,oh*0.6-20

    testing_grounds:SetCanResizeWidth(true) testing_grounds:SetCanResizeHeight(true)
    testing_grounds:Resize(w,h) -- matches the resolution of the full screen
    testing_grounds:SetCanResizeWidth(false) testing_grounds:SetCanResizeHeight(false)

    testing_grounds:SetImagePath("ui/skins/default/panel_back_border.png", 1)
    testing_grounds:SetVisible(true)

    testing_grounds:SetDockingPoint(1)
    testing_grounds:SetDockOffset(10, 45)

    do
        local details_screen = UIComponent(panel:CreateComponent("details_screen", "ui/vandy_lib/custom_image_tiled"))
        details_screen:SetState("custom_state_2")

        local nw = ow-w-20
        local nh = oh-110

        details_screen:SetCanResizeWidth(true) details_screen:SetCanResizeHeight(true)
        details_screen:Resize(nw,nh)
        details_screen:SetCanResizeWidth(false) details_screen:SetCanResizeHeight(false)

        details_screen:SetImagePath("ui/skins/default/panel_stack.png", 1)
        details_screen:SetVisible(true)
    
        details_screen:SetDockingPoint(3)
        details_screen:SetDockOffset(-5, 45)

        local details_title = UIComponent(details_screen:CreateComponent("details_title", "ui/templates/panel_subtitle"))
        details_title:Resize(details_screen:Width() * 0.9, details_title:Height())
        details_title:SetDockingPoint(2)
        details_title:SetDockOffset(0, details_title:Height() * 0.1)
    
        local details_text = core:get_or_create_component("text", "ui/vandy_lib/text/la_gioconda/center", details_title)
        details_text:SetVisible(true)
    
        details_text:SetDockingPoint(5)
        details_text:SetDockOffset(0, 0)
        details_text:Resize(details_title:Width() * 0.9, details_title:Height() * 0.9)

        do
    
            local w,h = details_text:TextDimensionsForText("[[col:fe_white]]Details[[/col]]")
        
            details_text:ResizeTextResizingComponentToInitialSize(w, h)
            details_text:SetStateText("[[col:fe_white]]Details[[/col]]")
        
            details_title:SetTooltipText("Details are cool, m8", true)
            details_text:SetInteractive(false)
            --details_text:SetTooltipText("{{tt:mct_profiles_tooltip}}", true)

        end

        local list_view = UIComponent(details_screen:CreateComponent("list_view", "ui/vandy_lib/vlist"))
        list_view:SetCanResizeWidth(true) list_view:SetCanResizeHeight(true)
        list_view:Resize(nw-20, nh-details_title:Height()-50)
        list_view:SetDockingPoint(2)
        list_view:SetDockOffset(10, details_title:Height() + 5)
    
        local x,y = list_view:Position()
        local w,h = list_view:Bounds()
        ModLog("list view bounds: ("..tostring(w)..", "..tostring(h)..")")
    
        local lclip = find_uicomponent(list_view, "list_clip")
        lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
        lclip:SetDockingPoint(0)
        lclip:SetDockOffset(0, 0)
        lclip:Resize(w,h)

        ModLog("list clip bounds: ("..tostring(lclip:Width()..", "..tostring(lclip:Height())..")"))
    
        local lbox = find_uicomponent(lclip, "list_box")
        lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
        lbox:SetDockingPoint(0)
        lbox:SetDockOffset(0, 0)
        lbox:Resize(w-30,h)

        ModLog("list box bounds: ("..tostring(lbox:Width()..", "..tostring(lbox:Height())..")"))
    end

    do
        local buttons_holder = UIComponent(panel:CreateComponent("buttons_holder", "ui/vandy_lib/custom_image_tiled"))
        buttons_holder:SetState("custom_state_2")

        local nw = w-20
        local nh = oh-h-150

        buttons_holder:SetCanResizeWidth(true) buttons_holder:SetCanResizeHeight(true)
        buttons_holder:Resize(nw,nh)
        buttons_holder:SetCanResizeWidth(false) buttons_holder:SetCanResizeHeight(false)

        buttons_holder:SetImagePath("ui/skins/default/parchment_texture.png", 1)
        buttons_holder:SetVisible(true)
    
        buttons_holder:SetDockingPoint(7)
        buttons_holder:SetDockOffset(10, -85)

        self:create_buttons_holder()
    end
end

-- create the various buttons of the bottom bar
function ui_obj:create_buttons_holder()
    -- to start, just a "load" button that automatically loads "ui/templates/bullet_point"

    local panel = self.panel
    local buttons_holder = find_uicomponent(panel, "buttons_holder")
    if not is_uicomponent(buttons_holder) then
        -- errmsg
        return false
    end

    local load_button = core:get_or_create_component("ui_editor_load_button", "ui/templates/square_medium_button", buttons_holder)
    load_button:SetVisible(true)
    load_button:SetDockingPoint(5)
    load_button:SetDockOffset(0,0)
    load_button:SetInteractive(true)
end

function ui_obj:create_loaded_uic_in_testing_ground(is_copied)
    local path = ui_editor_lib.loaded_uic_path

    if is_copied then
        path = "data/UI/templates/TEST"
    end

    local panel = self.panel
    if not panel or not is_uicomponent(panel) or not path then
        ModLog("create loaded uic in testing ground failed")
        return false
    end

    local testing_grounds = find_uicomponent(panel, "testing_grounds")
    testing_grounds:DestroyChildren()

    local test_uic = UIComponent(testing_grounds:CreateComponent("testing_component", path))
    if not is_uicomponent(test_uic) then
        ModLog("test uic failed!")
        return false
    end

    test_uic:SetVisible(true)
    test_uic:SetDockingPoint(5)
    test_uic:SetDockOffset(0, 0)
end

function ui_obj:create_details_header_for_obj(obj)
    local list_box = self.details_data.list_box
    local x_margin = self.details_data.x_margin
    local default_h = self.details_data.default_h

    if not is_uicomponent(list_box) then
        ModLog("display called on obj ["..obj:get_key().."], but the list box don't exist yo")
        ModLog(tostring(list_box))
        return false
    end

    -- TODO figure out how to save all the rows to the header

    -- create the header_uic for the holder of the UIC
    local header_uic = UIComponent(list_box:CreateComponent("ui_header_"..self.row_index, "ui/vandy_lib/expandable_row_header"))

    self.rows_to_objs[tostring(self.row_index)] = obj
    self.row_index = self.row_index+1

    obj:set_uic(header_uic)

    header_uic:SetCanResizeWidth(true)
    header_uic:SetCanResizeHeight(false)
    header_uic:Resize(list_box:Width() * 0.95 - x_margin, header_uic:Height())
    header_uic:SetCanResizeWidth(false)

    if default_h == 0 then self.details_data.default_h = header_uic:Height() end

    -- TODO set a tooltip on the header uic entirely
    header_uic:SetDockingPoint(0)
    header_uic:SetDockOffset(x_margin, 0)

    local dy_title = find_uicomponent(header_uic, "dy_title")
    dy_title:SetStateText(obj:get_type() .. ": " .. obj:get_key())

    local child_count = find_uicomponent(header_uic, "child_count")
    if obj:get_type() == "UI_Container" then
        local str = tostring(#obj.data)
        if not str or str == "" then
            child_count:SetVisible(false)
        else
            child_count:SetStateText(tostring(#obj.data))
        end
    else
        child_count:SetVisible(false)
    end

    -- move the x_margin over a bit
    self.details_data.x_margin = x_margin + 10

    -- loop through every field in "data" and call its own display() method
    local data = obj:get_data()

    -- ModLog("hand-crafting details header for obj ["..obj:get_key().."] with type ["..obj:get_type().."].\nNumber of data is: "..tostring(#data))

    for i = 1, #data do
        -- ModLog("in ["..tostring(i).."] within obj ["..obj:get_key().."].")
        local d = data[i]
        -- local d_key = d.key -- needed?
        local d_obj

        -- ModLog("Testing obj: "..tostring(d))
        -- ModLog("")

        if obj:get_key() == "dy_txt" then
            -- ModLog("VANDY LOOK HERE")
            -- ModLog(i.."'s key: " .. d:get_key())
            if tostring(d) == "UI_Field" then
                -- ModLog(i.."'s val: " .. tostring(d:get_value()))
            end
        end

        if string.find(tostring(d), "UIED_") or string.find(tostring(d), "UI_Container") or string.find(tostring(d), "UI_Field") then
            -- ModLog("inner child is a class")
            d_obj = d
        -- elseif type(d) == "table" then
        --     ModLog("inner child is a table")
        --     if not is_nil(d.value) then
        --         d_obj = d.value
        --     else
        --         ModLog("inner child table doesn't ")
        --     end
        else
            -- TODO errmsg
            ModLog("inner child is not a field or a class, Y")
            -- TODO resolve what to do if it's just a raw value?
        end

        if is_nil(d_obj) or not is_table(d_obj) then
            ModLog("we have a nil d_obj!")
        else
            self:display(d_obj)
        end
    end

    -- move the x_margin back to where it began here, after doing the internal loops
    self.details_data.x_margin = x_margin
end



function ui_obj:create_details_row_for_field(obj)
    local list_box = self.details_data.list_box
    local x_margin = self.details_data.x_margin
    local default_h = self.details_data.default_h
    
    if not is_uicomponent(list_box) then
        ModLog("display called on field ["..obj:get_key().."], but the list box don't exist yo")
        ModLog(tostring(list_box))
        return false
    end
    
    -- TODO get this working betterer (prettierer) for tables
    local key = obj:get_key()

    local type_text,tooltip_text,value_text = obj:get_display_text()

    local row_uic = UIComponent(list_box:CreateComponent("ui_field_"..self.row_index, "ui/campaign ui/script_dummy"))

    self.rows_to_objs[tostring(self.row_index)] = obj
    self.row_index = self.row_index + 1

    obj:set_uic(row_uic)

    row_uic:SetCanResizeWidth(true) row_uic:SetCanResizeHeight(true)
    row_uic:Resize(math.floor(list_box:Width() * 0.95 - x_margin), default_h)
    --row_uic:SetCanResizeWidth(false) row_uic:SetCanResizeHeight(false)
    row_uic:SetInteractive(true)

    row_uic:SetDockingPoint(0)
    row_uic:SetDockOffset(x_margin, 0)

    row_uic:SetTooltipText(tooltip_text, true)

    local left_text_uic = UIComponent(row_uic:CreateComponent("left_text_uic", "ui/vandy_lib/text/la_gioconda/unaligned"))

    do
        local ow,oh = row_uic:Width() * 0.3, row_uic:Height() * 0.9
        local str = "[[col:white]]"..type_text.."[[/col]]"

        left_text_uic:Resize(ow,oh)

        local w,h = left_text_uic:TextDimensionsForText(str)
        left_text_uic:ResizeTextResizingComponentToInitialSize(w,h)

        left_text_uic:SetStateText(str)

        left_text_uic:Resize(ow,oh)
        w,h = left_text_uic:TextDimensionsForText(str)
        left_text_uic:ResizeTextResizingComponentToInitialSize(ow,oh)
    end

    left_text_uic:SetVisible(true)
    left_text_uic:SetDockingPoint(4)
    left_text_uic:SetDockOffset(5, 0)

    left_text_uic:SetTooltipText(tooltip_text, true)

    -- change the str
    if --[[obj:get_native_type() == "str" and]] obj:get_key() == "text" then
        local right_text_uic = UIComponent(row_uic:CreateComponent("textbox", "ui/common ui/text_box"))
        local ok_button = UIComponent(right_text_uic:CreateComponent("check_name", "ui/templates/square_medium_button"))

        right_text_uic:SetVisible(true)
        right_text_uic:SetDockingPoint(5)
        right_text_uic:SetDockOffset(10, 0)

        right_text_uic:SetTooltipText(obj:get_hex(), true)

        right_text_uic:SetInteractive(true)
        right_text_uic:Resize(row_uic:Width() * 0.5, row_uic:Height() * 0.85)

        right_text_uic:SetStateText(value_text)

        ok_button:SetDockingPoint(6)
        ok_button:SetDockOffset(20, 0)

        ok_button:Resize(right_text_uic:Height() * 0.6, right_text_uic:Height() * 0.6)

        core:add_listener(
            "button_clicked",
            "ComponentLClickUp",
            function(context)
                return UIComponent(context.component) == ok_button
            end,
            function(context)
                local state_text = right_text_uic:GetStateText()
                ModLog("Checking text: "..tostring(state_text))

                -- TODO edit the related field in COPY
                local ok, err = pcall(obj:change_val(state_text))
                if not ok then ModLog(err) end
            end,
            true
        )
        
        -- local right_text_uic = UIComponent(row_uic:CreateComponent("right_text_uic", ""))
    else        
        local right_text_uic = UIComponent(row_uic:CreateComponent("right_text_uic", "ui/vandy_lib/text/la_gioconda/unaligned"))
        right_text_uic:SetCanResizeWidth(true) right_text_uic:SetCanResizeHeight(true)
        do
            local ow,oh = row_uic:Width() * 0.6, row_uic:Height() * 0.9
            local str = "[[col:white]]"..value_text.."[[/col]]"

            right_text_uic:Resize(ow,oh)

            local w,h = right_text_uic:TextDimensionsForText(str)
            right_text_uic:ResizeTextResizingComponentToInitialSize(w,h)

            right_text_uic:SetStateText(str)

            right_text_uic:Resize(ow,oh)
            w,h = right_text_uic:TextDimensionsForText(str)
            right_text_uic:ResizeTextResizingComponentToInitialSize(ow,oh)
        end

        right_text_uic:SetVisible(true)
        right_text_uic:SetDockingPoint(6)
        right_text_uic:SetDockOffset(0, 0)

        right_text_uic:SetTooltipText(obj:get_hex(), true)
    end
end


function ui_obj:display(obj)

    if string.find(tostring(obj), "UIED_") or string.find(tostring(obj), "UI_Container") then
        self:create_details_header_for_obj(obj)
    elseif string.find(tostring(obj), "UI_Field") then
        self:create_details_row_for_field(obj)
    else
        ModLog("not a field or a class!")
    end
end


function ui_obj:create_details_for_loaded_uic()
    local panel = self.panel

    -- TODO this uses the copied uic, so shit is easier to get; is this what I should do?
    local root_uic = ui_editor_lib.copied_uic

    ModLog("bloop 1")

    -- TODO get "headers" working (so you can close/open entire sections, ie. close all states or just one, etc)
    -- TODO figure out the actual look of the text for each thing
    -- TODO figure out tables

    local ok, err = pcall(function()

    local details_screen = find_uicomponent(panel, "details_screen")
    local list_box = find_uicomponent(details_screen, "list_view", "list_clip", "list_box")
    
    ModLog(tostring(list_box))
    ModLog(tostring(is_uicomponent(list_box)))

    -- save the list_box and the x_margin to the ui_obj so it can be easily accessed through all the displays
    self.details_data.list_box = list_box
    self.details_data.x_margin = 0
    self.details_data.default_h = 0

    -- TODO this is a potentially very expensive operation, take a look how it feels with huge files (probably runs like shit (: )
    ModLog("beginning")

    self:display(root_uic)

    ModLog("end")

    -- layout the list_box to make sure everything refreshes propa
    list_box:Layout()
    end) if not ok then ModLog(err) end


-- ModLog("bloop end")
end

-- load the currently deciphered UIC
-- opens the UIC in the testing grounds, and displays all the deciphered details
function ui_obj:load_uic()
    ModLog("load_uic() called")
    local panel = self.panel

    if not is_uicomponent(panel) then
        ModLog("load_uic() called, panel not found?")
        return false
    end

    self:create_loaded_uic_in_testing_ground()

    self:create_details_for_loaded_uic()
end

core:add_listener(
    "header_pressed",
    "ComponentLClickUp",
    function(context)
        local str = context.string
        return string.find(str, "ui_header_")
    end,
    function(context)
        local str = context.string
        local ind = string.gsub(str, "ui_header_", "")

        local obj = ui_obj.rows_to_objs[ind]

        obj:switch_state()
    end,
    true
)

core:add_listener(
    "load_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "ui_editor_load_button"
    end,
    function(context)
        -- TODO make this work for anything else
        local path = "data/ui/templates/button_cycle"

        ui_editor_lib.load_uic_with_path(path)

        --ui_obj:
    end,
    true
)

-- listener for the close button
core:add_listener(
    "ui_editor_close_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "ui_editor_close"
    end,
    function(context)
        ui_obj:close_panel()
    end,
    true
)

core:add_listener(
    "bloopity",
    "UICreated",
    true,
    function()
        ui_obj:init()
    end,
    true
)

return ui_obj