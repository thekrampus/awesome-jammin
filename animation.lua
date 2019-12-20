--- Jammin'! animations.
-- "Jammimations."
local wibox = require("wibox")
local timer = require("gears.timer")

local animation = {}
animation.__index = animation

--- A few old variants...
-- local frames = {'⣸', '⣴', '⣦', '⣇', '⡏', '⠟', '⠻', '⢹'}; local play_box_period = 0.2; local pause_glyph = '⣿';
local frames = {'⢸', '⣰', '⣤', '⣆', '⡇', '⠏', '⠛', '⠹'}; local period = 0.2; local pause_glyph = '⣿';
-- local frames = {'⠁', '⠂', '⠄', '⡈', '⡐', '⡠', '⣁', '⣂', '⣌', '⣔', '⣥', '⣮', '⣷', '⣿', '⣶', '⣤', '⣀', ' '}; local play_box_period = 0.2; local pause_glyph = '⣿'
-- local frames = {'⣀', '⡠', '⡠', '⠔', '⠔', '⠔', '⠊', '⠊', '⠊', '⠊', '⠉', '⠉', '⠉', '⠉', '⠉', '⠉', '⠑', '⠑', '⠑', '⠑', '⠢', '⠢', '⠢', '⢄', '⢄'}; local play_box_period = 0.03; local pause_glyph = '⣀';
-- local frames = {' ⣸', '⢀⣰', '⣀⣠', '⣄⣀', '⣆⡀', '⣇ ', '⡏ ', '⠏⠁', '⠋⠉', '⠉⠙', '⠈⠹', ' ⢹'}; local play_box_period = 0.16; local pause_glyph = '⣿⣿';
-- local frames = {' ⡱', '⢀⡰', '⢄⡠', '⢆⡀', '⢎ ', '⠎⠁', '⠊⠑', '⠈⠱'};
-- local period = 0.16667;
-- local pause_glyph = '⢾⡷';

local markup_fmt = '<span color="white">%s</span>'

function animation:start()
   self.timer:again()
end

function animation:stop()
   if self.timer.started then
      self.timer:stop()
   end
   self:set_markup(self.pause_glyph)
end

function animation:set_markup(s)
   self.wibox:set_markup(self.markup_fmt:format(s))
end

function animation.new(args)
   args = args or {}
   local self = setmetatable({}, animation)

   self.frames = args.frames or frames
   self.pause_glyph = args.pause_glyph or pause_glyph
   self.markup_fmt = args.markup_fmt or markup_fmt
   local period = args.period or period

   self.wibox = wibox.widget{
      forced_width = args.fixed_width,
      widget = wibox.widget.textbox
   };
   self.index = 1

   local function animate()
      self:set_markup(self.frames[self.index])
      self.index = (self.index % #self.frames) + 1
      return true
   end

   self.timer = timer.start_new(period, animate)
   self:stop()

   return self
end

setmetatable(animation, {
                __call = function(cls, ...)
                   return cls.new(...)
                end
})

return animation
