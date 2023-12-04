-- This program simply checks if there are new bulletins to display.
-- If there are, it loads and executes the main bulletins script.
-- Otherwise, it exits or performs other actions as needed.
-- Add this to logonevents.toml for a login event check.

local toml = require("toml")
local lfs = require("lfs")

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

-- Function to check if a bulletin is new
function isNewBulletin(bulletinFile, lastOnTime)
    local fileAttr = lfs.attributes(bulletinFile)
    if fileAttr then
        local fileModTime = fileAttr.modification
        return fileModTime >= lastOnTime
    else
        bbs_write_string("Error getting file attributes for ".. bulletinFile .. "\n")
        return false
    end
end

-- Read the Talisman configuration file and set paths
local iniPath = "/bbs/talisman.ini"  
local talismanConfig = parseIniFile(iniPath)
local gfilesPath = talismanConfig.paths and talismanConfig.paths["gfiles path"]
local dataPath = talismanConfig.paths and talismanConfig.paths["data path"]
local scriptPath = talismanConfig.paths and talismanConfig.paths["script path"]
local lastOnTimestamp = tonumber(bbs_get_user_attribute("last_on", "0"))

local function checkForNewBulletins(dataPath, lastOnTimestamp)
    local bulletinsConfig = readBulletinConfig(dataPath .. "/bulletins.toml")
    for _, bulletin in ipairs(bulletinsConfig.bulletin) do
        local bulletinFile = gfilesPath .. "/" .. bulletin.file .. ".ans"
        if isNewBulletin(bulletinFile, lastOnTimestamp) then
            return true
        end
    end
    return false
end

-- Check for new bulletins
if checkForNewBulletins(dataPath, lastOnTimestamp) then
    -- Load and execute the main bulletins script
    bbs_clear_screen()
    dofile(scriptPath .. "/bulletins.lua")
else
    bbs_write_string("|03No new bulletins...\r\n")
    bbs_pause()

    -- Exit or perform other actions as needed
end
