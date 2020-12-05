local ui_editor_lib = {
    loaded_uic = nil,
    loaded_uic_path = nil,

    log_file = "a_vandy_lib.txt",
    logging = {},
    is_checking = false,

    display_data = {} -- this is a table solely used for the creation of the display of UI in-game, it's cleared after every use
}

function ui_editor_lib.log(text)
    text = tostring(text) or ""



    ui_editor_lib.logging[#ui_editor_lib.logging+1] = text

    ui_editor_lib.check_logging()
end

function ui_editor_lib.print_log()
    local log_file_path = ui_editor_lib.log_file
    local logging = ui_editor_lib.logging

    local str = table.concat(logging, "\n")

    local log_file = io.open(log_file_path, "a+")
    log_file:write(str)
    log_file:close()

    ui_editor_lib.logging = {}
    ui_editor_lib.is_checking = false

    core:remove_listener("lib_check_logging")
end

-- only print the log if A) logging has 1000 lines or B) it's been 5s since the last call to logging
function ui_editor_lib.check_logging()
    if ui_editor_lib.is_checking then
        if #ui_editor_lib.logging >= 1000 then
            ui_editor_lib.print_log()
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
                ui_editor_lib.print_log()
            end,
            false
        )

        real_timer.register_singleshot("lib_check_logging", 5000)

        ui_editor_lib.is_checking = true
    end
end

function ui_editor_lib.init()
    local path = "script/uic_editor/"

    ui_editor_lib.parser =              require(path.."layout_parser") -- the manager for deciphering the hex and turning it into more accessible objects
    ui_editor_lib.ui =                  require(path.."ui_panel") -- the in-game UI panel manager

    path = path .. "classes/"
    ui_editor_lib.classes = {}
    local classes = ui_editor_lib.classes

    classes.BaseClass =                     require(path.."BaseClass")

    classes.Component =                     require(path.."Component")              -- the class def for the UIComponent type - main boy with names, events, offsets, states, images, children, etc
    classes.Field =                         require(path.."Field")                  -- the class def for UIComponent fields - ie., "offset", "width", "is_interactive" are all fields
    classes.Container =                     require(path.."Container")              -- the class def for containers, which are just slightly involved tables (for lists of states, images, etc)

    classes.ComponentImage =                require(path.."ComponentImage")         -- ComponentImages, simple stuff, just controls image path / width / height /etc
    classes.ComponentState =                require(path.."ComponentState")         -- controls the different states a UIC can be - open, closed, etc., lots of fields within
    classes.ComponentImageMetric =          require(path.."ComponentImageMetric")   -- controls the different fields on an image within a state - visible, tile, etc
    classes.ComponentMouse =                require(path.."ComponentMouse")
    classes.ComponentMouseSth =             require(path.."ComponentMouseSth")
    classes.ComponentProperty =             require(path.."ComponentProperty")
    classes.ComponentFunction =             require(path.."ComponentFunction")
    classes.ComponentFunctionAnimation =    require(path.."ComponentFunctionAnimation")
    classes.ComponentFunctionAnimationTrigger = require(path.."ComponentFunctionAnimationTrigger")
    classes.ComponentEvent =                require(path.."ComponentEvent")
    classes.ComponentEventProperty =        require(path.."ComponentEventProperty")

    classes.ComponentLayoutEngine = require(path.."ComponentLayoutEngine")

    classes.ComponentTemplate = require(path.."ComponentTemplate")
    classes.ComponentTemplateChild = require(path.."ComponentTemplateChild")
end

-- TODO return BaseClass by default?
function ui_editor_lib.get_class(class_name)
    if not is_string(class_name) then
        -- errmsg
        return nil
    end

    local ret = ui_editor_lib.classes[class_name]

    if not ret then
        return nil
    end

    return ret
end

-- TODO edit dis
-- check if a supplied object is an internal UI class
function ui_editor_lib.is_ui_class(obj)
    local str = tostring(obj)
    ui_editor_lib.log("is ui class: "..str)
    --ui_editor_lib.log(tostring(str.find("UIED_")))

    return not not string.find(str, "UIED_")
end

function ui_editor_lib.new_obj(class_name, ...)
    if ui_editor_lib.classes[class_name] then
        return ui_editor_lib.classes[class_name]:new(...)
    end

    ui_editor_lib.log("new_obj called, but no class was found with name ["..class_name.."].")
    
    return false
end

function ui_editor_lib.print_copied_uic()
    ui_editor_lib.log("print copied UIC")
    local ok, err = pcall(function()
    local uic = ui_editor_lib.copied_uic

    -- loop through aaaaaall fields and print their hex

    local hex_str = ""
    local bin_str = ""

    local function iter(d)
        local data = d:get_data()

        for i = 1, #data do
            local datum = data[i]

            if tostring(datum) == "UI_Field" then
                hex_str = hex_str .. datum:get_hex()
            else
                iter(datum)
            end
        end
    end

    iter(uic)

    ui_editor_lib.log(hex_str)

    -- loops through every single hex byte (ie. everything with two hexa values, %x%x), then converts that byte into the relevant "char"
    for byte in hex_str:gmatch("%x%x") do
        -- print(byte)

        local bin_byte = string.char(tonumber(byte, 16))

        -- print(bin_byte)

        bin_str = bin_str .. bin_byte
    end

    ui_editor_lib.log(bin_str)

    local new_file = io.open("data/UI/templates/TEST", "w+b")
    new_file:write(bin_str)
    new_file:close()

    ui_editor_lib.ui:create_loaded_uic_in_testing_ground(true)

end) if not ok then ui_editor_lib.log(err) end
end

function ui_editor_lib.load_uic_with_path(path)
    if not is_string(path) then
        -- errmsg
        return false
    end

    ui_editor_lib.log("load uic with path: "..path)

    local file = assert(io.open(path, "rb+"))
    if not file then
        ui_editor_lib.log("file not found!")
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

    ui_editor_lib.log("file opened!")

    local ok, err = pcall(function()

    local uic = ui_editor_lib.parser(data)

    ui_editor_lib.loaded_uic = uic
    ui_editor_lib.loaded_uic_path = path

    -- make a "copy" of the UIC
    ui_editor_lib.copied_uic = ui_editor_lib.new_obj("Component", uic)

    -- TODO testing the name and the like
    ui_editor_lib.log("Copied ui: "..ui_editor_lib.copied_uic:get_key())

    ui_editor_lib.ui:load_uic()
    end) if not ok then ui_editor_lib.log(err) end
end

core:add_static_object("ui_editor_lib", ui_editor_lib)

ui_editor_lib.init()