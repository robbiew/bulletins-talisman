-- About -----------------------------------------------------------------------
-- Bulletins by j0hnny a1pha
-- v.01
-- For Talisman BBS
--------------------------------------------------------------------------------

-- Features --------------------------------------------------------------------
--  Reads talisman.ini paths, bulletins.toml
--  Configurable light bar position & colors
--  New bulletin since last logon indicator (asterisk)
--  Page up/down for full-screen reading
--  Filters out SAUCE records from ANSI art
--  Random menu art
--------------------------------------------------------------------------------

-- Requirements ----------------------------------------------------------------
-- Lua 5.3 installed (not 5.4):
--      `sudo apt install lua5.3`
-- The LuaFileSystem (lfs) library is in your environment:
--      https://github.com/lunarmodules/luafilesystem
-- TOML parser library is in your environment:
--      https://github.com/LebJe/toml.lua
--------------------------------------------------------------------------------

-- Instructions ----------------------------------------------------------------
-- Create menus art for the bulletin (e.g. bull-main1.ans, bull-main2.ans, etc)
-- Create individual bulletins (e.g.bulletin1.ans, bulletin2.ans, etc)
-- Add bulletin config to Talisman's data/bulletins.toml file
-- Edit varaibles below to your liking
--------------------------------------------------------------------------------

-- Variables -------------------------------------------------------------------
local iniPath = "/bbs/talisman.ini"     -- path to Talisman config file
local bullMain = "bull-main"            -- name menu files "bull-main1.ans" etc
local maxBulletinMainFiles = 2          -- How many random bull-main files

-- X & Y menu positions (row & col)
local startX = 56
local startY = 19

-- Talisman Color Codes
local colors = {
    foreground = {
        black = "|00",
        dark_blue = "|01",
        dark_green = "|02",
        dark_cyan = "|03",
        dark_red = "|04",
        dark_magenta = "|05",
        brown = "|06",
        grey = "|07",
        dark_grey = "|08",
        light_blue = "|09",
        light_green = "|10",
        light_cyan = "|11",
        light_red = "|12",
        light_magenta = "|13",
        yellow = "|14",
        white = "|15"
    },
    background = {
        black = "|16",
        blue = "|17",
        green = "|18",
        cyan = "|19",
        red = "|20",
        magenta = "|21",
        brown = "|22",
        grey = "|23"
    }
}

-- Color states for selected and unselected items
local selectedBgColor = colors.background.magenta
local selectedFgColor = colors.foreground.light_red
local unselectedFgColor = colors.foreground.dark_cyan
local bracketColor = colors.foreground.light_red
local numberColor = colors.foreground.grey
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Main Declarations & Functions (no more config options below)
-------------------------------------------------------------------------------

local maxCols =  math.floor(bbs_get_term_width()+0.5)  -- convert float to integer
local maxRows =  math.floor(bbs_get_term_height()+0.5) -- convert float to integer

local lfs = require("lfs")
local toml = require("toml")


-- Function to read and parse the Talisman.ini configuration file
function parseIniFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Unable to open file: " .. filePath)
        return nil
    end

    local data = {}
    local currentSection
    for line in file:lines() do
        -- Check if line is a comment
        if not line:match("^;") then
            if line:match("^%[.-%]$") then
                -- New section
                currentSection = line:match("^%[(.-)%]$")
                data[currentSection] = {}
            elseif line:match("^[%w_ ]+%s*=%s*.+") then
                -- Key-value pair
                local key, value = line:match("([%w_ ]+)%s*=%s*(.+)")
                key = key:match("^%s*(.-)%s*$")  -- Trim leading and trailing spaces
                if currentSection then
                    data[currentSection][key] = value
                else
                    data[key] = value
                end
            end
        end
    end

    file:close()
    return data
end

-- Function to read and parse the Bulletins TOML configuration file
function readBulletinConfig(configFilePath)
    local file = io.open(configFilePath, "r")
    if not file then
        error("Unable to open TOML config file: " .. configFilePath)
        return nil
    end

    local content = file:read("*all")
    file:close()

    local succeeded, parsedData = pcall(toml.decode, content)
    if not succeeded then
        error("Error parsing TOML file: " .. parsedData)  -- parsedData contains the error message
    end
    return parsedData
end

-- Function to dynamically create menu options from TOML data
function createMenuOptionsFromToml(tomlData)
    local menuOptions = {}
    local menuPositions = {}
    local yPos = startY  -- Starting Y position (row) for menu options

    for _, bulletin in ipairs(tomlData.bulletin) do
        local key = bulletin.hotkey
        local name = bulletin.name
        local secLevel = bulletin.sec_level  -- You can use this for access control if needed

        menuOptions[key] = "[" .. key .. "] " .. name
        menuPositions[key] = yPos
        yPos = yPos + 1
    end

    -- Add the quit option
    menuOptions['Q'] = "[Q] Quit"
    menuPositions['Q'] = yPos

    return menuOptions, menuPositions
end

-- Read the Talisman configuration file and set paths
local talismanConfig = parseIniFile(iniPath)
local gfilesPath = talismanConfig.paths and talismanConfig.paths["gfiles path"]
local dataPath = talismanConfig.paths and talismanConfig.paths["data path"]

-- Read the Bulletin TOML configuration file and create menu options
local tomlData = readBulletinConfig(dataPath .. "/bulletins.toml")
menuOptions, menuPositions = createMenuOptionsFromToml(tomlData)

-- Define ANSI escape code for cursor positioning
function positionCursor(row, col)
    bbs_write_string(string.format("\x1b[%d;%df", row, col))
end

-- Function to write a string at a specific position
function writeAtPosition(row, col, text)
    positionCursor(row, col)
    bbs_write_string(text)
end

-- Function to display a random bulletin main file
function displayRandomBulletinMain()
    local randomNumber = math.random(1, maxBulletinMainFiles)
    local randomBulletinFile = string.format("%s%d", bullMain, randomNumber)

    bbs_clear_screen()
    bbs_display_gfile(randomBulletinFile)
end

-- Function to check if a bulletin is new
function isNewBulletin(bulletinFile, lastOnTime)
    local fileAttr = lfs.attributes(bulletinFile)
    if fileAttr then
        local fileModTime = fileAttr.modification
        return fileModTime >= lastOnTime
    else
        bbs_write_string("Error getting file attributes for " .. bulletinFile .. "\n")
        return false
    end
end

function display_and_scroll_file(bulletinNumber)
    local bulletinFile = string.format(gfilesPath .. "/bulletin%d.ans", bulletinNumber)
    local file = io.open(bulletinFile, "r")
    if not file then
        bbs_write_string("Error opening file: " .. bulletinFile .. "\r\n")
        return
    end

    local content = file:read("*all")
    file:close()

    -- Check for and remove SAUCE record
    local sauceStart = content:find("SAUCE00")
    if sauceStart then
        content = content:sub(1, sauceStart - 2)
    end

    -- Split the content into lines
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local pageSize = maxRows-1
    local currentPage = 1
    local totalPages = math.ceil(#lines / pageSize)

    local function displayPage()
        bbs_clear_screen()
        for i = 1, pageSize do
            local lineIndex = (currentPage - 1) * pageSize + i
            if lines[lineIndex] then
                if lineIndex == totalLines then
                    -- If it's the last line, do not append "\r\n"
                    bbs_write_string(lines[lineIndex])
                else
                    bbs_write_string(lines[lineIndex] .. "\r\n")
                end
            end
        end
        bbs_write_string("\x1b[".. maxRows .. ";1f")
        local pageInfo = colors.background.magenta .. colors.foreground.white .. " Page " .. currentPage .. " of " .. totalPages
        bbs_display_gfile("footer")
        bbs_write_string("\x1b[".. maxRows .. ";1f")
        bbs_write_string(pageInfo)
        bbs_write_string("|00")  -- Reset to default colors
    end

    -- Initially display the first page
    displayPage()

    local key
    repeat
        key = bbs_getchar()

        local pageChanged = false
        if key:upper() == 'B' then -- Down arrow
            if currentPage < totalPages then
                currentPage = currentPage + 1
                pageChanged = true
            end
        elseif key:upper() == 'A' then -- Up arrow
            if currentPage > 1 then
                currentPage = currentPage - 1
                pageChanged = true
            end
        end

        -- Redraw the page only if it changed
        if pageChanged then
            displayPage()
        end

    until key == 'q' or key == 'Q' -- 'q', 'Q'

    bbs_clear_screen()
    displayRandomBulletinMain()
end

function displayMenu(selectedOption, lastOnTime)
    -- Find the length of the longest menu option
    local maxLength = 0
    for _, option in pairs(menuOptions) do
        maxLength = math.max(maxLength, #option)
    end

    for key, option in pairs(menuOptions) do
        local row = menuPositions[key]
        local isSelected = tostring(key) == selectedOption
        local asterisk = ""

        -- Only check for numeric keys, skip for 'Q'
        if tonumber(key) then
            local bulletinFile = string.format(gfilesPath .. "/bulletin%d.ans", key)
            if isNewBulletin(bulletinFile, lastOnTime) then
                asterisk = "*"
            end
        end

        local displayText
        if isSelected then
            -- Color for selected item
            displayText = selectedBgColor .. selectedFgColor .. " " .. option .. string.rep(" ", maxLength - #option + 1)
        else
            -- Color for unselected item
            local bracketOpen, number, rest = option:match("(%[)([^%]]+)(].+)")
            if bracketOpen and number and rest then
                local colorBracket = bracketColor
                local colorNumber = numberColor
                local colorRest = unselectedFgColor

                -- Applying colors to each part
                bracketOpen = colorBracket .. bracketOpen
                number = colorNumber .. number
                local closingBracket, restText = rest:match("(])(.+)")
                closingBracket = colorBracket .. closingBracket
                restText = colorRest .. restText

                -- Combining the parts
                displayText = " " .. bracketOpen .. number .. closingBracket .. restText
            else
                displayText = " " .. unselectedFgColor .. option
            end
            displayText = displayText .. string.rep(" ", maxLength - #option + 1)
        end

        -- Write the option with the lightbar and then reset the background color
        writeAtPosition(row, startX,
            displayText .. colors.background.black .. " " .. colors.foreground.dark_red .. asterisk)
    end
end

-- Retrieve the laston timestamp as a number
local lastOnTimestamp = tonumber(bbs_get_user_attribute("last_on", "0"))

-- Function to load a bulletin
function loadBulletin(bulletinNumber)
    local bulletinFile = string.format("bulletin%d", bulletinNumber)
    bbs_clear_screen()
    bbs_display_gfile_pause(bulletinFile)
    bbs_pause()
    displayRandomBulletinMain()
end

-- Load the main screen once before entering the loop
bbs_write_string("\x1b[?25l") --hide the cursor
displayRandomBulletinMain()

-- Main interaction loop -------------------------------------------------------

local selected = '1'
local running = true
while running do
    displayMenu(selected, lastOnTimestamp) -- Display the menu with the current selection highlighted
    local key = bbs_getchar()

    if key == '1' or key == '2' or key == '3' then
        selected = key
    elseif key:upper() == 'Q' then
        running = false
    elseif key:upper() == 'A' then -- Up arrow logic
        if selected == '1' then
            selected = 'Q'
        elseif selected == 'Q' then
            selected = '3'
        else
            selected = tostring(tonumber(selected) - 1) -- Move up in the options
        end
    elseif key:upper() == 'B' then                      -- Down arrow logic
        if selected == 'Q' then
            selected = '1'
        elseif selected == '3' then
            selected = 'Q'
        else
            selected = tostring(tonumber(selected) + 1)
        end
    elseif key == 'enter' or key == '\013' then -- Enter key logic
        if selected == 'Q' then
            running = false
        else
            -- loadBulletin(tonumber(selected))
            display_and_scroll_file(tonumber(selected))
        end
    end
end

-- Make sure to exit cleanly
bbs_write_string("\x1b[?25h") --show the cursor