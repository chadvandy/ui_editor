local ui_editor_lib = {
    loaded_uic = nil,
    loaded_uic_path = nil,

    loaded_uic_field_count = 0,

    log_file = "a_vandy_lib.txt",
    logging = {},
    is_checking = false,

    testing_file_str = "TEST",
    testing_file_ind = 0,
}

function ui_editor_lib:get_testing_file_string()
    local ret = self.testing_file_str..tostring(self.testing_file_ind)

    -- self.testing_file_ind = self.testing_file_ind+1

    return ret
end

function ui_editor_lib:log(text)
    text = tostring(text) or ""


    self.logging[#self.logging+1] = text

    self:check_logging()
end

function ui_editor_lib:log_init()
    local str = "New log started!\nEnjoy, fuckface!"
    local log_file_path = self.log_file

    local log_file = io.open(log_file_path, "w+")
    log_file:write(str)
    log_file:close()
end

function ui_editor_lib:print_log()
    local log_file_path = self.log_file
    local logging = self.logging

    local str = "\n"..table.concat(logging, "\n")

    local log_file = io.open(log_file_path, "a+")
    log_file:write(str)
    log_file:close()

    ui_editor_lib.logging = {}
    ui_editor_lib.is_checking = false

    core:remove_listener("lib_check_logging")
end

-- only print the log if A) logging has 5000 lines or B) it's been 5s since the last call to logging
function ui_editor_lib:check_logging()
    if self.is_checking then
        if #self.logging >= 5000 then
            self:print_log()
        else
            -- do nothing?
        end
    else
        core:add_listener(
            "lib_check_logging",
            "RealTimeTrigger",
            function(context)
                return context.string == "lib_check_logging"
            end,
            function(context)
                self:print_log()
            end,
            false
        )

        real_timer.register_singleshot("lib_check_logging", 5000)

        self.is_checking = true
    end
end

function ui_editor_lib:init()
    self:log_init()
    local path = "script/uic_editor/"

    self.parser =              self:load_module("layout_parser", path) -- the manager for deciphering the hex and turning it into more accessible objects
    self.ui =                  self:load_module("ui_panel", path) -- the in-game UI panel manager

    path = path .. "classes/"

    self.classes = {}
    local classes = self.classes

    classes.BaseClass =                         self:load_module("BaseClass", path)

    classes.Component =                         self:load_module("Component", path)              -- the class def for the UIComponent type - main boy with names, events, offsets, states, images, children, etc
    classes.Field =                             self:load_module("Field", path)                  -- the class def for UIComponent fields - ie., "offset", "width", "is_interactive" are all fields
    classes.Collection =                        self:load_module("Collection", path)              -- the class def for collections, which are just slightly involved tables (for lists of states, images, etc)

    classes.ComponentImage =                    self:load_module("ComponentImage", path)         -- ComponentImages, simple stuff, just controls image path / width / height /etc
    classes.ComponentState =                    self:load_module("ComponentState", path)         -- controls the different states a UIC can be - open, closed, etc., lots of fields within
    classes.ComponentImageMetric =              self:load_module("ComponentImageMetric", path)   -- controls the different fields on an image within a state - visible, tile, etc
    classes.ComponentMouse =                    self:load_module("ComponentMouse", path)
    classes.ComponentMouseSth =                 self:load_module("ComponentMouseSth", path)
    classes.ComponentProperty =                 self:load_module("ComponentProperty", path)
    classes.ComponentFunction =                 self:load_module("ComponentFunction", path)
    classes.ComponentFunctionAnimation =        self:load_module("ComponentFunctionAnimation", path)
    classes.ComponentFunctionAnimationTrigger = self:load_module("ComponentFunctionAnimationTrigger", path)
    classes.ComponentEvent =                    self:load_module("ComponentEvent", path)
    classes.ComponentEventProperty =            self:load_module("ComponentEventProperty", path)

    classes.ComponentLayoutEngine =             self:load_module("ComponentLayoutEngine", path)

    classes.ComponentTemplate =                 self:load_module("ComponentTemplate", path)
    classes.ComponentTemplateChild =            self:load_module("ComponentTemplateChild", path)
end

function ui_editor_lib:load_module(module_name, path)
    --[[if package.loaded[module_name] then
        return 
    end]]

    local full_file_name = path .. module_name .. ".lua"

    local file, load_error = loadfile(full_file_name)

    if not file then
        self:log("Attempted to load module with name ["..module_name.."], but loadfile had an error: ".. load_error .."")
        --return
    else
        self:log("Loading module with name [" .. module_name .. ".lua]")

        local global_env = core:get_env()
        local attach_env = {}
        setmetatable(attach_env, {__index = global_env})

        -- pass valuable stuff to the modules
        -- attach_env.mct = self
        --attach_env.core = core

        setfenv(file, attach_env)
        local lua_module = file(module_name)
        package.loaded[module_name] = lua_module or true

        self:log("[" .. module_name .. ".lua] loaded successfully!")

        --if module_name == "mod_obj" then
        --    self.mod_obj = lua_module
        --end

        --self[module_name] = lua_module

        return lua_module
    end

    local ok, err = pcall(function() require(module_name) end)

    --if not ok then
    self:log("Tried to load module with name [" .. module_name .. ".lua], failed on runtime. Error below:")
    self:log(err)
        return false
    --end
end

-- TODO return BaseClass by default?
function ui_editor_lib:get_class(class_name)
    if not is_string(class_name) then
        -- errmsg
        return nil
    end

    local ret = self.classes[class_name]

    if not ret then
        return nil
    end

    return ret
end

-- TODO edit dis
-- check if a supplied object is an internal UI class
function ui_editor_lib:is_ui_class(obj)
    local str = tostring(obj)
    self:log("is ui class: "..str)
    --ui_editor_lib:log(tostring(str.find("UIED_")))

    return not not string.find(str, "UIED_")
end

function ui_editor_lib:new_obj(class_name, ...)
    if self.classes[class_name] then
        return self.classes[class_name]:new(...)
    end

    self:log("new_obj called, but no class was found with name ["..class_name.."].")
    
    return false
end

function ui_editor_lib:print_copied_uic()
    self:log("print copied UIC")
    local ok, err = pcall(function()
    local uic = self.copied_uic

    -- loop through aaaaaall fields and print their hex

    local hex_str = ""
    local bin_str = ""

    local function iter(d)
        local data = d:get_data()

        for i = 1, #data do
            local datum = data[i]

            if tostring(datum) == "UI_Field" then
                hex_str = hex_str .. datum:get_hex()
            elseif tostring(datum) == "UI_Collection" then
                -- add the length hex and then iterate through all fields (read: objects)
                hex_str = hex_str .. datum:get_hex()
                iter(datum)
            else
                iter(datum)
            end
        end
    end

    iter(uic)

    -- ui_editor_lib:log(hex_str)

    -- loops through every single hex byte (ie. everything with two hexa values, %x%x), then converts that byte into the relevant "char"
    for byte in hex_str:gmatch("%x%x") do
        -- print(byte)

        local bin_byte = string.char(tonumber(byte, 16))

        -- print(bin_byte)

        bin_str = bin_str .. bin_byte
    end

    -- ui_editor_lib:log(bin_str)

    self.testing_file_ind=self.testing_file_ind+1
    local new_file = io.open("data/UI/ui_editor/"..self:get_testing_file_string(), "w+b")
    new_file:write(bin_str)
    new_file:close()

    -- ui_editor_lib.ui:create_loaded_uic_in_testing_ground(true)

end) if not ok then self:log(err) end
end

function ui_editor_lib:load_uic_with_path(path)
    if not is_string(path) then
        -- errmsg
        return false
    end

    self.loaded_uic = nil
    self.loaded_uic_path = ""
    self.copied_uic = nil

    self:log("load uic with path: "..path)

    local file = assert(io.open(path, "rb+"))
    if not file then
        self:log("file not found!")
        return false
    end

    local data = {}
    --local nums = {}
    --local location = 1

    local block_num = 10
    while true do
        local bytes = file:read(block_num)
        if not bytes then break end

        for b in string.gfind(bytes, ".") do
            local byte = string.format("%02X", string.byte(b))

            --data = data .. " " .. byte
            data[#data+1] = byte
        end
    end

    file:close()

    self:log("file opened!")

    local ok, err = pcall(function()

    local uic,field_count = self.parser(data)

    self.loaded_uic = uic
    self.loaded_uic_path = path

    -- TODO decide dis number

    -- set this file to large if it has a lot of fields; 
    local b = false
    if field_count >= 5000 then
        b = true
    end

    -- make a "copy" of the UIC
    self.copied_uic = self:new_obj("Component", uic)


    self.ui:load_uic()
    end) if not ok then self:log(err) end
end

core:add_static_object("ui_editor_lib", ui_editor_lib)

ui_editor_lib:init()