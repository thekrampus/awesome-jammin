# 𝓙𝓪𝓶𝓶𝓲𝓷'! -- a dbus-based media widget for [awesome][awesome]

*(If the title doesn't read "Jammin'!" in a jammin' script, you need to fix your Unicode rendering.)*

[//]: # (TODO: put a screencap here)

## what

[awesome][awesome] is pretty neat. I wrote a media widget for use in [my own configuration](/../../../awesome-starman). It's grown pretty dope tho so I forked it into its own repo.

**BE ADVISED!** 𝓙𝓪𝓶𝓶𝓲𝓷'! is compatible with awesome 4, and notibly **NOT** backwards-compatible with awesome 3.5.x or earlier. awesome 4 made a big API change for spawning processes and that breaks things. Also the slider is new to 4.

Fun fact, this was originally called *awesify* and was meant for use specifically with Spotify for Linux. Turns out it's actually just easier to use DBus's generic media tools, so **ostensibly** this should work with anything. I still just use Spotify, so I make no guarantees about compatibility with anything else. *If you want to patch compatibility with other media players, make a pull request!*

some highlights:
* see what's playing
* volume slider on right-click
* sick tooltip
* provides clean interface to media controls
* configurable!
* :fire: HOT like FIRE :fire:

## but how
To install:
* `git clone` somewhere your config can read it, like `~/.config/awesome`
* Add the widget to your wibar:

    ```lua
    -- in your rc.lua:
    local jammin = require("jammin")
    local myjams = jammin()
    -- [...]
    s.mywibox:setup {
        -- [...]
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            myjams, -- or wherever you want it
            mytextclock,
            s.mylayoutbox
        }
    }
    ```
* Add keybindings for media controls:

    ```lua
    -- in your rc.lua:
    local jammin = require("jammin")
    -- [...]
    globalkeys = awful.util.table.join(
        -- [...]
        -- Media controls
        awful.key({ }, "XF86AudioPlay", jammin.playpause,
           {description = "play/pause media", group = "media"}),
        awful.key({ }, "XF86AudioNext", jammin.next,
           {description = "next track", group = "media"}),
        awful.key({ }, "XF86AudioPrev", jammin.previous,
           {description = "previous track", group = "media"}),
        awful.key({ }, "XF86AudioMute", jammin.mute,
           {description = "toggle mute", group = "media"}),
        awful.key({ }, "#123", jammin.vol_up,
           {description = "volume++", group = "media"}),
        awful.key({ }, "#122", jammin.vol_down,
           {description = "volume--", group = "media"})
    )
    ```

[awesome]: http://awesomewm.org/