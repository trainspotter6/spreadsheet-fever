-- Copyright (c) 2019 Jason Baker
-- AUTHORS: Jason Baker (jason.baker0@gmail.com)
-- All code copyright by the authors listed in the respective source files
-- and licenced under GPLv3 and higher.	 See LICENSE for details.

local TaskManager = require "TaskManager"
local missionutil = require "missionutil"
require "serialize"

local cargo_icon = {
    COAL = 'cargo_coal.png',
    CONSTRUCTION_MATERIALS = 'cargo_construction_materials.png',
    CRUDE = 'cargo_crude.png',
    FOOD = 'cargo_food.png',
    FUEL = 'cargo_fuel.png',
    GOODS = 'cargo_goods.png',
    GRAIN = 'cargo_grain.png',
    IRON_ORE = 'cargo_iron_ore.png',
    LIVESTOCK = 'cargo_livestock.png',
    LOGS = 'cargo_logs.png',
    MACHINES = 'cargo_machines.png',
    OIL = 'cargo_oil.png',
    PASSENGERS = 'cargo_passengers.png',
    PLANKS = 'cargo_planks.png',
    PLASTIC = 'cargo_plastic.png',
    SLAG = 'cargo_slag.png',
    STEEL = 'cargo_steel.png',
    STONE = 'cargo_stone.png',
    TOOLS = 'cargo_tools.png',
}

-- Internally, speeds are represented in m/s
local speed_factor = {
  MPH = 2.237,
  KPH = 3.600,
  mps = 1.0,
}

-- In general, I don't do windows
local function doWindows()
   return string.sub(package.config, 1, 1) == "\\"
end

-- Write the <img> link for the given cargo type to a file f.
local function write_icon(f, cargo)
    local filename = cargo_icon[cargo]
    if not filename then error("Unknown cargo: " .. tostring(cargo)) end
    f:write("<img src='", filename, "' alt='", cargo, "'>")
end

-- Returns a span containing the first letter of name, with the full value
-- of name as hover text.
local function abbrev(name)
    return string.format("<span title='%s'>%s</span>",
			 name, string.sub(name, 1, 1))
end

local state_display = {
    AT_TERMINAL = abbrev("Reloading"),
    EN_ROUTE = abbrev("Moving"),
    -- The next two don't show up in the lines table:
    GOING_TO_DEPOT = abbrev("depoting"),
    IN_DEPOT = abbrev("Depoted"),
}

-- Appends an element to the given array
local function append(array, elt)
    array[#array + 1] = elt
end

-- Maps a function over an array, returning an array of results
local function map(fn, array)
    local ret = {}
    for i = 1, #array do
	ret[i] = fn(array[i])
    end
    return ret
end

-- Returns the number of hashed elements in a table (ignoring array-like ones).
local function ht_size(ht)
   local ret = 0
   for _, _ in pairs(ht) do
       ret = ret + 1
   end
   return ret
end

-- Serializes an object to a file.
local function serialize_to(obj, f)
    local before = io.output()
    io.output(f)
    serialize(obj)
    io.output(before)
end

local logfile = nil

-- Writes all arguments to the log file
local function log(...)
    logfile:write(table.unpack({...}))
    logfile:write("\n")
end

-- Dumps an object to the log file.  The optional second argument
-- describes the object dumped.
local function logObj(obj, pfx)
    if pfx then logfile:write(pfx, " = ") end
    serialize_to(obj, logfile)
    return obj
end

local settings = nil
local function getSettings()
   if not settings then
      local function tryOpen(name)
	 local ret, err = io.open(name)
	 if ret then log("Reading settings from ", name);
	 else log("Error opening ", name, ": ", err)  end
	 return ret
      end
      local sep = "/"
      if doWindows() then sep = "\\" end
      local home = os.getenv("HOME")
      if not home then
	 home = ((os.getenv("HOMEDRIVE") or "%HOMEDRIVE% unset")
		  .. ":\\" ..
		  (os.getenv("HOMEPATH") or "%HOMEPATH% unset"))
      end
      log("Loading settings: searching ", home)
      local f = tryOpen(home .. sep .. ".tfdashrc") or
	 tryOpen(home .. sep .. "tfdash.rc") or
	 tryOpen("mods/urbanspreadsheets/tfdash.rc")
      if f then
	 local r = load(f)
	 assert(type(r) == "function",
		"bad .tfdashrc: expected function, found " .. tostring(r))
	 settings = r()
      else
	 log("Could not load settings")
	 settings = {
	    speedUnit = "KPH",
	    fontSize = "8pt",
	    menuFontSize = "7pt",
	 }
      end
   end
   return settings
end

-- Returns a caching wrapper around game.interface.getEntity
local function makeGetEntity()
    local memo = {}
    return function(id)
	assert(type(id) == "number", "Invalid id type")
	local r = memo[id]
	if r then return r end
	r = game.interface.getEntity(id)
	memo[id] = r;
	return r
    end
end

-- There is no single place to initialize this variable, so we do it lazily.
local stop_log = nil

-- Detects when trains are stopped and on the tracks, logging to stopLog()
-- This function is called on every update callback, so performance is
-- critical.
--
-- known_trains is an array of train ids
-- stopped_trains is a map train_id -> unix time when stopped
-- getEntity is the caching game.interface.getEntity wrapper
--
-- Returns the new value of stopped_trains.
local function checkHealth(known_trains, stopped_trains, getEntity)
    if not stop_log then
	stop_log = io.open("/tmp/tf-dash/stop-log.txt", "w+")
    end
    local game_now_tm = nil
    local game_now_epoch = nil
    local function getGameTime_tm()
	if not game_now_tm then
	    local weird_datime = game.interface.getGameTime()
	    game_now_tm = {
		year = weird_datime.date.year,
		month = weird_datime.date.month,
		day = weird_datime.date.day,
		hour = math.floor(weird_datime.time / (60 * 60)),
		min = math.floor((weird_datime.time / 60) % 60),
		sec = math.floor(weird_datime.time % 60),
		-- do we need to even worry about this?
		remainder = weird_datime.time - math.floor(weird_datime.time)
	    }
	    -- logObj(weird_datime, "game time")
	    -- logObj(game_now_tm, "derived struct tm")
	end
	return game_now_tm
    end
    local function getGameTime_epoch()
	if not game_now_epoch then
	    local tm_time = getGameTime_tm()
	    game_now_epoch = os.time(tm_time) + tm_time.remainder
	    -- log("epoch time = ", game_now_epoch)
	    -- logObj(os.date("*t", game_now_epoch), "laundred epoch time")
	end
	return game_now_epoch
    end

    local total_stopped_trains = 0
    local new_stopped_trains = {}
    local new_unstopped_trains = {}
    for i = 1, #known_trains do
	local train = getEntity(known_trains[i])
	if train and train.speed == 0 and train.state == "EN_ROUTE" then
	    total_stopped_trains = total_stopped_trains + 1
	    if not stopped_trains[train.id] then
		log("new stopped train: ", train.name, " ", train.id)
		stopped_trains[train.id] = getGameTime_epoch()
		append(new_stopped_trains, train)
	    end
	 end
    end
--  if ht_size(stopped_trains) > total_stopped_trains then
--	We know there are unstopped trains, but it cost us one iteration
--	over the hastable anyway
    for k in pairs(stopped_trains) do
	local train = getEntity(k)
	if not train then
	    log("train ", k, " disappeared while stopped")
	    stopped_trains[k] = nil
	elseif train.speed ~= 0 or train.state ~= "EN_ROUTE" then
	    log("new unstopped train: ", train.name, " ", train.id)
	    append(new_unstopped_trains, train)
	end
    end

    if #new_stopped_trains ~= 0 or #new_unstopped_trains ~= 0 then
	local stamp = (
	    os.date("%F %T", getGameTime_epoch())
	    ..
	    string.format("%0.3f", getGameTime_tm().remainder):sub(2)
	    ..
	    ": ")
	for i = 1, #new_unstopped_trains do
	    local train = new_unstopped_trains[i]
	    log(stamp, train.name, " stopped at ", stopped_trains[train.id],
		" and restarted at ", getGameTime_epoch())
	    -- Now, we need to account for the fact that time increases 2s
	    -- for every day that date increases, and time will roll over
	    -- past midnight once in a full-length game.
	    local b = stopped_trains[train.id]
	    local e = getGameTime_epoch()
	    local stopped_days =  math.floor(e/86400) - math.floor(b/86400)
	    b = b % 86400
	    e = e % 86400
	    if e < b then e = e + 86400 end
	    local stopped_time_unix = e - b
	    stop_log:write(stamp, getEntity(train.line).name, " ",
			   train.name, " started after ", stopped_days,
			   " days ", os.date("!%T", stopped_time_unix), "\n")
	    stopped_trains[train.id] = nil
	end
	for i = 1, #new_stopped_trains do
	    local train = new_stopped_trains[i]
	    stop_log:write(stamp, getEntity(train.line).name, " ",
			   train.name, " stopped on tracks\n")
	end
	stop_log:flush()
	logObj(stopped_trains, "updated stopped_trains")
    end
    -- even though we just modified it in-place
    return stopped_trains
end

-- Writes an html table of train status to the file f, and returns an array
-- of entitiy ids for all trains attached to lines.
local function genRailTable(f, getEntity)
    -- First, we build an array of line_info records containing
    -- a line entity and arrays of associated train and station_group entities
    -- sorted by line name
    local known_trains = game.interface.getVehicles({ carrier = "RAIL" })
    local known_stations = {}
    local line_info_by_id = {}
    for i = 1, #known_trains do
	local train = getEntity(known_trains[i])
	if not train.line then	-- luacheck: ignore 542
	    -- TODO: build lists of trains en-route to and at depot
	elseif line_info_by_id[train.line] then
	    append(line_info_by_id[train.line].train, train)
	else
	    local line = getEntity(train.line)
	    line_info_by_id[train.line] = {
		train = { train },
		line = line,
		station = map(getEntity, line.stops),
	    }
	    for j = 1, #line.stops do
		if not known_stations[line.stops[j]] then
		    known_stations[line.stops[j]] = getEntity(line.stops[j])
		end
	    end
	end
    end
    local line_info = {}
    for _, v in pairs(line_info_by_id) do
	append(line_info, v)
    end
    table.sort(line_info, function(a, b) return a.line.name < b.line.name end)

    -- logObj(line_info, "line_info")

    -- Next, compute some column group sizes for our table
    local max_cargos = 0
    for i = 1, #line_info do
	for j = 1, #line_info[i].train do
	    max_cargos = math.max(max_cargos,
				  ht_size(line_info[i].train[j].capacities))
	end
    end
    -- log("max_cargos = ", max_cargos)

    -- Finally, generate the damn thing
    f:write("<table class='lines'>\n",
	    "<thead>\n",
	    "<tr><th colspan =", 5 + max_cargos, ">Rail Lines</th></tr>\n",
	    "<tr><th>Name</th><th>Train</th>",
	    "<th><span title='State'>St</span></th>",
	    "<th><span title='Speed'>Sp</span></th>",
	    "<th>Heading</th>",
	    "<th colspan=", max_cargos, ">Cargo</th></tr>\n",
	    "</thead><tbody>\n")

    local function genTrainCols(train, stations)
	local td_attrs = ""
	if train.speed == 0 and train.state == "EN_ROUTE" then
	    td_attrs = " class='stopped'"
	end
	local td = "<td" .. td_attrs .. ">"
	local td_num = "<td" .. td_attrs .. " style='text-align: right'>"
	f:write(td, train.name, "</td>\n")
	f:write(td, state_display[train.state] or train.state, "</td>\n")
	local c = speed_factor[settings.speedUnit]
	f:write(td_num, math.floor(c * train.speed + 0.5), "</td>\n")
	-- Look at that, indexing from 0 like sane people do
	f:write(td, stations[train.stopIndex + 1].name, "</td>\n")
	for cargo, cap in pairs(train.capacities) do
	    f:write(td_num, train.cargoLoad[cargo] or 0, "/", cap)
	    write_icon(f, cargo)
	    f:write("</td>\n")
	end
	local empty_cols = max_cargos - ht_size(train.capacities)
	if empty_cols > 0 then
	    f:write("<td", td_attrs, " colspan=", empty_cols, "></td>\n")
	end
    end

    for i = 1, #line_info do
	local info = line_info[i]
	f:write("<tr><td rowspan=", #info.train)
	if bit32.band(1, i) == 0 then
	    f:write(" class='stripe'")
	end
	f:write(">", info.line.name, "</td>\n")
	genTrainCols(info.train[1], info.station)
	for j = 2, #info.train do
	    f:write("</tr><tr>\n")
	    genTrainCols(info.train[j], info.station)
	end
    end
    f:write("</tr></tbody></table>\n")
    -- and return an up-to-date known train list for future checkHealth calls
    return known_trains, known_stations
end

local function genRailStationTable(f, getEntity, rail_station_groups)
    local stations = {}
    for _, group in pairs(rail_station_groups) do
	-- seems like this shouldn't always be true, but it is
	assert(#group.stations == 1)
	local station = getEntity(group.stations[1])
	append(stations, {
	    name = group.name,
	    cargoWaiting = group.cargoWaiting,
	    isCargo = station.cargo,
	})
    end
    local function cmpInfo(a, b)
	if a.isCargo == b.isCargo then
	    return a.name < b.name
	else
	    return a.isCargo
	end
    end
    table.sort(stations, cmpInfo)

    f:write("<table class='stations'>\n",
	    "<thead>\n",
	    "<tr><th colspan=2>Waiting Cargo</th></tr>\n",
	    "<tr><th>Station</th><th>Cargo</th></tr>\n",
	    "</thead><tbody>\n")
    for i = 1, #stations do
	if ht_size(stations[i].cargoWaiting) > 0 then
	    f:write("<tr class='striped'><td>", stations[i].name, "</td>\n")
	    local pfx = "<td class='num'>"
	    for cargo, count in pairs(stations[i].cargoWaiting) do
		f:write(pfx, count)
		write_icon(f, cargo)
		pfx = "<br>"
	     end
	     f:write("</td></tr>\n")
	end
    end
    f:write("</tbody></table>\n")
end

-- We don't trust the performance of getEntities, so we cache SIM_BUILDING
-- ids between genFactoryTable calls.
local factory_ids = nil

local function genFactoryTable(f, getEntity)
    if not factory_ids then
	factory_ids = game.interface.getEntities(
	    { pos = { 0, 0 }, radius=999999 }, { type = "SIM_BUILDING" })
    end
    local factories = map(getEntity, factory_ids)
    table.sort(factories, function(a, b) return a.name < b.name end)

    f:write("<Table class='factories'>\n",
	    "<thead>\n",
	    "<tr><th colspan=3>Factories</th></tr>\n",
	    "<tr><th>Name</th><th>Max</th><th>Status</th>\n",
	    "</thead><tbody>\n")
    for i = 1, #factories do
	local factory = factories[i]
	-- Checking whether a factory is online is tricky: Raw resource
	-- producers fill up their local storage when the game starts, and
	-- level = 0 doesn't tell us whether we're producing 0/100 or 99/100.
	if factory.itemsConsumed._sum > 0 or factory.itemsShipped._sum > 0 then
	    f:write("<tr")
	    local status = "Normal"
	    if factory.nextUpgradeInMonths < 8 then
	      f:write(" class='growing'")
	      status = string.format(
		  "Growing in %dm", factory.nextUpgradeInMonths)
	    elseif factory.nextDowngradeInMonths < 8 then
	      f:write(" class='shrinking'")
	      status = string.format(
		  "Shrinking in %dm", factory.nextDowngradeInMonths)
	    end
	    f:write("><td>", factory.name, "</td>\n")
	    f:write("<td class='num'>", 100 * 2^factory.level, "</td>\n")
	    f:write("<td>", status, "</td></tr>\n")
	end
    end
    f:write("</tbody></table>\n")
end

-- Writes our main ui file: /tmp/tf-dash/dash.html.  This method is called
-- up to once per second of walltime (in the first update callback of the
-- second).  It generates the main body of the file and calls methods like
-- genRailTable to fill in the details.	 It returns the latest known train
-- list (computed in genRailTable).
local function genFile(delay, observerCalls, getEntity)
    -- TF unbinds os.rename, os.remove, and os.exit.  We might be able to
    -- atomicaly update the file with
    -- os.popen("mv /tmp/tf-dash.html.new /tmp/tf-dash.html"), but shelling
    -- out once a second may be excessive
    -- local f = io.open("/tmp/tf-dash/dash.html.new", "w+")
    local f = io.open("/tmp/tf-dash/dash.html", "w+")
    f:write("<!DOCTYPE html>\n")
    f:write("<html lang='en'><head>\n")
    f:write("<title>Spreadsheet Fever</title>\n")
    f:write("<script>tfdash = { fps: ", observerCalls, " }</script>\n")
    f:write("<script src='tf-dash.js'></script>\n")
    f:write("<link rel='stylesheet' href='tf-dash.css' type='text/css'>\n")
    f:write("<link rel='shortcut icon' href='favicon.ico'>\n")
    f:write("<meta charset='UTF-8'>\n")
    f:write("<style>\n")
    f:write("body { font-size: ", getSettings().menuFontSize, " }\n")
    f:write("table { font-size: ", getSettings().fontSize, " }\n")
    f:write("</style>")
    f:write("</head><body>\n")
    f:write("<div style='float: left'>FPS = ",
	    observerCalls, "/lag = ", delay, "s</div>\n")
    f:write("<div style='float: right' id='menu'></div>\n")
    local known_trains, known_stations = genRailTable(f, getEntity)
    genRailStationTable(f, getEntity, known_stations)
    genFactoryTable(f, getEntity)
    f:write("</body></html>\n")
    f:close()
    -- local r, err = os.rename("/tmp/tf-dash/dash.html.new",
    --				"/tmp/tf-dash/dash.html")
    -- if not r then log("rename failed: ", err) end
    return known_trains
end

local function makeObserver()
    local next_dump_time = os.time()
    local updates_per_dump = 0
    local info = {
	name = "Observer Task",
	-- Be sure to update README.md#Usage when this var changes
	description = "This dialog box is the only native UI element in Spreadsheet Fever. To see the rest, point your browser at file:///tmp/tf-dash/dash.html, and run tail -f /tmp/tf-dash/stop-log.txt in a terminal. (In windows, these paths are relative to the drive where steam is installed. This mod is free software: see LICENSE for details." -- luacheck: ignore
	-- visible = false
    }
    local task = missionutil.makeTask(info)
    local known_trains = { }	-- set entity-id (map values all true)
    local stopped_trains = { }	-- map entity-id -> in-game stop time
    task.update = function(_)
	local now = os.time()
	local getEntity = makeGetEntity()
	updates_per_dump = updates_per_dump + 1
	stopped_trains = checkHealth(known_trains, stopped_trains, getEntity)

	if (next_dump_time > now) then return end
	known_trains = genFile(now - next_dump_time, updates_per_dump,
			       getEntity)
	next_dump_time = now + 1;
	updates_per_dump = 0;
    end
    return task
end

function data()
    logfile = io.open("/tmp/tf-dash-debug-log.txt", "a+")
    logfile:setvbuf("line")
    logfile:write("logging initialized\n")
    local tm = TaskManager.new()
    tm:register("observer", makeObserver)
    local mission = missionutil.makeMissionInterface(tm)
    mission.onInit(function()
	-- We need to call tm:add after this callback is invoked for
	-- obscure reasons (presumably so that the game can build back-links).
	tm:add("observer")
    end)
    return mission
end
