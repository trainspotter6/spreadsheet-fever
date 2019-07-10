-- Copyright (c) 2019 Jason Baker
-- AUTHORS: Jason Baker (jason.baker0@gmail.com)
-- All code copyright by the authors listed in the respective source files
-- and licenced under GPLv3 and higher.  See LICENSE for details.

require "serialize"

-- In general, I dont do windows
local function doWindows()
   return string.sub(package.config, 1, 1) == "\\"
end

function data()
    local me = "urbanspreadsheets_webdash_1"
    return {
        info = {
            minorVersion = 0,
            severityAdd = "NONE",
            severityRemove = "NONE",
            name = "Spreadsheet Fever",
            description = "Displays rail and factory info in a local .html file, and a log of stopped trains in a text file.", -- luacheck: ignore
            tags = { "Script Mod", "Misc", "UI mod" },
            authors = {{ name = "Urban Spreadsheets", role = 'CREATOR' },
                       { name = "Jason Baker", role = 'AUTHOR' }},
        },
        runFn = function(settings)
	    -- Is this even setable from the user settings.lua file?
            game.config.earnAchievementsWithMods = true
            -- TODO: create init.bat and choose between the two
            local out = nil
	    if doWindows() then 
	       io.popen("mods\\" .. me .. "\\scripts\\init.bat")
	    else 
	       io.popen("mods/" .. me .. "/scripts/init") 
	    end
            -- We don\'t want to open a file in /tmp/tf-dash/ until the init
            -- script finishes
            local lines = out:lines()
            local log = io.open("/tmp/tf-dash-debug-log.txt", "w+")
            log:write("lua version = ", _VERSION, "\n")
            local silent = true
            for line in lines do
                silent = false
                log:write(line, "\n")
            end
            log:write("mods/" .. me .. "/scripts/init finished\n")
            log:close()
            assert(silent, "error initializing html directory")
        end
    }
end

