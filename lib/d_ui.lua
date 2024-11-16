-- user interface
-- i.e., redraw, key, and enc for each page

-- each page should be paired with a grid page
-- "shift" on grid associated with K1
-- E1 changes page
-- each page only uses E/K 2 and 3

-- not sure about this yet ...:
-- grid page change --> affect display page
-- display page change --> NO grid page change

local d_ui = {}

local UI = require "ui"

d_dots = include 'lib/d_dots'
d_sample = include 'lib/d_sample'

-- not to overwrite instance loaded in dots.lua or d_sample
-- d_timber = include 'lib/d_timber'

-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

function d_ui.init()
  display = {}
  display[1] = UI.Pages.new(1, 3)  -- sample
  display[2] = UI.Pages.new(2, 1)  -- rec
  display[3] = UI.Pages.new(3, 1)  -- dots

  -- display info in order
  display_names = {'sample', 'rec', 'dots'}
end

-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

-- main navigation bar
function d_ui.draw_nav(header)
  y = 5  -- default text hight
  glyph_buffer = 2

  for i = 1,#display_names do
    x = (i - 1) * glyph_buffer
    screen.move(x, y)
    screen.level(i == DISPLAY_ID and 15 or 2)
    screen.text("|")
  end

  -- current display header
  screen.move_rel(glyph_buffer * 2, 0)
  screen.text(header)
  screen.stroke()
end

-----------------------------------------------------------------
-- SAMPLE
-----------------------------------------------------------------

-- 0: OVERVIEW --------------------------------------------------
-- TODO: build this, connect with K1

-- 1: TRACK -----------------------------------------------

function d_ui.sample_1_redraw()
  local folder = bank_folders[BANK]

  bank_text = "send midi or K2"
  bank_text = folder ~= nil and folder or bank_text

  d_ui.draw_nav(
      TRACK .. " • " .. 
      BANK .. " • " .. 
      bank_text)

  screen.move(64, 32)
  screen.text_center('sample!')

  screen.stroke()
end

function d_ui.sample_1_key(n,z)

  if n == 2 and z == 1 then
    d_sample:load_bank(BANK)
  end

end

function d_ui.sample_1_enc(n,d)
  print('sample 1 enc')
end

-- 1: SAMPLE  ------------------------------------------------------
function d_ui.sample_2_redraw()
  d_ui.draw_nav("sample 2")

  waveform_view:update()
  waveform_view:redraw()

  screen.stroke()
end

function d_ui.sample_2_key(n,z)
  waveform_view:key(n, z)
end

function d_ui.sample_2_enc(n,d)
  waveform_view:enc(n, d)
end

-- 3: FILTER AMP --------------------------------------------------
function d_ui.sample_3_redraw()
  d_ui.draw_nav("sample 3")

  screen.aa(1)
  filter_amp_view:redraw()

  screen.stroke()
end

function d_ui.sample_3_key(n,z)
  -- for fine tuning
  if n == 1 then
    if z == 1 then
      d_timber.shift_mode = true
    else
      d_timber.shift_mode = false
    end
  end

  filter_amp_view:key(n, z)
end

function d_ui.sample_3_enc(n,d)
  filter_amp_view:enc(n, d)
end


-----------------------------------------------------------------
-- REC
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
rec_toggle = 0

function d_ui.rec_1_redraw()
  d_ui.draw_nav("rec 1")
  screen.move(64, 32)
  screen.text_center('rec!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('ooooh!')
  end

  screen.stroke()
end

function d_ui.rec_1_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
  end
end

function d_ui.rec_1_enc(n,d)
  print('recording encoder')
end


-----------------------------------------------------------------
-- DOTS
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------

function d_ui.dots_1_redraw()
  screen.aa(0)
  d_ui.draw_nav("dots baby")

  local p = nil
  local baseline_y = 30

  -- baseline
  screen.move(14, baseline_y)
  screen.line(114, baseline_y)

  -- voice position (above or below line)
  for i=1,4 do
    p = d_dots.positions[i]
    p = util.linlin(0, params:get('dots_loop_length'), 14, 114, p)

    screen.move(p, baseline_y)
    lr = i % 2 == 0 and 1 or -1

    if i < 3 then
      screen.line_rel(0, 12 * lr)
    else
      screen.move_rel(0, 6 * lr)
      screen.text('.')
    end
  end

  -- TODO: contrived waveform using amp poll?

  screen.stroke()
end

function d_ui.dots_1_key(n,z)
  if n == 3 and z == 1 then
    if d_dots.moving then
      d_dots:stop()
    else
      d_dots:start()
    end
  end
end

function d_ui.dots_1_enc(n,d)
  print('dots encoder')
end

return d_ui