// Copyright (c) 2019 Jason Baker jason.baker0@gmail.com
// AUTHORS: Jason Baker (jason.baker0@gmail.com)
// All code copyright by the authors listed in the respective source files
// and licenced under GPLv3 and higher.	 See LICENSE for details.
// 
// Automatically reloads this window when we expect a new version of 
// tf-dash.html to appear.
//
// We know that the file is generated each time the time of day rolls
// over to a new second, and we know the fps in the second leading up
// to this version of the file.  From this, we can estimate when the
// new file version is ready.  If the drop from 60fps is entirely
// caused by genFile(), we can expect a new file (60 - fps)/60 of the
// way into the next second.  This should be plenty conservative.
//
// We further constrain the offset into the next second to be between
// 75 and 750ms just to keep things sane
{
    let reload = true;
    let offset = Math.min(750, Math.max(75, (60 - tfdash.fps) * 1000 / 60));
    let now  = new Date().getTime();
    let target = 1000 * Math.floor(now/1000) + 1000 + offset;
    window.setTimeout(function() { if (reload) location.reload(); },
		      target - now);

    tfdash.cancelReload = function() {
	reload = false;
	document.getElementById("menu").innerHTML =
	    "<a href='javascript:location.reload()'>start reloading</a>";
    }

    let addButton = function() {
	document.getElementById("menu").innerHTML =
	    "<a href='javascript:tfdash.cancelReload()'>stop reloading</a>";
    }

    if (document.readyState == "loading")
	document.addEventListener("DOMContentLoaded", addButton);
    else
	addButton();
}
