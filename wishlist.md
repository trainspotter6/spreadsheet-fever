<!-- Copyright (c) 2019 Jason Baker jason.baker0@gmail.com 
     All source files copyright their respective authors.
     See COPYING for details -->

1. Make sure all cargo columns in Rail Lines have the same width,
   which is the minimum width of the widest cargo column.  Maybe this
   can be done in Javascript, certainly not css.

1. Get more than one corner of the splash screen image to display and
   randomize splash screen images.

1. Treat airplanes/air routes similarly to trains, maybe in a seperate
   html file.

1. More config options such as the ability to turn off some table
   generation, and the ability to split the rail table into multiple
   columns (side by side tables).  Also, the ability to split any
   table by one or more pivots.  "P" is a good pivot for my rail
   table, because it splits cargo and passenger lines into separate
   html tables.  It would be nice to have a pivot that splits the
   Waiting Cargo table into cargo and passanger parts.

1. Matrix of city needs (ie, transport, commercial, and industrial).
   Maybe this goes in a second or third page?

1. Set up 2d nearest neighbor search on towns and factories so that we
   can report the distance and direction of a train from the nearest
   landmark.

1. Rethink the way we handle in game dates/times more generally.  (We
   conflate overall calendar date with train travel time.  With the
   default settings, this is only an issue in Sprint 1968 when the
   vehicle day rolls over to midnight.  `script.lua:checkHealth()` deals
   with this case in a hacky way.)

1. Set up a REPL using two named pipes.

1. Can javascript access local files?  If so, one could go nuts with
   ajax over named pipes.

1. Something for bus and tram lines.  Given that we can't tell which
   line/direction passengers are waiting for at stations and stop
   pairs, I don't know what this would look like.
