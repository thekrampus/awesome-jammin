----------------------------------------------------------------
--- Jammin'! A dbus-based media widget for awesome
--
-- @author Krampus &lt;tetramor.ph&gt;
-- @module jammin
----------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")

local animation = require("jammin.animation")

local jammin = {}
jammin.__index = jammin

local track_fmt = ' ${track.title} <span color="white">${track.artist}</span> '
local tooltip_fmt = '   ${track.title}\n' ..
   '<span color="white">by</span> ${track.artist}\n' ..
   '<span color="white">on</span> ${track.album}\n' ..
   '   <span color="green">${track.year}</span>'

local default_player = "spotify"

local function send_media_cmd(player, cmd)
   local dbus_cmd = "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.%s /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.%s"
   awful.spawn(dbus_cmd:format(player, cmd))
end

local function format(fmt, track)
   for match, key in fmt:gmatch("(%${track%.(.-)})") do
      fmt = fmt:gsub(match, track[key] or "")
   end
   return fmt
end

local function sanitize(raw_string)
   return raw_string
      :gsub("&", "&amp;")
      :gsub("<", "&lt;")
      :gsub(">", "&gt;")
      :gsub("'", "&apos;")
      :gsub("\"", "&quot;")
end

function jammin.playpause(player)
   send_media_cmd(player or default_player, "PlayPause")
end

function jammin.next(player)
   send_media_cmd(player or default_player, "Next")
end

function jammin.previous(player)
   send_media_cmd(player or default_player, "Previous")
end

function jammin.vol_set(n)
   awful.spawn("amixer -q set Master " .. n .. "%")
end

function jammin.vol_up()
   awful.spawn("amixer -q set Master 5%+")
end

function jammin.vol_down()
   awful.spawn("amixer -q set Master 5%-")
end

function jammin.mute()
   awful.spawn("amixer -q set Master playback toggle")
end

local function make_menu()
   local theme = {
      width = 20,
      height = 220
   }

   local menu = awful.menu{ theme = theme }

   local function menu_widget()
      local beautiful = require("beautiful")
      local gears = require("gears")

      local function handle_shape(cr, w, h)
         return gears.shape.transform(gears.shape.partially_rounded_rect)
            : scale(0.9, 0.9) (cr, h, h, true, false, true, true, theme.width)
      end
      local slider = wibox.widget {
         bar_shape = gears.shape.rounded_bar,
         bar_height = 2,
         bar_color = beautiful.fg_focus,
         handle_color = "[0]#000000",
         handle_shape = handle_shape,
         handle_border_color = beautiful.fg_focus,
         handle_border_width = 2,
         handle_width = theme.width,
         handle_margins = {left=1, top=2},
         bar_margins = {left=7, right=10, top=theme.width/2 - 1},
         value = 100,
         widget = wibox.widget.slider
      }

      local function slider_callback()
         jammin.vol_set(slider.value)
      end

      slider:connect_signal("widget::redraw_needed", slider_callback)

      local w = wibox.container {
         wibox.container {
            slider,
            width = theme.height,
            strategy = 'max',
            widget = wibox.container.constraint
         },
         direction = 'east',
         widget = wibox.container.rotate
      }
      return {akey = nil,
              widget = w,
              cmd = nil}
   end

   menu:add({ new = menu_widget })

   return menu
end

function jammin:set_track_info()
   if self.track then
      self.music_box:set_markup(format(self.track_fmt, self.track))
      self.tooltip:set_markup(format(self.tooltip_fmt, self.track))
   else
      self.music_box:set_text("⣹")
      self.tooltip:set_markup("... nothing's playing...")
   end
end

--- Handler function for PlaybackStatus change signals
-- Updates the playbox animation to reflect the playback status
function jammin:handle_playback(status)
   if status == "Paused" then
      self.play_anim:stop()
   elseif status == "Stopped" then
      self.track = nil
      self.play_anim:stop()
      self.play_anim:set_markup("⣏")
   elseif status == "Playing" then
      self.play_anim:start()
   end
end

--- Handler function for Metadata change signals
-- Updates the musicbox to reflect the new track
function jammin:handle_trackchange(metadata)
   local nfields = 0
   for _ in pairs(metadata) do
      nfields = nfields + 1
   end
   if nfields == 0 then
      -- Empty metadata indicates that spotify has been closed
      self.track = nil
   else
      self.track = {}
      -- Parse and sanitize the data to print
      local title = metadata["xesam:title"] or ""
      self.track.title = sanitize(title)
      local artist_list = metadata["xesam:artist"] or ""
      self.track.artist = sanitize(table.concat(artist_list, ", "))
      local album = metadata["xesam:album"] or ""
      self.track.album = sanitize(album)
      local date = metadata["xesam:contentCreated"] or ""
      self.track.year = date:match("^(%d*)-") or "----"
   end
end

--- General handler function, callback on org.freedesktop.DBus.Properties
function jammin:on_signal(data, interface, changed, invalidated)
   if data.member == "PropertiesChanged" then
      if interface == "org.mpris.MediaPlayer2.Player" then
         if changed.PlaybackStatus ~= nil then
            -- Track play/pause/stop signal
            self:handle_playback(changed.PlaybackStatus)
         end
         if changed.Metadata ~= nil then
            -- Track change signal
            self:handle_trackchange(changed.Metadata)
         end
         self:set_track_info()
      end
   end
end

--- Create a new jammin'! widget. Accepts a table of arguments as optional
-- parameters which override the hardcoded defaults.
--
-- Formatting strings use Pango markup syntax, but with the added ability
-- to insert data about the current track using key-based patterns of the
-- format "${track.key}". For example, if a track by Aphex Twin is playing,
-- the formatting string
--   ``Now playing: ${track.artist}...''
-- will be formatted as
--   ``Now playing: Aphex Twin''
--
-- @param track_fmt   Formatting string for the track display.
-- @param tooltip_fmt Formatting string for the widget tooltip.
-- @param animation   A jammin.animation to draw in the playbox.
function jammin.new(args)
   args = args or {}
   local self = setmetatable({}, jammin)

   self.track_fmt = args.track_fmt or track_fmt
   self.tooltip_fmt = args.tooltip_fmt or tooltip_fmt
   self.play_anim = args.animation or animation()

   self.track = nil

   self.menu = make_menu()
   self.music_box = wibox.widget.textbox()

   local w = wibox.layout.fixed.horizontal(self.play_anim.wibox, self.music_box)

   self.tooltip = awful.tooltip{objects = {w}, delay_show = 1}

   self:handle_playback("Stopped")
   self:set_track_info()

   -- Hook into DBus signals
   dbus.add_match("session", "interface='org.freedesktop.DBus.Properties'")
   dbus.connect_signal("org.freedesktop.DBus.Properties", function(...) self:on_signal(...) end)

   w:buttons(awful.util.table.join(
                awful.button({ }, 1, jammin.playpause ),
                awful.button({ }, 2, jammin.mute),
                awful.button({ }, 3, function() self.menu:toggle() end ),
                awful.button({ }, 4, jammin.vol_up ),
                awful.button({ }, 5, jammin.vol_down )
   ))

   return w
end

setmetatable(jammin, {
                __call = function(cls, ...)
                   return cls.new(...)
                end
})

return jammin
