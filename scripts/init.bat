rem Copyright (c) 2019 Jason Baker
rem AUTHORS: Jason Baker (jason.baker0@gmail.com)
rem All code copyright by the authors listed in the respective source files
rem and licenced under GPLv3 and higher.  See doc/COPYING for details.
rem
rem Note that everything lives under the steam drive letter, this choice
rem is intentional, and is meant to prevent errors from people like the 
rem primary author who don't do Windows.
rem
rem NOTE: this batch file isn't wired up or tested yet, see ..\mod.lua:data().
self=urbanspreadsheets_webdash_1

deltree \tmp\tf-dash
mkdir \tmp\tf-dash
copy mods\%self%\www\*.* \tmp\tf-dash\
copy NUL \tmp\tf-dash\stop-log.txt
