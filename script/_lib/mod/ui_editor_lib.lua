local ui_editor_lib = {
    loaded_uic = nil,
    loaded_uic_path = nil,

    display_data = {} -- this is a table solely used for the creation of the display of UI in-game, it's cleared after every use
}

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
    ModLog("is ui class: "..str)
    --ModLog(tostring(str.find("UIED_")))

    return not not string.find(str, "UIED_")
end

function ui_editor_lib.new_obj(class_name, ...)
    if ui_editor_lib.classes[class_name] then
        return ui_editor_lib.classes[class_name]:new(...)
    end

    ModLog("new_obj called, but no class was found with name ["..class_name.."].")
    
    return false
end

function ui_editor_lib.load_uic_with_path(path)
    if not is_string(path) then
        -- errmsg
        return false
    end

    ModLog("load uic with path: "..path)

    local file = assert(io.open(path, "rb+"))
    if not file then
        ModLog("file not found!")
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

    ModLog("file opened!")

    local ok, err = pcall(function()

    local uic = ui_editor_lib.parser(data)

    ui_editor_lib.loaded_uic = uic
    ui_editor_lib.loaded_uic_path = path

    ui_editor_lib.ui:load_uic()
    end) if not ok then ModLog(err) end
end

core:add_static_object("ui_editor_lib", ui_editor_lib)

ui_editor_lib.init()