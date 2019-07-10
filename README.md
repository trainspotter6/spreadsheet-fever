<!-- Copyright (c) 2019 Jason Baker jason.baker0@gmail.com
     All source files copyright their respective authors.
     See LICENSE for details. -->

# Spreadsheet Fever

Spreadsheet Fever is Transport Fever UI mod that bypasses the game's
internal UI.  We do this mostly for performance, but also to declutter
the game's window.  The mod updates a log of stopped trains on every
frame, and generates an html overview of rail and factory activity
once per second.  Note: this mod uses TF's mission infrastructure, and
therefore can only be used in free-play mode, not campaign mode.

Before this UI, I kept a vehicle overview window opened for every
train, so that I could see when train became blocked, unable to find a
path the the destination in the first place, or otherwise bothered, as
well as to eyeball each line's source factory outputs.  This slowed
the game to a crawl.  With vehicle and ka-ching icons disabled in the
central HUD menu, I was able to get about 4fps running below 1x speed
with 55 train windows opened.  (I had to close half the windows to
avoid severe lag when laying out track while paused.)  After the mod,
with train windows eliminated, I can get around 40fps at a smooth 4x
speed.

I haven't tried to measure the impact of this mod's lua code on the TF
engine, but it feels minimal.  As for the increased CPU load from the
web browser reloading a small page every second, it shouldn't be an
issue.  I've never seen TF fully utilize 2 cores on Linux (it
consistently stays around 1.5), while my 9 year old CPU has 4 cores
and 8 threads.

I like to think of the web page as primitive but functional.  It
doesn't include everything I'd like, but then everything I'd like
isn't available in lua.

## Release Status

Alpha: So far, this mod is confirmed to work on Ubuntu 18.04 with
firefox.  I don't expect problems from other browsers, other UNIX
variants, or MacOS, but I do expect problems with Windows.
`scripts\\init.bat` probably contains errors right now, so Windows
users might want to try this script manually before enabling the
mod in TF.

## Usage

When the game starts, follow the directions in the Observer dialog
box:

<!-- It's gonna be fun keeping this in sync -->
> This dialog box is the only native UI element in Spreadsheet
> Fever. To see the rest, point your browser at
> `file:///tmp/tf-dash/dash.html`, and run `tail -f
> /tmp/tf-dash/stop-log.txt` in a terminal. (In windows, these paths
> are relative to the drive where Steam is installed.

There are a few config options, which you can control by adding a
`.tfdashrc` or `tfdask.rc` file to your home directory based on the
following template (which you can find in `mods/settings.lua` relative
to your TF install path):

<!-- And keeping this in sync -->
``` lua
-- Configuration for Spreadsheet Fever.
function data() {
    return {
       speedUnit = "MPH",	-- MPH, KPH, or mps (meters/sec)
       fontSize = "8pt",	-- compact
       menuFontSize = "7pt",	-- a little more compact
    }
}
```
If you have trouble loading your config in Windows, set `%HOME%` or both
`%HOMEDRIVE%` and `%HOMEPATH%` appropriately.

## Developers

Relative to the TF `mods/urbanspreadsheets_webdash_1` directory, we
have a few interesting files:

* `mod.lua` is responsible for running `scripts/init` or
  `scripts/init.bat` as appropriate to initialize the `/tmp/tf-dash` dir.

* `www/tf-dash.js` and `www/tf-dash.css` contain webpage-enabling garbage.

* `campaign/_auto_/_auto_/script.lua` contains the core logic:
   `makeObserver()` establishes our end-of-frame callback and calls
   `checkHealth()` (to update stop-log.txt) and `genFile()` (to
   overwrite `dash.html`) when appropriate.

I've scribbled my thoughts on where to go from here in wishlist.md.

## Limitations

The Spreadsheet Fever dashboard is very much limited by TF's lua api:

* No view into train "waiting for path"/"unable to find path" status,
  we just complain when a train's speed drops to zero when not at a
  station.

* No breakdown of cargo or people waiting at a station by line or even
  by terminal.

* No way to see the advertised production rate of a factory.  We see
  some stats, but nothing corresponding to the rate shown in in-game
  overview windows.

* Time is weird.  With the default settings, each day of Calendar time
  equals 2 seconds of vehicle time.  We get them both through a single
  function `game.interface.gameTime()` merge both into a single
  number, then disentangle them when generating stop-log messages.

* No way to examine user settings stored in the steam userdata dir
  (eg speedUnit).

* Git access at 
  [github](https://github.com/trainspotter6/spreadsheet-fever.git)

## Endnotes

All source files are copyright by their respective authors, while
images in the `www/` dir are copyright Urban Games.  If you download
this mod without buying Transport Fever, you are pirating icons!
Icons, I tell you!

Spreadsheet Fever code is free software, see `LICENSE` for conditions.
