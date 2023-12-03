------------------------------------------------------------------------------- 
-- Bulletins by j0hnny a1pha
-- v.01
-- For Talisman BBS
-------------------------------------------------------------------------------
-- Features:
--  Configurable light bar
--  New bulletin indicator
-------------------------------------------------------------------------------
-- Ensure that Lua 5.3, the LuaFileSystem (lfs) library is in your environment. 
-- You can install lfs with Luarocks:             
-- https://innovativeinnovation.github.io/ubuntu-setup/lua/luarocks.html     
-------------------------------------------------------------------------------

-- Variables - Set these to your liking  

local bullPath = "/bbs/gfiles" -- no trailing slash

-- Brackets are required for displayMenu coloring
local menuOptions = { 
    [1] = "[1] about r3tr0x",
    [2] = "[2] about talisman",
    [3] = "[3] bbs history",
    ['Q'] = "[Q] quit"
}
-- Y position (row) 
local menuPositions = {
    [1] = 19,      
    [2] = 20,       
    [3] = 21,      
    ['Q'] = 23      
}

-- X position (col) 
local startX = 56   

-- Talisman Color Codes
local colors = {
    foreground = {
        black = "|00", dark_blue = "|01", dark_green = "|02",
        dark_cyan = "|03", dark_red = "|04", dark_magenta = "|05",
        brown = "|06", grey = "|07", dark_grey = "|08",
        light_blue = "|09", light_green = "|10", light_cyan = "|11",
        light_red = "|12", light_magenta = "|13", yellow = "|14",
        white = "|15"
    },
    background = {
        black = "|16", blue = "|17", green = "|18", cyan = "|19",
        red = "|20", magenta = "|21", brown = "|22", grey = "|23"
    }
}

-- Color states for selected and unselected items
local selectedBgColor = colors.background.magenta
local selectedFgColor = colors.foreground.light_red
local unselectedFgColor = colors.foreground.dark_cyan
local bracketColor = colors.foreground.light_red
local numberColor = colors.foreground.grey

-------------------------------------------------------------------------------
-- Main Declarations & Functions
-------------------------------------------------------------------------------

local lfs = require("lfs")
-- Define ANSI escape code for cursor positioning
function positionCursor(row, col)
    bbs_write_string(string.format("\x1b[%d;%df", row, col))
end

-- Function to write a string at a specific position
function writeAtPosition(row, col, text)
    positionCursor(row, col)
    bbs_write_string(text)
end

-- Function to check if a bulletin is new
function isNewBulletin(bulletinFile, lastOnTime)
    local fileAttr = lfs.attributes(bulletinFile)
    if fileAttr then
        local fileModTime = fileAttr.modification
        --bbs_write_string(string.format("Debug: File: %s, ModTime: %s, LastOn: %s\n", 
         --                              bulletinFile, tostring(fileModTime), tostring(lastOnTime)))
        return fileModTime >= lastOnTime
    else
        bbs_write_string("Error getting file attributes for " .. bulletinFile .. "\n")
        return false
    end
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
            local bulletinFile = string.format(bullPath .. "/bulletin%d.ans", key)
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
                displayText = " " .. bracketOpen .. number .. closingBracket .. restText .. asterisk
            else
                displayText = " " .. unselectedFgColor .. option
            end
            displayText = displayText .. string.rep(" ", maxLength - #option + 1)
        end

        -- Write the option with the lightbar and then reset the background color
        writeAtPosition(row, startX, displayText .. colors.background.black)
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
    bbs_display_gfile("bull-main")
end

-- Load the main screen once before entering the loop
bbs_write_string("\x1b[?25l") --hide the cursor
bbs_display_gfile("bull-main")

-- Main interaction loop
local selected = '1'
local running = true
while running do
    displayMenu(selected, lastOnTimestamp)-- Display the menu with the current selection highlighted
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
    elseif key:upper() == 'B' then -- Down arrow logic
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
            loadBulletin(tonumber(selected)) -- Move down in the options
        end
    end
end

-- Make sure to exit cleanly
bbs_write_string("\x1b[?25h") --show the cursor
bbs_write_string("Exiting bulletin viewer...")
