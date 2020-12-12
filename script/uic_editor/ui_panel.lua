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

    key_to_uics = {},
    value_to_uics = {},
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
    else
        ui_editor_lib:log("Invalid type passed to ui:delete_component()")
        return
    end

    dummy:DestroyChildren()
end


function ui_obj:init()
    local new_button
    if __game_mode == __lib_type_campaign or __game_mode == __lib_type_battle then
        ui_editor_lib:log("bloop")
        local button_group = find_uicomponent(core:get_ui_root(), "menu_bar", "buttongroup")
        new_button = UIComponent(button_group:CreateComponent("button_ui_editor", "ui/templates/round_small_button"))

        new_button:SetTooltipText("UI Editor", true)

        ui_editor_lib:log("bloop 2")
        --new_button:SetImagePath()

        new_button:PropagatePriority(button_group:Priority())

        button_group:Layout()

        ui_editor_lib:log("bloop 5")
    elseif __game_mode == __lib_type_frontend then
        local button_group = find_uicomponent(core:get_ui_root(), "sp_frame", "menu_bar")

        new_button = UIComponent(button_group:CreateComponent("button_ui_editor", "ui/templates/round_small_button"))
        new_button:SetTooltipText("UI Editor", true)

        button_group:Layout()
    end

    if not is_uicomponent(new_button) then ui_editor_lib:log("NO NEW BUTTON") return end

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

    ui_editor_lib:log("test 1")

    self.panel = panel

    --panel:PropagatePriority(5000)
    --panel:LockPriority()

    panel:SetCanResizeWidth(true) panel:SetCanResizeHeight(true)

    
    ui_editor_lib:log("test 2")

    local sw,sh = core:get_screen_resolution()
    panel:Resize(sw*0.95, sh*0.95)

    panel:SetCanResizeWidth(false) panel:SetCanResizeHeight(false)

    ui_editor_lib:log("test 3")

    -- edit the name
    local title_plaque = UIComponent(panel:Find("title_plaque"))
    local title = UIComponent(title_plaque:Find("title"))
    title:SetStateText("UI Editor")

    ui_editor_lib:log("test 4")

    -- hide stuff from the gfx window
    local comps = {
        UIComponent(panel:Find("checkbox_windowed")),
        UIComponent(panel:Find("ok_cancel_buttongroup")),
        UIComponent(panel:Find("button_advanced_options")),
        UIComponent(panel:Find("button_recommended")),
        UIComponent(panel:Find("dropdown_resolution")),
        UIComponent(panel:Find("dropdown_quality")),
    }

    ui_editor_lib:log("test 5")

    self:delete_component(comps)

    -- create the close button!   
    local close_button_uic = core:get_or_create_component("ui_editor_close", "ui/templates/round_medium_button", panel)
    local img_path = effect.get_skinned_image_path("icon_cross.png")
    close_button_uic:SetImagePath(img_path)
    close_button_uic:SetTooltipText("Close panel", true)

    ui_editor_lib:log("test 6")

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

        local filter_holder = UIComponent(details_screen:CreateComponent("filter_holder", "ui/campaign ui/script_dummy"))
        filter_holder:SetCanResizeWidth(true)
        filter_holder:SetCanResizeHeight(true)

        filter_holder:SetDockingPoint(2)
        filter_holder:SetDockOffset(0, details_title:Height() + 5)

        filter_holder:Resize(details_title:Width(), details_title:Height() * 2.5)

        filter_holder:SetCanResizeWidth(false)
        filter_holder:SetCanResizeHeight(false)

        do
            local key_filter_text = UIComponent(filter_holder:CreateComponent("key_filter_text", "ui/vandy_lib/text/la_gioconda/center"))
            key_filter_text:SetVisible(true)

            key_filter_text:SetDockingPoint(4)
            key_filter_text:SetDockOffset(10, -30)
            key_filter_text:Resize(filter_holder:Width() * 0.3, key_filter_text:Height())

            do
                local mw,mh = key_filter_text:TextDimensionsForText("[[col:fe_white]]Filter by Key[[/col]]")
            
                key_filter_text:ResizeTextResizingComponentToInitialSize(mw, mh)
                key_filter_text:SetStateText("[[col:fe_white]]Filter by Key[[/col]]")
            
                key_filter_text:SetTooltipText("Filter by Key, wtf else do you want me to say", true)
                key_filter_text:SetInteractive(false)
            end
            
            local value_filter_text = UIComponent(filter_holder:CreateComponent("value_filter_text", "ui/vandy_lib/text/la_gioconda/center"))
            value_filter_text:SetVisible(true)

            value_filter_text:SetDockingPoint(4)
            value_filter_text:SetDockOffset(10, 30)
            value_filter_text:Resize(filter_holder:Width() * 0.3, value_filter_text:Height())

            do
                local mw,mh = value_filter_text:TextDimensionsForText("[[col:fe_white]]Filter by Value[[/col]]")
            
                value_filter_text:ResizeTextResizingComponentToInitialSize(mw, mh)
                value_filter_text:SetStateText("[[col:fe_white]]Filter by Value[[/col]]")
            
                value_filter_text:SetTooltipText("Filter by Value, do it, I dare you", true)
                value_filter_text:SetInteractive(false)
            end

            local key_filter = UIComponent(filter_holder:CreateComponent("key_filter_input", "ui/common ui/text_box"))

            key_filter:SetVisible(true)
            key_filter:SetDockingPoint(5)
            key_filter:SetDockOffset(20, -30)
        
            key_filter:SetTooltipText("The filter for the key, wtf", true)
        
            key_filter:SetInteractive(true)
            
            key_filter:SetCanResizeWidth(true)
            key_filter:Resize(filter_holder:Width() * 0.5, key_filter:Height())
        
            key_filter:SetStateText("")
            
            local value_filter = UIComponent(filter_holder:CreateComponent("value_filter_input", "ui/common ui/text_box"))

            value_filter:SetVisible(true)
            value_filter:SetDockingPoint(5)
            value_filter:SetDockOffset(20, 30)
        
            value_filter:SetTooltipText("Hiiiiiii filter the value", true)
        
            value_filter:SetInteractive(true)
            
            value_filter:SetCanResizeWidth(true)
            value_filter:Resize(filter_holder:Width() * 0.5, key_filter:Height())
        
            value_filter:SetStateText("")

            local do_filter = UIComponent(filter_holder:CreateComponent("do_filter", "ui/templates/square_medium_button"))
            do_filter:SetTooltipText("Do the filter", true)
            do_filter:SetVisible(true)

            do_filter:SetDockingPoint(6)
            do_filter:SetDockOffset(-20, 0)
        end

        local list_view = UIComponent(details_screen:CreateComponent("list_view", "ui/vandy_lib/vlist"))
        list_view:SetCanResizeWidth(true) list_view:SetCanResizeHeight(true)
        list_view:Resize(nw-20, nh-details_title:Height()-filter_holder:Height()-50)
        list_view:SetDockingPoint(2)
        list_view:SetDockOffset(10, details_title:Height() + filter_holder:Height() + 5)
    
        local x,y = list_view:Position()
        local w,h = list_view:Bounds()
        ui_editor_lib:log("list view bounds: ("..tostring(w)..", "..tostring(h)..")")
    
        local lclip = UIComponent(list_view:Find("list_clip"))
        lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
        lclip:SetDockingPoint(0)
        lclip:SetDockOffset(0, 0)
        lclip:Resize(w,h)

        ui_editor_lib:log("list clip bounds: ("..tostring(lclip:Width()..", "..tostring(lclip:Height())..")"))
    
        local lbox = UIComponent(lclip:Find("list_box"))
        lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
        lbox:SetDockingPoint(0)
        lbox:SetDockOffset(0, 0)
        lbox:Resize(w-30,h)

        ui_editor_lib:log("list box bounds: ("..tostring(lbox:Width()..", "..tostring(lbox:Height())..")"))
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

-- TODO clear filter function
-- TODO clear all canvases function
-- TODO better row uic names and getting and shit, esp. with canvases

-- TODO use canvases off large-file mode; large file should just start everything deleted, while not-large has everything created

function ui_obj:do_filter()
    ModLog("Doing the filter")
    local panel = self.panel
    local filter_holder = find_uicomponent(panel, "details_screen", "filter_holder")

    if not is_uicomponent(filter_holder) then
        ModLog("Wtf no filter holder.")
        return false
    end

    local ok, err = pcall(function()

    local key_filter_input = UIComponent(filter_holder:Find("key_filter_input"))
    local value_filter_input = UIComponent(filter_holder:Find("value_filter_input"))

    local key_filter = key_filter_input:GetStateText()
    local value_filter = value_filter_input:GetStateText()

    if key_filter == "" then key_filter = nil end
    if value_filter == "" then value_filter = nil end

    -- if ui_editor_lib.is_large_file then

    -- TODO clear all canvases
    local root = ui_editor_lib.copied_uic

    local function loopy(stuff, parent_uic)
        local str = tostring(stuff)
        if str:find("UI_Field") then
            local key = stuff:get_key()
            local value = stuff:get_value_text()

            local create = false

            if key_filter and key:find(key_filter) then
                create = true
            end

            if value_filter and value:find(value_filter) then
                create = true
            end

            if create then
                self:create_details_row_for_field(stuff, parent_uic)
            end

            return create
        else
            local list_box = self.details_data.list_box
            local uic = stuff:get_uic()
            local id = uic:Id()

            local canvas = UIComponent(list_box:Find(id.."_canvas"))

            local data = stuff:get_data()
            local any_created = false
            for i = 1, #data do
                local datum = data[i]

                local created = loopy(datum, uic)
                if created then any_created = true end
            end

            if any_created then
                if is_uicomponent(canvas) then
                    canvas:SetVisible(true)
                end
            end
        end
    end

    loopy(root)


    -- else

    --     if key_filter ~= "" then
    --         for key,uics in pairs(self.key_to_uics) do
    --             if string.find(key, key_filter) then
    --                 -- for i = 1, #uics do
    --                 --     local uic = uics[i]
    --                 --     uic:SetVisible(true)
    --                 -- end
    --             else
    --                 for i = 1, #uics do
    --                     local uic = uics[i]
    --                     uic:SetVisible(false)
    --                 end
    --             end
    --         end
    --     end

    --     if value_filter ~= "" then
    --         for value,uics in pairs(self.value_to_uics) do
    --             if string.find(value, value_filter) then
    --                 for i = 1, #uics do
    --                     local uic = uics[i]
    --                     uic:SetVisible(true)
    --                 end
    --             else
    --                 for i = 1, #uics do
    --                     local uic = uics[i]
    --                     uic:SetVisible(false)
    --                 end
    --             end
    --         end
    --     end

    -- end

    end) if not ok then ui_editor_lib:log(err) end

end

-- create the various buttons of the bottom bar
function ui_obj:create_buttons_holder()
    -- to start, just a "load" button that automatically loads "ui/templates/bullet_point"

    local panel = self.panel
    local buttons_holder = UIComponent(panel:Find("buttons_holder"))
    if not is_uicomponent(buttons_holder) then
        -- errmsg
        return false
    end

    local load_button = core:get_or_create_component("ui_editor_load_button", "ui/templates/square_medium_button", buttons_holder)
    load_button:SetVisible(true)
    load_button:SetDockingPoint(5)
    load_button:SetDockOffset(0,0)
    load_button:SetInteractive(true)
    load_button:SetTooltipText("Load UIC Details", true)

    local save_button = core:get_or_create_component("ui_editor_save_button", "ui/templates/square_medium_button", buttons_holder)
    save_button:SetVisible(true)
    save_button:SetDockingPoint(5)
    save_button:SetDockOffset(65,0)
    save_button:SetInteractive(true)
    save_button:SetTooltipText("Save UIC as Copy", true)

    local test_button = core:get_or_create_component("ui_editor_test_button", "ui/templates/square_medium_button", buttons_holder)
    test_button:SetVisible(true)
    test_button:SetDockingPoint(5)
    test_button:SetDockOffset(-100, 0)
    test_button:SetInteractive(true)
    test_button:SetTooltipText("Display UIC", true)

    local full_screen_button = core:get_or_create_component("ui_editor_full_screen_button", "ui/templates/square_medium_button", buttons_holder)
    full_screen_button:SetVisible(true)
    full_screen_button:SetDockingPoint(5)
    full_screen_button:SetDockOffset(-100, -50)
    full_screen_button:SetInteractive(true)
    full_screen_button:SetTooltipText("Display UIC as Fullscreen", true)


    local path_name_input = core:get_or_create_component("path_name_input","ui/common ui/text_box", buttons_holder)

    path_name_input:SetVisible(true)
    path_name_input:SetDockingPoint(5)
    path_name_input:SetDockOffset(0, 50)

    path_name_input:SetTooltipText("Path to loaded UIC (from where Warhammer2.exe is located)", true)

    path_name_input:SetInteractive(true)
    
    path_name_input:SetCanResizeWidth(true)
    path_name_input:Resize(test_button:Width() * 8, path_name_input:Height())
    --path_name_input:SetCanResizeWidth(false)

    path_name_input:SetStateText("")
end

function ui_obj:get_path()
    local panel = self.panel
    local path_name_input = find_uicomponent(panel, "buttons_holder", "path_name_input")

    if not is_uicomponent(path_name_input) then
        -- errmsg
        return false
    end

    local path = path_name_input:GetStateText()

    -- TODO verify that the path is valid - there's a file there and what not


    return path
end

function ui_obj:create_loaded_uic_in_testing_ground(is_copied, is_fullscreen)
    local path = ui_editor_lib.loaded_uic_path

    if is_copied then
        path = "ui/ui_editor/"..ui_editor_lib:get_testing_file_string()
    end

    local panel = self.panel
    if not panel or not is_uicomponent(panel) or not path then
        ui_editor_lib:log("create loaded uic in testing ground failed")
        return false
    end

    local testing_grounds = UIComponent(panel:Find("testing_grounds"))
    testing_grounds:DestroyChildren()

    if is_fullscreen then
        -- local cw,ch = core:get_screen_resolution()
        -- testing_grounds:Resize(cw, ch)

        -- TODO add in a un-fullscreen button or functionality somehow
        local test_uic = UIComponent(core:get_ui_root():CreateComponent("testing_component", path))

        if not is_uicomponent(test_uic) then
            ui_editor_lib:log("test uic failed!")
            return false
        end

        test_uic:SetVisible(true)

        local fullscreen_disable_button = UIComponent(core:get_ui_root():CreateComponent("fullscreen_disable", "ui/templates/square_medium_button"))
        fullscreen_disable_button:SetDockingPoint(2)
        fullscreen_disable_button:SetDockOffset(0, 40)

        panel:SetVisible(false)

        core:add_listener(
            "fullscreen_disable",
            "ComponentLClickUp",
            function(context)
                return context.string == "fullscreen_disable"
            end,
            function(context)
                local uic = UIComponent(context.component)

                self:delete_component(uic)
                self:delete_component(test_uic)

                if is_uicomponent(panel) then
                    panel:SetVisible(true)
                end
            end,
            false
        )

        return
    end

    local test_uic = UIComponent(testing_grounds:CreateComponent("testing_component", path))
    if not is_uicomponent(test_uic) then
        ui_editor_lib:log("test uic failed!")
        return false
    end

    test_uic:SetVisible(true)
    test_uic:SetDockingPoint(5)
    test_uic:SetDockOffset(0, 0)

    local w,h = test_uic:Bounds()

    local ow,oh = testing_grounds:Dimensions()

    local wf,hf = 0,0

    if w > ow then
        wf = w/ow
    end

    if h > oh then
        hf = h/oh
    end

    local f

    if wf >= hf then f = wf else f = hf end

    if f == 0 then
        return
    end

    test_uic:SetCanResizeWidth(true)
    test_uic:SetCanResizeHeight(true)

    test_uic:Resize(w/f,h/f)

    test_uic:SetCanResizeWidth(false)
    test_uic:SetCanResizeHeight(false)
    
end

function ui_obj:create_details_header_for_obj(obj)
    local list_box = self.details_data.list_box
    local x_margin = self.details_data.x_margin
    local default_h = self.details_data.default_h

    if not is_uicomponent(list_box) then
        ui_editor_lib:log("display called on obj ["..obj:get_key().."], but the list box don't exist yo")
        ui_editor_lib:log(tostring(list_box))
        return false
    end

    -- create the header_uic for the holder of the UIC
    local i = self.row_index
    local header_uic = UIComponent(list_box:CreateComponent("ui_header_"..i, "ui/vandy_lib/expandable_row_header"))

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

    local dy_title = UIComponent(header_uic:Find("dy_title"))
    dy_title:SetStateText(obj:get_type() .. ": " .. obj:get_key())

    local child_count = UIComponent(header_uic:Find("child_count"))
    if obj:get_type() == "UI_Collection" then
        local str = tostring(#obj.data)
        if not str or str == "" then
            child_count:SetVisible(false)
        else
            child_count:SetStateText(tostring(#obj.data))
        end
    else
        child_count:SetVisible(false)
    end

    if obj:get_type() == "UIED_Component" and not obj:is_root() then
        local delete_button = UIComponent(header_uic:CreateComponent("delete", "ui/templates/square_medium_button"))

        delete_button:SetDockingPoint(6)
        delete_button:SetDockOffset(-5, 0)

        delete_button:SetCanResizeWidth(true)
        delete_button:SetCanResizeHeight(true)
        delete_button:Resize(header_uic:Height() * 0.8, header_uic:Height() * 0.8)
        delete_button:SetCanResizeHeight(false)
        delete_button:SetCanResizeWidth(false)

        core:add_listener(
            "delete_component",
            "ComponentLClickUp",
            function(context)
                return UIComponent(context.component) == delete_button
            end,
            function(context)
                ui_editor_lib:log("Object ["..obj:get_key().."] with type ["..obj:get_type().."] being deleted!")
                local parent = obj:get_parent()

                ui_editor_lib:log("Parent obj key is ["..parent:get_key().."], of type ["..parent:get_type().."].")

                -- remove the data from the parent!
                parent:remove_data(obj)

                -- delete the canvas and the header UIC
                local header_uic_id = header_uic:Id()
                self:delete_component(header_uic)
                self:delete_component(UIComponent(list_box:Find(header_uic_id.."_canvas")))
            end,
            false
        )
    end

    -- move the x_margin over a bit
    self.details_data.x_margin = x_margin + 10

    -- create the Canvas for large files only
    -- if ui_editor_lib.is_large_file then


    -- set the state of the header to closed
    -- if obj is a UIC, set it to closed
    if obj:get_type() == "UIED_Component" then
        header_uic:SetState("active")
        header_uic:SetVisible(true)
        obj.state = "closed"
    else 
        -- set it to invisible
        header_uic:SetState("active")
        header_uic:SetVisible(false)
        obj.state = "invisible"
    end

    local list_view = UIComponent(list_box:CreateComponent("ui_header_"..i.."_canvas", "ui/vandy_lib/vlist"))

    list_view:SetCanResizeWidth(true) list_view:SetCanResizeHeight(true)
    list_view:Resize(list_box:Width(), 5)
    list_view:SetDockingPoint(0)
    list_view:SetDockOffset(0, 0)

    local x,y = list_view:Position()
    local w,h = list_view:Dimensions()
    -- ui_editor_lib:log("list view bounds: ("..tostring(w)..", "..tostring(h)..")")

    local lclip = UIComponent(list_view:Find("list_clip"))
    lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
    lclip:SetDockingPoint(2)
    lclip:SetDockOffset(0, 0)
    lclip:Resize(w,h)

    -- ui_editor_lib:log("list clip bounds: ("..tostring(lclip:Width()..", "..tostring(lclip:Height())..")"))

    local lbox = UIComponent(lclip:Find("list_box"))
    lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
    lbox:SetDockingPoint(2)
    lbox:SetDockOffset(0, 0)
    lbox:Resize(w,h)

    list_view:SetVisible(false)

    -- hide da scroll bar
    local vslider = UIComponent(list_view:Find("vslider"))
    vslider:SetVisible(false) 
    vslider:PropagateVisibility(false)

    -- end

    -- loop through every field in "data" and call its own display() method
    local data = obj:get_data()

    -- ui_editor_lib:log("hand-crafting details header for obj ["..obj:get_key().."] with type ["..obj:get_type().."].\nNumber of data is: "..tostring(#data))

    for i = 1, #data do
        -- ui_editor_lib:log("in ["..tostring(i).."] within obj ["..obj:get_key().."].")
        local d = data[i]
        -- local d_key = d.key -- needed?
        local d_obj

        -- ui_editor_lib:log("Testing obj: "..tostring(d))
        -- ui_editor_lib:log("")

        -- if obj:get_key() == "dy_txt" then
        --     -- ui_editor_lib:log("VANDY LOOK HERE")
        --     -- ui_editor_lib:log(i.."'s key: " .. d:get_key())
        --     if tostring(d) == "UI_Field" then
        --         -- ui_editor_lib:log(i.."'s val: " .. tostring(d:get_value()))
        --     end
        -- end

        if string.find(tostring(d), "UIED_") or string.find(tostring(d), "UI_Collection") or string.find(tostring(d), "UI_Field") then
            -- ui_editor_lib:log("inner child is a class")
            d_obj = d
        -- elseif type(d) == "table" then
        --     ui_editor_lib:log("inner child is a table")
        --     if not is_nil(d.value) then
        --         d_obj = d.value
        --     else
        --         ui_editor_lib:log("inner child table doesn't ")
        --     end
        else
            -- TODO errmsg
            ui_editor_lib:log("inner child is not a field or a class, Y")
            -- TODO resolve what to do if it's just a raw value?
        end

        if is_nil(d_obj) or not is_table(d_obj) then
            ui_editor_lib:log("we have a nil d_obj!")
        else
            self:display(d_obj)
        end
    end

    -- move the x_margin back to where it began here, after doing the internal loops
    self.details_data.x_margin = x_margin
end



function ui_obj:create_details_row_for_field(obj, parent_uic)
    local list_box = self.details_data.list_box
    local x_margin = self.details_data.x_margin
    local default_h = self.details_data.default_h
    
    if not is_uicomponent(list_box) then
        ui_editor_lib:log("display called on field ["..obj:get_key().."], but the list box don't exist yo")
        ui_editor_lib:log(tostring(list_box))
        return false
    end
    
    -- TODO get this working betterer (prettierer) for tables

    local key = obj:get_key()

    local type_text,tooltip_text,value_text = obj:get_display_text()

    local row_uic = nil
    local canvas = nil
    if is_uicomponent(parent_uic) then
        local id = parent_uic:Id()
        canvas = UIComponent(list_box:Find(id.."_canvas"))

        if is_uicomponent(canvas) then
            ui_editor_lib:log("Canvas found!")

            local lbox = find_uicomponent(canvas, "list_clip", "list_box")
            
            row_uic = UIComponent(lbox:CreateComponent("ui_field_"..self.row_index, "ui/campaign ui/script_dummy"))

            -- TODO figure this out?
            -- resize canvas automatically, use Layout(), what?
        else
            ui_editor_lib:log("Canvas not found!!!! "..id)
            return false
        end
    else
        row_uic = UIComponent(list_box:CreateComponent("ui_field_"..self.row_index, "ui/campaign ui/script_dummy"))
    end    


    self.rows_to_objs[tostring(self.row_index)] = obj
    self.row_index = self.row_index + 1

    obj:set_uic(row_uic)

    row_uic:SetCanResizeWidth(true) row_uic:SetCanResizeHeight(true)
    row_uic:Resize(math.floor(list_box:Width() * 0.95 - x_margin), default_h)
    row_uic:SetCanResizeWidth(false) row_uic:SetCanResizeHeight(false)
    row_uic:SetInteractive(true)

    row_uic:SetDockingPoint(0)

    row_uic:SetDockOffset(x_margin, 0)

    row_uic:SetTooltipText(tooltip_text, true)

    if self.key_to_uics[key] then
        self.key_to_uics[key][#self.key_to_uics[key]+1] = row_uic
    else
        self.key_to_uics[key] = {row_uic}
    end

    if self.value_to_uics[value_text] then
        self.value_to_uics[value_text][#self.value_to_uics[value_text]+1] = row_uic
    else
        self.value_to_uics[value_text] = {row_uic}
    end

    local left_text_uic = UIComponent(row_uic:CreateComponent("key", "ui/vandy_lib/text/la_gioconda/unaligned"))

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
    if obj:is_editable() and obj:get_native_type() == "str" or obj:get_native_type() == "utf8"--[[and obj:get_key() == "text"]] then
        local right_text_uic = UIComponent(row_uic:CreateComponent("value", "ui/common ui/text_box"))
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
                ui_editor_lib:log("Checking text: "..tostring(state_text))

                local ok, err = pcall(obj:change_val(state_text))
                if not ok then ui_editor_lib:log(err) end
            end,
            true
        )
        
        -- local right_text_uic = UIComponent(row_uic:CreateComponent("right_text_uic", ""))
    -- TODO pick one, fucker (bool or boolean, that is)
    elseif obj:is_editable() and obj:get_native_type() == "bool" or obj:get_native_type() == "boolean" then
        local right_text_uic = UIComponent(row_uic:CreateComponent("value", "ui/templates/checkbox_toggle"))

        right_text_uic:SetVisible(true)
        right_text_uic:SetDockingPoint(5)
        right_text_uic:SetDockOffset(30, 0)

        right_text_uic:SetTooltipText(obj:get_hex(), true)

        right_text_uic:SetInteractive(true)

        local val = obj:get_value()

        if val == true then
            right_text_uic:SetState("selected")
        else 
            right_text_uic:SetState("active")
        end
        -- right_text_uic:Resize(row_uic:Width() * 0.5, row_uic:Height() * 0.85)

        -- right_text_uic:SetStateText(value_text)

        core:add_listener(
            "checkbox_clicked",
            "ComponentLClickUp",
            function(context)
                return UIComponent(context.component) == right_text_uic
            end,
            function(context)
                -- local state_text = right_text_uic:GetStateText()
                local my_state = obj:get_value()

                local new_state = not my_state
                -- local new_state = UIComponent(context.component):CurrentState()
                -- local b = false
                -- ui_editor_lib:log("My new state is: "..new_state)
                -- if new_state == "selected" then
                --     b = true
                -- end
                
                -- ui_editor_lib:log("Checking text: "..tostring(state_text))

                local ok, err = pcall(obj:change_val(new_state))
                if not ok then ui_editor_lib:log(err) end
            end,
            true
        )
    else        
        local right_text_uic = UIComponent(row_uic:CreateComponent("value", "ui/vandy_lib/text/la_gioconda/unaligned"))
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

    if canvas then
        local cw,ch = canvas:Width(), canvas:Height()
        local _,rh = row_uic:Width(), row_uic:Height()

        canvas:SetDockingPoint(0)
        canvas:SetDockOffset(0, 0)
        canvas:Resize(cw, ch+rh+5)

        canvas:Layout()
    end
end


function ui_obj:display(obj)
    -- if file too big, only create headers
    -- if ui_editor_lib.is_large_file then
    
    if string.find(tostring(obj), "UIED_") or string.find(tostring(obj), "UI_Collection") then
        self:create_details_header_for_obj(obj)
    end

    -- else
    --     if string.find(tostring(obj), "UIED_") or string.find(tostring(obj), "UI_Collection") then
    --         self:create_details_header_for_obj(obj)
    --     elseif string.find(tostring(obj), "UI_Field") then
    --         self:create_details_row_for_field(obj)
    --     else
    --         ui_editor_lib:log("not a field or a class!")
    --     end
    -- end
end


function ui_obj:create_details_for_loaded_uic()
    local panel = self.panel

    local root_uic = ui_editor_lib.copied_uic

    ui_editor_lib:log("bloop 1")

    -- TODO figure out the actual look of the text for each thing
    -- TODO figure out tables

    local ok, err = pcall(function()

    local details_screen = UIComponent(panel:Find("details_screen"))
    local list_box = find_uicomponent(details_screen, "list_view", "list_clip", "list_box")

    ui_editor_lib:log("The total amount of fields in this file is: "..tostring(ui_editor_lib.parser.field_count))
    
    ui_editor_lib:log(tostring(list_box))
    ui_editor_lib:log(tostring(is_uicomponent(list_box)))

    -- destroy chil'un of list_box (clear previous shit)
    list_box:DestroyChildren()

    -- save the list_box and the x_margin to the ui_obj so it can be easily accessed through all the displays
    self.details_data.list_box = list_box
    self.details_data.x_margin = 0
    self.details_data.default_h = 0

    -- TODO this is a potentially very expensive operation, take a look how it feels with huge files (probably runs like shit (: )
    ui_editor_lib:log("beginning")

    self:display(root_uic)

    ui_editor_lib:log("end")

    -- layout the list_box to make sure everything refreshes propa
    list_box:Layout()
    end) if not ok then ui_editor_lib:log(err) end
end

-- load the currently deciphered UIC
-- opens the UIC in the testing grounds, and displays all the deciphered details
function ui_obj:load_uic()
    ui_editor_lib:log("load_uic() called")
    local panel = self.panel

    if not is_uicomponent(panel) then
        ui_editor_lib:log("load_uic() called, panel not found?")
        return false
    end

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

        local list_box = ui_obj.details_data.list_box
        if is_uicomponent(list_box) then
            list_box:Layout()
        end
    end,
    true
)


core:add_listener(
    "save_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "ui_editor_save_button"
    end,
    function(context)
        ui_editor_lib:print_copied_uic()
    end,
    true
)

core:add_listener(
    "test_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "ui_editor_test_button"
    end,
    function(context)
        ui_obj:create_loaded_uic_in_testing_ground(true)
    end,
    true
)

core:add_listener(
    "full_screen_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "ui_editor_full_screen_button"
    end,
    function(context)
        ui_obj:create_loaded_uic_in_testing_ground(true, true)
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
        -- TODO make sure get_path is valid 
        local path = ui_obj:get_path()

        ui_editor_lib:load_uic_with_path(path)

        --ui_obj:
    end,
    true
)

core:add_listener(
    "do_the_filter",
    "ComponentLClickUp",
    function(context)
        return context.string == "do_filter"
    end,
    function(context)
        ModLog("DO FILTER")
        ui_obj:do_filter()
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
        ui_editor_lib:log("UI Created")
        local ok, err = pcall(function()
        ui_obj:init()
        end) if not ok then ui_editor_lib:log(err) end
    end,
    true
)

return ui_obj