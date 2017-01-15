--- Jammin'! dbus support.

assert(dbus)
local awful = require("awful")

local jdbus = {}

local cmd_fmt = "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.%s / org.freedesktop.MediaPlayer2.%s %s"
local default_player = "spotify"

local function default_callback(stdout, stderr, exitreason, exitcode)
   if exitcode ~= 0 then
      print("\nError " .. exitcode .. " from jammin' dbus command:")
      print(stderr)
      return
   end
end

function jdbus.send(args, callback)
   local player = args.player or default_player
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
   awful.spawn.easy_async(cmd_fmt:format(player, cmd, params), callback)
end

function jdbus.add_property_listener(listener)
   dbus.connect_signal("org.freedesktop.DBus.Properties", listener)
end

dbus.add_match("session", "interface='org.freedesktop.DBus.Properties', member='PropertiesChanged'")

return jdbus
