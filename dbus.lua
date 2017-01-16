--- Jammin'! dbus support.

assert(dbus)
local dbus = dbus
local awful = require("awful")

local jdbus = {}

local dbus_dest = "org.mpris.MediaPlayer2.%s"
local dbus_path = "/org/mpris/MediaPlayer2"
local dbus_interface = "org.mpris.MediaPlayer2.Player"

local cmd_fmt = string.format("dbus-send --print-reply --dest=%s %s %s.%s %s",
                              dbus_dest,
                              dbus_path,
                              "%s", -- interface
                              "%s", -- member
                              "%s") -- argument list
local default_player = "spotify"

local function default_callback(stdout, stderr, exitreason, exitcode)
   if exitcode ~= 0 then
      print("\nError " .. exitcode .. " from jammin' dbus command:")
      print(stderr)
      return
   end
end

local function parse_value(t, raw_value)
   if t == "string" then
      return raw_value:gmatch('"(.*)"')()
   elseif t == "boolean" then
      return (raw_value == "true")
   elseif t == "objpath" then
      return nil -- give up
   elseif t == "array" then
      local ret = {}
      local entry_type = raw_value:match("^%[ (%w+)")
      if entry_type == "dict" then
         for entry in raw_value:gmatch("dict entry(%b())") do
            local en_key, en_t, en_raw_val = entry:match("^%( string \"([%w:]+)\" variant (%w+) (.*) %)$")
            ret[en_key] = parse_value(en_t, en_raw_val)
         end
      else
         for _, a_t, a_raw_val in raw_value:gmatch(" ((%w+) (%b\"\"))") do
            table.insert(ret, parse_value(a_t, a_raw_val))
         end
      end
      return ret
   else -- numeric
      return tonumber(raw_value)
   end
end

local function metadata_callback(callback, stdout, stderr, exitreason, exitcode)
   if exitcode ~= 0 then
      print("\nError " .. exitcode .. " from jammin' asynchronous metadata polling:")
      print(stderr)
      return
   end

   local raw_props = stdout:gsub("%s+", " ") -- shrink space
      :match("array (%b[])") -- get first array

   local props = parse_value('array', raw_props)
   callback(props)
end

function jdbus.poll_async(player, callback)
   local args = {
      player = player or default_player,
      interface = "org.freedesktop.DBus.Properties",
      cmd = "GetAll",
      params = {
         {"string", dbus_interface}
      }
   }
   jdbus.send(args, function(...) metadata_callback(callback, ...) end)
end

function jdbus.send(args, callback)
   local player = args.player or default_player
   local interface = args.interface or dbus_interface
   local cmd = args.cmd
   local params = ""
   for _, v in ipairs(args.params or {}) do
      if type(v) == "table" then
         params = params .. v[1] .. ":" .. v[2] .. " "
      elseif type(v) == "string" then
         params = params .. "string:" .. v .. " "
      elseif type(v) == "boolean" then
         params = params .. "boolean:" .. v .. " "
      end
   end
   callback = callback or default_callback

   local cmd_line = cmd_fmt:format(player, interface, cmd, params)
   print("Calling: " .. cmd_line)
   awful.spawn.easy_async(cmd_line, callback)
   collectgarbage()
end

function jdbus.add_property_listener(listener)
   local function handler(data, path, ...)
      if path == dbus_interface then
         listener(...)
      end
   end
   dbus.connect_signal("org.freedesktop.DBus.Properties", handler)
end

dbus.add_match("session", "interface='org.freedesktop.DBus.Properties', member='PropertiesChanged'")

return jdbus
