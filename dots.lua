-- dots
--
-- See docs.

-- norns `require` statements
-- x = require('module')
local MusicUtil = require "musicutil"
local UI = require "ui"
local Formatters = require "formatters"
local BeatClock = require "beatclock"

engine.name = "d_Timber"

-- script components
d_timber = include 'lib/d_timber'
d_ui = include 'lib/d_ui'
d_dots = include 'lib/d_dots'
d_grid = include 'lib/d_grid'
d_sample = include 'lib/d_sample'

-- general constants
REDRAW_FRAMERATE = 30

page_i = 1
page = d_ui.pages[page_i]

-----------------------------------------------------------------
-- TIMBER
-----------------------------------------------------------------


-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()
  -- parameters
  d_sample.build_params()
  d_dots.build_params()

  -- inits
  d_dots.init()
  
  -- redraw clock
  screen_dirty = true
  grid_dirty = true
  clock.run(redraw_clock)
end

-----------------------------------------------------------------
-- UI
-----------------------------------------------------------------

function redraw()
  screen.clear()

  d_ui.draw_nav(page)
  d_ui[page .. '_redraw']()
  d_ui.draw_params(page)

  screen.update()
end

function key(n, z)
  d_ui[page .. '_key'](n,z)
end

function enc(n, d)
  if n == 1 then
    page_i = util.wrap(page_i + d, 1, #d_ui.pages)
    page = d_ui.pages[page_i]
    screen_dirty = true
  end
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      d_grid:grid_redraw()
      grid_dirty = false
    end

  end
end
