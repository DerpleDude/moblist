--[[
    A list of mobs with configurable filters.
]]
local mq                               = require('mq')
local ImGui                            = require 'ImGui'
local Icons                            = require('mq.ICONS')
local gIcon                            = Icons.MD_SETTINGS

local spawns                           = {}
local running                          = true
local myName                           = mq.TLO.Me.DisplayName()
local window_flags                     = bit32.bor(ImGuiWindowFlags.None)
local treeview_table_flags             = bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable,
    ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Sortable, ImGuiTableFlags.ScrollY)
local openGUI, drawGUI                 = true, true
local angle                            = 0
local size                             = 25
local column_count                     = 9
local script                           = 'MobList'
local direction_arrow                  = false
local LoadTheme                        = require('lib.theme_loader')
local defaults                         = require('lib.themes')
local characterName                    = mq.TLO.Me.DisplayName()
local themeFile                        = string.format('%s/MyThemeZ.lua', mq.configDir)
local configFile                       = string.format('%s/%s_moblist.lua', mq.configDir, characterName)
local themeName                        = 'Default'
local theme, settings, defaultSettings = {}, {}, {}
local mobheader                        = "\ay[\agMob List\ay]"

local updated_data                     = false

local colors                           = {
    red       = IM_COL32(255, 0, 0, 255),
    yellow    = IM_COL32(255, 255, 0, 255),
    white     = IM_COL32(255, 255, 255, 255),
    blue      = IM_COL32(0, 0, 255, 2551),
    lightBlue = IM_COL32(0, 255, 255, 255),
    green     = IM_COL32(0, 255, 0, 255),
    grey      = IM_COL32(158, 158, 158, 255),
    purple    = IM_COL32(255, 0, 255, 255),
}

local filter                           = {
    ['LevelLow']      = 1,
    ['LevelHigh']     = 135,
    ['Name']          = '',
    ['RangeLow']      = 0,
    ['RangeHigh']     = 50000,
    ['Body']          = '',
    ['Race']          = '',
    ['Class']         = '',
    ['Surname']       = '',
    ['Type']          = { 'PC', 'NPC', 'Untargetable', 'Mount', 'Pet', 'Corpse', 'Chest', 'Trigger', 'Trap', 'Timer', 'Item', 'Mercenary', 'Aura', 'Object', 'Banner', 'Campfire', 'Flyer', },
    ['Type_Selected'] = 2,
    ['name_reverse']  = false,
    ['body_reverse']  = false,
    ['race_reverse']  = false,
    ['class_reverse'] = false,
    ['conColor']      = true,
}

defaultSettings                        = {
    [script] = {
        Scale     = 1.0,
        LoadTheme = 'Default',
        locked    = false,
    },
}

local ColumnID_ID                      = 0
local ColumnID_Lvl                     = 1
local ColumnID_DisplayName             = 2
local ColumnID_Name                    = 3
local ColumnID_Distance                = 4
local ColumnID_Loc                     = 5
local ColumnID_Body                    = 6
local ColumnID_Race                    = 7
local ColumnID_Class                   = 8
local ColumnID_Direction               = 9
local ColumnID_Surname                 = 10
local themeID                          = 1
function RotatePoint(p, cx, cy, angle)
    local radians = math.rad(angle)
    local cosA = math.cos(radians)
    local sinA = math.sin(radians)

    local newX = cosA * (p.x - cx) - sinA * (p.y - cy) + cx
    local newY = sinA * (p.x - cx) + cosA * (p.y - cy) + cy

    return ImVec2(newX, newY)
end

function DrawArrow(topPoint, width, height, color)
    local draw_list = ImGui.GetWindowDrawList()
    local p1 = ImVec2(topPoint.x, topPoint.y)
    local p2 = ImVec2(topPoint.x + width, topPoint.y + height)
    local p3 = ImVec2(topPoint.x - width, topPoint.y + height)

    -- center
    local center_x = (p1.x + p2.x + p3.x) / 3
    local center_y = (p1.y + p2.y + p3.y) / 3

    -- rotate
    angle = angle + .01
    p1 = RotatePoint(p1, center_x, center_y, angle)
    p2 = RotatePoint(p2, center_x, center_y, angle)
    p3 = RotatePoint(p3, center_x, center_y, angle)

    draw_list:AddTriangleFilled(p1, p2, p3, ImGui.GetColorU32(color))
end

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function loadThemeSettings()
    if not File_Exists(configFile) then
        mq.pickle(configFile, defaultSettings)
        loadThemeSettings()
    else
        settings = dofile(configFile)
    end
    if not File_Exists(themeFile) then
        mq.pickle(themeFile, defaults)
        loadThemeSettings()
    else
        theme = dofile(themeFile)
    end
    if settings[script].LoadTheme == nil then
        settings[script].LoadTheme = themeName
    end
    if settings[script].locked == nil then
        settings[script].locked = false
    end
    themeName = settings[script].LoadTheme or themeName
    for tID, tData in pairs(theme.Theme) do
        if tData['Name'] == themeName then
            themeID = tID
        end
    end
end

local function isType(spawn)
    return spawn.Type() == filter.Type[filter.Type_Selected]
end

local function matchFilters(spawn)
    if not isType(spawn) then return false end
    if not spawn.Type() == filter.Type[filter.Type_Selected] then return false end
    if not (spawn.Level() >= filter.LevelLow and spawn.Level() <= filter.LevelHigh) then return false end
    if not (spawn.Distance() >= filter.RangeLow and spawn.Distance() <= filter.RangeHigh) then return false end
    if filter['name_reverse'] then
        if string.find(string.lower(spawn.Name()), string.lower(filter.Name)) or string.find(string.lower(spawn.DisplayName()), string.lower(filter.Name)) then return false end
    else
        if not string.find(string.lower(spawn.Name()), string.lower(filter.Name)) and not string.find(string.lower(spawn.DisplayName()), string.lower(filter.Name)) then return false end
    end
    if filter['body_reverse'] then
        if string.find(string.lower(spawn.Body()), string.lower(filter.Body)) then return false end
    else
        if not string.find(string.lower(spawn.Body()), string.lower(filter.Body)) then return false end
    end
    if filter['race_reverse'] then
        if string.find(string.lower(spawn.Race()), string.lower(filter.Race)) then return false end
    else
        if not string.find(string.lower(spawn.Race()), string.lower(filter.Race)) then return false end
    end
    if filter['class_reverse'] then
        if string.find(string.lower(spawn.Class()), string.lower(filter.Class)) then return false end
    else
        if not string.find(string.lower(spawn.Class()), string.lower(filter.Class)) then return false end
    end
    if filter['surname_reverse'] then
        if string.find(string.lower(spawn.Surname() or ""), string.lower(filter.Surname)) then return false end
    else
        if not string.find(string.lower(spawn.Surname() or ""), string.lower(filter.Surname)) then return false end
    end
    return true
end

local function create_spawn_list()
    local new_spawns = mq.getFilteredSpawns(matchFilters)
    spawns = new_spawns
    updated_data = true
end

local function main()
    create_spawn_list()
    loadThemeSettings()
    while running == true do
        mq.delay('1s')
        create_spawn_list()
    end
end

local current_sort_specs = nil
local function CompareWithSortSpecs(a, b)
    if not current_sort_specs then return false end

    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0
        if sort_spec.ColumnUserID == ColumnID_ID then
            if a.ID() == nil or b.ID() == nil then return false end
            delta = a.ID() - b.ID()
        elseif sort_spec.ColumnUserID == ColumnID_Lvl then
            if a.Level() == nil or b.Level() == nil then return false end
            delta = a.Level() - b.Level()
        elseif sort_spec.ColumnUserID == ColumnID_DisplayName then
            if a.DisplayName() == nil or b.DisplayName() == nil then return false end
            if a.DisplayName() < b.DisplayName() then
                delta = -1
            elseif b.DisplayName() < a.DisplayName() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Name then
            if a.Name() == nil or b.Name() == nil then return false end
            if a.Name() < b.Name() then
                delta = -1
            elseif b.Name() < a.Name() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Distance then
            if a.Distance() == nil or b.Distance() == nil then return false end
            delta = a.Distance() - b.Distance()
        elseif sort_spec.ColumnUserID == ColumnID_Loc then
            if a.Loc() == nil or b.Loc() == nil then return false end
            if a.Loc() < b.Loc() then
                delta = -1
            elseif b.Loc() < a.Loc() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Body then
            if a.Body() == nil or b.Body() == nil then return false end
            if a.Body() < b.Body() then
                delta = -1
            elseif b.Body() < a.Body() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Race then
            if a.Race() == nil or b.Race() == nil then return false end
            if a.Race() < b.Race() then
                delta = -1
            elseif b.Race() < a.Race() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Class then
            if a.Class() == nil or b.Class() == nil then return false end
            if a.Class() < b.Class() then
                delta = -1
            elseif b.Class() < a.Class() then
                delta = 1
            else
                delta = 0
            end
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end
    return a.ID() - b.ID() < 0
end

local function getConColor(spawn)
    local conColor = spawn.ConColor()
    local textColor = colors.purple
    if conColor == 'GREY' then
        textColor = colors.grey
    elseif conColor == 'GREEN' then
        textColor = colors.green
    elseif conColor == 'LIGHT BLUE' then
        textColor = colors.lightBlue
    elseif conColor == 'BLUE' then
        textColor = colors.blue
    elseif conColor == 'WHITE' then
        textColor = colors.white
    elseif conColor == 'YELLOW' then
        textColor = colors.yellow
    elseif conColor == 'RED' then
        textColor = colors.red
    end
    return textColor
end

local function reverseToggle(id, value, tooltip)
    if value then
        ImGui.PushStyleColor(ImGuiCol.Button, IM_COL32(180, 100, 0, 255))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, IM_COL32(210, 130, 0, 255))
    else
        ImGui.PushStyleColor(ImGuiCol.Button, IM_COL32(60, 60, 60, 255))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, IM_COL32(90, 90, 90, 255))
    end
    local clicked = ImGui.Button(Icons.MD_SWAP_HORIZ .. '##' .. id)
    ImGui.PopStyleColor(2)
    if ImGui.IsItemHovered() then ImGui.SetTooltip(tooltip or 'Reverse filter') end
    if clicked then value = not value end
    return value
end

local function displayGUI()
    if not openGUI then running = false end
    if mq.TLO.MacroQuest.GameState() ~= "INGAME" then return end
    local ColorCount, StyleCount = LoadTheme.StartTheme(theme.Theme[themeID])
    local flags = settings[script].locked and bit32.bor(window_flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize) or window_flags
    openGUI, drawGUI = ImGui.Begin("Mob List##", openGUI, flags)

    ImGui.PushFont(ImGui.GetFont(), ImGui.GetFontSize() * (1 + (28 / 100)))
    if drawGUI and not mq.TLO.Me.Zoning() then
        if ImGui.Button(gIcon .. '##MobList') then
            ImGui.OpenPopup('MobListPopup')
        end
        ImGui.SameLine()
        if ImGui.Button(Icons.MD_HIGHLIGHT_OFF .. '##ClearHighlights') then mq.cmd('/highlight reset') end
        if ImGui.IsItemHovered() then ImGui.SetTooltip('Clear highlighted mob list') end

        -- Place the popup context outside the button conditional to have it reactively check for the opening condition
        if ImGui.BeginPopup('MobListPopup') then
            if ImGui.BeginMenu('ThemeZ') then
                -- Iterate over themes to create menu items dynamically
                for k, data in pairs(theme.Theme) do
                    -- The third parameter is the selected condition, if true it will highlight the item
                    if ImGui.MenuItem(data.Name, '', (data.Name == themeName)) then
                        themeName = data.Name
                        themeID = k
                        settings[script].LoadTheme = themeName
                        -- Saving the settings to the configuration file using a fictional pickle function
                        mq.pickle(configFile, settings)
                    end
                end
                ImGui.EndMenu()
            end
            if ImGui.MenuItem('Name as consider color', '', filter.conColor) then
                filter.conColor = not filter.conColor
            end
            if ImGui.MenuItem('Display direction arrow', '', direction_arrow) then
                direction_arrow = not direction_arrow
            end
            if ImGui.MenuItem('Lock Window', '', settings[script].locked) then
                settings[script].locked = not settings[script].locked
                mq.pickle(configFile, settings)
            end
            ImGui.EndPopup()
        end
        if ImGui.IsMouseReleased(1) and ImGui.IsItemHovered() then
            ImGui.OpenPopup('MobListPopup')
        end

        if ImGui.CollapsingHeader("Filters", ImGuiTreeNodeFlags.DefaultOpen) then
            local filterItems = {
                {
                    width = 220,
                    render = function()
                        ImGui.Text("Lvl Rng")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(35)
                        filter.LevelLow = ImGui.InputInt('##LowLvl', filter.LevelLow, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Lowest level to display') end
                        ImGui.SameLine()
                        filter.LevelHigh = ImGui.InputInt('##HighLvl', filter.LevelHigh, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Highest level to display') end
                        ImGui.PopItemWidth()
                    end,
                },
                {
                    width = 270,
                    hasReverse = true,
                    render = function()
                        ImGui.Text("Name")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(200)
                        filter.Name = ImGui.InputText('##Name', filter.Name, 0)
                        ImGui.PopItemWidth()
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Name filter') end
                        ImGui.SameLine()
                        filter['name_reverse'] = reverseToggle('NameReverse', filter['name_reverse'], 'Reverse Filter Name')
                    end,
                },
                {
                    width = 210,
                    render = function()
                        ImGui.Text("Dist")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(50)
                        filter.RangeLow = ImGui.InputInt('##RangeLow', filter.RangeLow, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Minimum Distance') end
                        ImGui.SameLine()
                        filter.RangeHigh = ImGui.InputInt('##RangeHigh', filter.RangeHigh, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Maximum Distance') end
                        ImGui.PopItemWidth()
                    end,
                },
                {
                    width = 115,
                    render = function()
                        ImGui.PushItemWidth(85)
                        filter.Type_Selected = ImGui.Combo('##TypeCombo', filter.Type_Selected, filter.Type)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Type of mobs to display') end
                        ImGui.PopItemWidth()
                    end,
                },
                {
                    width = 195,
                    hasReverse = true,
                    render = function()
                        ImGui.Text("Body")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(100)
                        filter.Body = ImGui.InputText('##Body', filter.Body, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Body type filter') end
                        ImGui.PopItemWidth()
                        ImGui.SameLine()
                        filter['body_reverse'] = reverseToggle('BodyReverse', filter['body_reverse'], 'Reverse Filter Body Type')
                    end,
                },
                {
                    width = 195,
                    hasReverse = true,
                    render = function()
                        ImGui.Text("Race")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(100)
                        filter.Race = ImGui.InputText('##Race', filter.Race, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Race filter') end
                        ImGui.PopItemWidth()
                        ImGui.SameLine()
                        filter['race_reverse'] = reverseToggle('RaceReverse', filter['race_reverse'], 'Reverse Filter Race')
                    end,
                },
                {
                    width = 195,
                    hasReverse = true,
                    render = function()
                        ImGui.Text("Class")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(100)
                        filter.Class = ImGui.InputText('##Class', filter.Class, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Class filter') end
                        ImGui.PopItemWidth()
                        ImGui.SameLine()
                        filter['class_reverse'] = reverseToggle('ClassReverse', filter['class_reverse'], 'Reverse Filter Class')
                    end,
                },
                {
                    width = 195,
                    hasReverse = true,
                    render = function()
                        ImGui.Text("Surname")
                        ImGui.SameLine()
                        ImGui.PushItemWidth(100)
                        filter.Surname = ImGui.InputText('##Surname', filter.Surname, 0)
                        if ImGui.IsItemHovered() then ImGui.SetTooltip('Surname filter') end
                        ImGui.PopItemWidth()
                        ImGui.SameLine()
                        filter['surname_reverse'] = reverseToggle('SurnameReverse', filter['surname_reverse'], 'Reverse Filter Surname')
                    end,
                },
            }

            local spacing     = ImGui.GetStyle().ItemSpacing.x
            local iconW       = ImGui.GetFrameHeight() + spacing -- square icon button + one spacing gap

            -- Compute actual widths: fixed items use their declared width, items with a
            -- reverse toggle add the icon button size on top.
            for _, item in ipairs(filterItems) do
                item.actualWidth = item.width + (item.hasReverse and iconW or 0)
            end

            local availWidth = ImGui.GetWindowWidth()
            local i = 1
            while i <= #filterItems do
                local rowWidth = 0
                local rowEnd = i
                while rowEnd <= #filterItems do
                    local nextWidth = filterItems[rowEnd].actualWidth
                    if rowWidth + nextWidth > availWidth and rowEnd > i then break end
                    rowWidth = rowWidth + nextWidth
                    rowEnd = rowEnd + 1
                end
                local numCols = rowEnd - i
                if ImGui.BeginTable('##filter_row_' .. i, numCols, bit32.bor(ImGuiTableFlags.None)) then
                    for j = i, rowEnd - 1 do
                        ImGui.TableSetupColumn('##fc_' .. j, ImGuiTableColumnFlags.WidthFixed, filterItems[j].actualWidth)
                    end
                    ImGui.TableNextRow()
                    for j = i, rowEnd - 1 do
                        ImGui.TableNextColumn()
                        filterItems[j].render()
                    end
                    ImGui.EndTable()
                end
                i = rowEnd
            end
        end
        if direction_arrow == true then
            column_count = 11
        else
            column_count = 10
        end
        if ImGui.BeginTable('##List_table', column_count, treeview_table_flags) then
            ImGui.TableSetupColumn("ID", 0, 50, ColumnID_ID)
            ImGui.TableSetupColumn("Lvl", 0, 30, ColumnID_Lvl)
            ImGui.TableSetupColumn("Display Name", 0, 200, ColumnID_DisplayName)
            ImGui.TableSetupColumn("Name", 0, 200, ColumnID_Name)
            ImGui.TableSetupColumn("Dist", 0, 50, ColumnID_Distance)
            ImGui.TableSetupColumn("Loc", 0, 100, ColumnID_Loc)
            ImGui.TableSetupColumn("Body Type", 0, 80, ColumnID_Body)
            ImGui.TableSetupColumn("Race", 0, 80, ColumnID_Race)
            ImGui.TableSetupColumn("Class", 0, 70, ColumnID_Class)
            ImGui.TableSetupColumn("Surname", 0, 70, ColumnID_Surname)
            if direction_arrow == true then
                ImGui.TableSetupColumn("Direction", ImGuiTableColumnFlags.NoSort, 20, ColumnID_Direction)
            end
            ImGui.TableSetupScrollFreeze(0, 1)
            local sort_specs = ImGui.TableGetSortSpecs()
            if updated_data and sort_specs then
                sort_specs.SpecsDirty = true
                updated_data = false
            end
            if sort_specs then
                if sort_specs.SpecsDirty then
                    for n = 1, sort_specs.SpecsCount, 1 do
                        local sort_spec = sort_specs:Specs(n)
                    end
                    if #spawns > 1 then
                        current_sort_specs = sort_specs
                        table.sort(spawns, CompareWithSortSpecs)
                        current_sort_specs = nil
                    end
                    sort_specs.SpecsDirty = false
                end
            end
            ImGui.TableHeadersRow()
            local clipper = ImGuiListClipper.new()
            clipper:Begin(#spawns)
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                    local item = spawns[row_n + 1]
                    if (item.ID() or 0) > 0 then
                        -- Valid spawn, continue
                        ImGui.PushID(item)
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        ImGui.Selectable(tostring(item.ID() or 0), false, ImGuiSelectableFlags.SpanAllColumns)
                        if ImGui.IsItemHovered() then
                            if ImGui.IsMouseReleased(ImGuiMouseButton.Right) then
                                printf("%s \agHighlighting mobs named \ar%s", mobheader, item.DisplayName())
                                mq.cmdf('/highlight "%s"', item.DisplayName())
                            end
                            if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                                if ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyPressed(ImGuiKey.RightCtrl) then
                                    printf("%s \agNavigating \aogroup \agto \ar%s \ag ID \ar%s", mobheader,
                                        item.DisplayName(),
                                        item.ID())
                                    mq.cmdf('/dgae /nav id %s', item.ID())
                                else
                                    printf("%s \agNavigating \aoself \agto \ar%s \ag ID \ar%s", mobheader, item.Name(),
                                        item.ID())
                                    mq.cmdf('/nav id %s', item.ID())
                                end
                            end
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Level() or "")
                        if filter.conColor == false then
                            ImGui.TableNextColumn()
                            ImGui.Text(item.DisplayName() or "")
                            ImGui.TableNextColumn()
                            ImGui.Text(item.Name() or "")
                        else
                            local color = getConColor(item)
                            ImGui.TableNextColumn()
                            ImGui.TextColored(color, item.DisplayName() or "")
                            ImGui.TableNextColumn()
                            ImGui.TextColored(color, item.Name() or "")
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text(string.format("%d", item.Distance() or 0))
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Loc() or "")
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Body() or "")
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Race() or "")
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Class() or "")
                        ImGui.TableNextColumn()
                        ImGui.Text(item.Surname() or "")
                        ImGui.TableNextColumn()

                        if direction_arrow == true then
                            local cursorScreenPos = ImGui.GetCursorScreenPosVec()
                            --angle = getRelativeDirection(item.HeadingTo())
                            angle = item.HeadingTo.Degrees() - mq.TLO.Me.Heading.Degrees()
                            DrawArrow(ImVec2(cursorScreenPos.x + size / 2, cursorScreenPos.y), 5, 15,
                                ImVec4(0, 255, 0, 255))
                        end
                        ImGui.PopID()
                    end
                end
            end
            ImGui.EndTable()
        end
    end
    ImGui.PopFont()
    LoadTheme.EndTheme(ColorCount, StyleCount)
    ImGui.End()
end

mq.bind('/moblist', function(arg)
    if arg == 'lock' then
        settings[script].locked = not settings[script].locked
        mq.pickle(configFile, settings)
        printf("%s Window %s", mobheader, settings[script].locked and '\agLocked' or '\ayUnlocked')
    end
end)

mq.imgui.init('displayGUI', displayGUI)

main()
