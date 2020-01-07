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

local jdbus = require("jammin.dbus")

local jammin = {
   master_volume_widget = nil
}
jammin.__index = jammin

local function show_master_volume_widget()
   if jammin.master_volume_widget ~= nil then
      jammin.master_volume_widget:show{coords={x=10, y=20}}
   end
end

--- Media controls
function jammin.playpause(player)
   jdbus.send({cmd = "PlayPause", player = player})
end

function jammin.next(player)
   jdbus.send({cmd = "Next", player = player})
end

function jammin.previous(player)
   jdbus.send({cmd = "Previous", player = player})
end

function jammin.vol_set(n)
   awful.spawn("amixer -q -M set Master " .. n .. "%")
end

function jammin.vol_up()
   awful.spawn("amixer -q -M set Master 5%+")
   -- show_master_volume_widget()
end

function jammin.vol_down()
   awful.spawn("amixer -q -M set Master 5%-")
   -- show_master_volume_widget()
end

function jammin.mute()
   awful.spawn("amixer -q -M set Master playback toggle")
   -- show_master_volume_widget()
end

-- Factory for a default async volume polling function
local function default_async_volume_factory(slider)
   local function slider_refresh_callback(out, err, _, status)
      if status ~= 0 then
         print("\nError " .. status .. " from jammin' volume polling:")
         print(err)
         return
      end

      local vol_pct = out:match("Mono.+%[(%d+)%%%]")
      if vol_pct then
         slider.value = tonumber(vol_pct)
      end
   end

   return function()
      awful.spawn.easy_async("amixer -M get Master", slider_refresh_callback)
   end
end

--- Construct a volumebar widget for this jammin' instance
function jammin.volumebar(args)
   args = args or {}
   local widget = args.widget

   local theme = {
      width = args.width or 20,
      height = args.height or 220,
      border_color = args.border_color or beautiful.menu_border_color,
      border_width = args.border_width or beautiful.menu_border_width,
      bg_normal = args.background_color or beautiful.menu_bg_normal
   }

   local slider = wibox.widget {
      bar_shape = args.bar_shape or shape.rounded_bar,
      bar_height = args.bar_height or 2,
      bar_color = args.bar_color or beautiful.fg_focus,
      handle_color = args.handle_color or "[0]#000000",
      handle_shape = args.handle_shape or function(cr, w, h)
         return shape.transform(shape.partially_rounded_rect)
            : scale(0.9, 0.9) (cr, h, h, true, false, true, true, theme.width)
                                          end,
      handle_border_color = args.handle_border_color or beautiful.fg_focus,
      handle_border_width = args.handle_border_width or 2,
      handle_width = args.handle_width or theme.width,
      handle_margins = args.handle_margins or {left=1, top=2},
      bar_margins = args.bar_margins or {left=7, right=10, top=theme.width/2 - 1},
      value = 100,
      widget = wibox.widget.slider
   }

   local slider_handler = args.slider_handler or jammin.vol_set
   slider:connect_signal("widget::redraw_needed",
                         function() slider_handler(slider.value) end)

   local async_volume_poll_fn = (args.async_volume_factory or default_async_volume_factory)(slider)
   widget:connect_signal("mouse::enter", async_volume_poll_fn)

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

   return nifty.popup_widget(
      w,
      {
         theme = theme,
         timeout = args.popup_timeout or 3
      }
   )
end

function jammin:async_update(player)
   jdbus.poll_async(player, function(p) self:on_propchange(p, nil) end)
end

--- (List | atom) -> (List)
local function normalize_list(value)
   if type(value) == 'table' then
      return value
   elseif value ~= nil then
      return {value}
   end
end

--- (ISO 8601 datetime) -> ({year, month, day})
local function normalize_date(value)
   local y, m, d = (value or ""):match("^(%d*)-(%d*)-(%d*)T")
   return {year = y, month = m, day = d}
end

--- Handler function for Metadata change signals
-- Updates the musicbox to reflect the new track
function jammin:handle_trackchange(metadata)
   local nfields = 0
   for _ in pairs(metadata) do
      nfields = nfields + 1
   end
   if nfields == 0 then
      -- Empty metadata indicates that the music player has been closed
      self:playback_handler("Closed")
   else
      -- Normalize the track data
      local track = {
         length_us = metadata["mpris:length"],
         art_url = metadata["mpris:artUrl"],
         album = metadata["xesam:album"],
         album_artists = normalize_list(metadata["xesam:albumArtist"]),
         artists = normalize_list(metadata["xesam:artist"]),
         as_text = metadata["xesam:asText"],
         bpm = metadata["xesam:audioBPM"],
         auto_rating = metadata["xesam:autoRating"],
         comments = normalize_list(metadata["xesam:comment"]),
         created = normalize_date(metadata["xesam:contentCreated"]),
         disc_number = metadata["xesam:discNumber"],
         first_played = normalize_date(metadata["xesam:firstUsed"]),
         genres = normalize_list(metadata["xesam:genre"]),
         last_played = normalize_date(metadata["xesam:lastUsed"]),
         lyricists = normalize_list(metadata["xesam:lyricist"]),
         title = metadata["xesam:title"],
         track_number = metadata["xesam:trackNumber"],
         url = metadata["xesam:url"],
         play_count = metadata["xesam:useCount"],
         user_rating = metadata["xesam:userRating"]
      }
      self:track_handler(track)
   end
end


-- XXX should this be removed?
-- --- Add a handler for DBus notifications through naughty for a given appname.
-- -- The default handler function assumes the notification title and text are the
-- -- track title and album respectively. The caller can override this by passing
-- -- their own handler function, which is set as the notification callback.
-- function jammin:add_notify_handler(appname, handler)
--    handler = handler or
--       function(_, _, _, icon, title, text, _, hints, _)
--          local i
--          if icon ~= "" then
--             i = icon
--          elseif hints.icon_data or hints.image_data then
--             -- TODO
--          end
--          self:on_notify(title, nil, text, i)
--          return false
--       end
--    local preset = naughty.config.presets[appname] or {}
--    preset.callback = handler
--    table.insert(naughty.dbus.config.mapping, {{appname=appname}, preset})
-- end

-- --- Handler for notification data. This should be called by notify handlers.
-- function jammin:on_notify(title, artist, album, icon)
--    if not self.track then
--       self.track = {}
--    end
--    self.track.title = self.track.title or title
--    self.track.artist = self.track.artist or artist
--    self.track.icon = self.track.icon or icon

--    self:refresh()
-- end

-- local pretty = require("pl.pretty")
--- Handler for PropertyChanged signals on org.freedesktop.DBus.Properties
function jammin:on_propchange(changed, invalidated)
   -- print("DEBUG: jammin:on_propchange")
   -- print("changed:")
   -- pretty.dump(changed)
   -- print("invalidated:")
   -- pretty.dump(invalidated)
   -- print("\n")
   if changed.PlaybackStatus then
      -- Track play/pause/stop signal
      self:playback_handler(changed.PlaybackStatus)
   end
   if changed.Metadata then
      -- Track change signal
      self:handle_trackchange(changed.Metadata)
   end
end

--- Factory for a default handler for playback status changes, if none is specified
local function default_playback_handler(self, status)
   -- Just do nothing by default
end

--- A default handler for track changes, if none is specified
local function default_track_handler(self, data)
   local artist = table.concat(data.artists, ', ')
   self.widget:set_markup(
      string.format("%s - %s",
                    data.title,
                    artist
      )
   )

   self.tooltip:set_markup(
      string.format("%s - %s\n" ..
                       "on %s (%s)",
                    data.title, artist,
                    data.album, data.created.year
      )
   )
end

--- Create a new jammin'! widget. Accepts a table of arguments as optional
-- parameters which override the hardcoded defaults.
--
-- @param playback_handler Handler function for playback status changes
-- @param track_handler    Handler function for track status changes
-- @param tooltip_preset   Table to be passed to `awful.tooltip`
function jammin.new(args)
   local self = setmetatable({}, jammin)
   args = args or {}

   self.widget = wibox.widget.textbox("")

   self.playback_handler = args.playback_handler or default_playback_handler
   self.track_handler = args.track_handler or default_track_handler
   self.tooltip = awful.tooltip(args.tooltip_preset or {})
   self.tooltip:add_to_object(self.widget)

   self:playback_handler("Stopped")
   self:async_update()

   -- Hook into DBus signals
   jdbus.add_property_listener(function(...) self:on_propchange(...) end)

   return self
end

setmetatable(jammin, {
                __call = function(cls, ...)
                   return cls.new(...)
                end
})

return jammin
