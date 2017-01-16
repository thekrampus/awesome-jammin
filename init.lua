----------------------------------------------------------------
--- Jammin'! A dbus-based media widget for awesome
--
-- @author Krampus &lt;tetramor.ph&gt;
-- @module jammin
----------------------------------------------------------------

local naughty = require("naughty")
local res, nifty = pcall(require, "nifty")
if not res then
   local err_msg = "If you want to be jammin' you gotta get nifty!\n" ..
      "https://github.com/thekrampus/awesome-nifty"
   print("Error from jammin/init.lua: " .. err_msg)
   naughty.notify{preset=naughty.config.presets.critical,
                  title="Jammin' error!",
                  text=err_msg}
   return {}
end


local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local shape = require("gears.shape")

local animation = require("jammin.animation")
local dbus = require("jammin.dbus")

local jammin = {}
jammin.__index = jammin

local track_fmt = ' ${track.title} <span color="white">${track.artist}</span> '
local tooltip_fmt = '   ${track.title}\n' ..
   '<span color="white">by</span> ${track.artist}\n' ..
   '<span color="white">on</span> ${track.album}\n' ..
   '   <span color="green">${track.year}</span>'

function jammin.playpause(player)
   dbus.send({cmd = "PlayPause", player = player})
end

function jammin.next(player)
   dbus.send({cmd = "Next", player = player})
end

function jammin.previous(player)
   dbus.send({cmd = "Previous", player = player})
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

   local function handle_shape(cr, w, h)
      return shape.transform(shape.partially_rounded_rect)
         : scale(0.9, 0.9) (cr, h, h, true, false, true, true, theme.width)
   end

   local slider = wibox.widget {
      bar_shape = shape.rounded_bar,
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

   return nifty.popup_widget(w, {theme = theme, timeout = 3})
end

--- Update the widget's markup and tooltip with the current track info
function jammin:refresh()
   if self.track then
      self.music_box:set_markup(nifty.util.format(self.track_fmt, self.track, 'track'))
      self.tooltip:set_markup(nifty.util.format(self.tooltip_fmt, self.track, 'track'))
   else
      self.music_box:set_text("⣹")
      self.tooltip:set_markup("... nothing's playing...")
   end
   collectgarbage()
end

function jammin:async_update(player)
   dbus.poll_async(player, function(p) self:on_propchange(p, nil) end)
end

--- Handler function for PlaybackStatus change signals
-- Updates the play animation to reflect the playback status
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
      -- Parse the data to store
      local artist_list = metadata["xesam:artist"]
      local date = metadata["xesam:contentCreated"] or ""
      local year, month, day = date:match("^(%d*)-(%d*)-(%d*)T")
      self.track = {
         title = metadata["xesam:title"],
         album = metadata["xesam:album"],
         disc_number = metadata["xesam:discNumber"],
         track_number = metadata["xesam:trackNumber"],
         url = metadata["xesam:url"],
         art_url = metadata["mpris:artUrl"],
         length_us = metadata["mpris:length"],
         artist = artist_list and table.concat(artist_list, ", "),
         year = year or "----",
         month = month,
         day = day
      }
   end
end

--- Add a handler for DBus notifications through naughty for a given appname.
-- The default handler function assumes the notification title and text are the
-- track title and album respectively. The caller can override this by passing
-- their own handler function, which is set as the notification callback.
function jammin:add_notify_handler(appname, handler)
   handler = handler or
      function(_, _, _, icon, title, text, _, hints, _)
         local i
         if icon ~= "" then
            i = icon
         elseif hints.icon_data or hints.image_data then
            -- TODO
         end
         self:on_notify(title, nil, text, i)
         return false
      end
   local preset = naughty.config.presets[appname] or {}
   preset.callback = handler
   table.insert(naughty.dbus.config.mapping, {{appname=appname}, preset})
end

--- Handler for notification data. This should be called by notify handlers.
function jammin:on_notify(title, artist, album, icon)
   if not self.track then
      self.track = {}
   end
   self.track.title = self.track.title or title
   self.track.artist = self.track.artist or artist
   self.track.icon = self.track.icon or icon

   self:refresh()
end

--- Handler for PropertyChanged signals on org.freedesktop.DBus.Properties
function jammin:on_propchange(changed, invalidated)
   if changed.PlaybackStatus then
      -- Track play/pause/stop signal
      self:handle_playback(changed.PlaybackStatus)
   end
   if changed.Metadata then
      -- Track change signal
      self:handle_trackchange(changed.Metadata)
   end
   self:refresh()
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

   self.wibox = wibox.layout.fixed.horizontal(self.play_anim.wibox, self.music_box)

   self.tooltip = awful.tooltip{objects = {self.wibox}, delay_show = 1}

   self:handle_playback("Stopped")
   self:refresh()
   self:async_update()

   -- Hook into DBus signals
   dbus.add_property_listener(function(...) self:on_propchange(...) end)

   self.wibox:buttons(awful.util.table.join(
                         awful.button({ }, 1, jammin.playpause ),
                         awful.button({ }, 2, jammin.mute),
                         awful.button({ }, 3, function() self.menu:toggle() end ),
                         awful.button({ }, 4, jammin.vol_up ),
                         awful.button({ }, 5, jammin.vol_down )
                                           )
   )

   return self
end

setmetatable(jammin, {
                __call = function(cls, ...)
                   return cls.new(...)
                end
})

return jammin
