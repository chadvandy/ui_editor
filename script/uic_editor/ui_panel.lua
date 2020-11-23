-- the actual physical for the UI, within the game.
-- weird concept, right?

local ui_editor_lib = core:get_static_object("ui_editor_lib")

local ui_obj = {
    new_button = nil,
    opened = false,

    panel = nil,
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
    local w,h = ow*0.75,oh*0.75-20

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
        local nh = h

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
        list_view:Resize(nw-20, nh-details_title:Height()-40)
        list_view:SetDockingPoint(2)
        list_view:SetDockOffset(10, details_title:Height() + 5)
    
        local x,y = list_view:Position()
        local w,h = list_view:Bounds()
    
        local lclip = find_uicomponent(list_view, "list_clip")
        lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
        lclip:SetDockingPoint(0)
        lclip:SetDockOffset(0, 0)
        lclip:Resize(w,h)
    
        local lbox = find_uicomponent(lclip, "list_box")
        lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
        lbox:SetDockingPoint(0)
        lbox:SetDockOffset(0, 0)
        lbox:Resize(w,h)
    end

    do
        local buttons_holder = UIComponent(panel:CreateComponent("buttons_holder", "ui/vandy_lib/custom_image_tiled"))
        buttons_holder:SetState("custom_state_2")

        local nw = ow-20
        local nh = oh-h-150

        buttons_holder:SetCanResizeWidth(true) buttons_holder:SetCanResizeHeight(true)
        buttons_holder:Resize(nw,nh)
        buttons_holder:SetCanResizeWidth(false) buttons_holder:SetCanResizeHeight(false)

        buttons_holder:SetImagePath("ui/skins/default/parchment_texture.png", 1)
        buttons_holder:SetVisible(true)
    
        buttons_holder:SetDockingPoint(8)
        buttons_holder:SetDockOffset(0, -85)

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

function ui_obj:create_loaded_uic_in_testing_ground()
    local path = ui_editor_lib.loaded_uic_path

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

function ui_obj:create_details_for_loaded_uic()
    local panel = self.panel
    local root_uic = ui_editor_lib.loaded_uic

    ModLog("bloop 1")

    -- TODO get "headers" working (so you can close/open entire sections, ie. close all states or just one, etc)
    -- TODO figure out the actual look of the text for each thing
    -- TODO figure out tables

    local ok, err = pcall(function()

    local details_screen = find_uicomponent(panel, "details_screen")
    local list_box = find_uicomponent(details_screen, "list_view", "list_clip", "list_box")

    -- save the list_box and the x_margin to the ui_editor_lib so it can be easily accessed through all the displays
    ui_editor_lib.display_data.list_box = list_box
    ui_editor_lib.display_data.x_margin = 0

    -- TODO this is a potentially very expensive operation, take a look how it feels with huge files (probably runs like shit (: )
    -- call the :display() method on root_uic, which creates the header for that component, runs through all its fields, and calls every individual field's "display" method as well!
    ModLog("beginning")

    local ok, err = pcall(function()
    root_uic:display()
    end) if not ok then ModLog(err) end

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