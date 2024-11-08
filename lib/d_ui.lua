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

d_dots = include 'lib/d_dots'

d_ui.pages = {'dots', 'rec'}

d_ui.glyphs = {
  dots = "'.•",
  rec = "--"
}

-- sample pages: --, ->, #, l.|
-- rec pages: --, -> ??? maybe?? 

-- these map to named parameter indices
-- might add more (3 and 4) with shift
d_ui.params = {
  dots = {'a', 'b'},
  rec = {'c', 'd'}
}

--------------------------------------------------------------------------------
-- NAVIGATION
--------------------------------------------------------------------------------

-- main navigation bar
function d_ui.draw_nav(page)
  nav_buffer = 10
  nav_y = 6
  n = 2
  nav_bar_len = 128 - (2 + n - 1) * nav_buffer
  nav_bar_len = nav_bar_len / n

  for i = 1,#d_ui.pages do
    x = nav_buffer + (i - 1) * (nav_bar_len + nav_buffer)
    screen.move(x, nav_y)
    screen.level(d_ui.pages[i] == page and 15 or 5)
    screen.line(x + nav_bar_len, nav_y)
    screen.move(x + nav_bar_len / 2, nav_y - 2)
    screen.text_center(d_ui.glyphs[d_ui.pages[i]])
    screen.stroke()
  end
end


-- parameters to adjust with K2 and K3
function d_ui.draw_params(page)
  screen.move(10, 62)
  screen.text(d_ui.params[page][1])
  screen.move(118, 62)
  screen.text_right(d_ui.params[page][2])
end


--------------------------------------------------------------------------------
-- DOTS
--------------------------------------------------------------------------------

function d_ui.dots_redraw()
  local p = nil

  -- baseline
  screen.move(14, 20)
  screen.line(114, 20)

  -- voice position (above or below line)
  for i=1,4 do
    p = d_dots.positions[i]
    p = util.linlin(0, params:get('dots_loop_length'), 14, 114, p)

    screen.move(p, 20)
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

function d_ui.dots_key(n,z)
  if n == 3 and z == 1 then
    if d_dots.moving then
      d_dots:stop()
    else
      d_dots:start()
    end
  end
end

--------------------------------------------------------------------------------
-- SAMPLE: LOAD
--------------------------------------------------------------------------------





--------------------------------------------------------------------------------
-- REC: MAIN
--------------------------------------------------------------------------------
rec_toggle = 0

function d_ui.rec_redraw()
  screen.move(64, 32)
  screen.text_center('rec!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('ooooh!')
  end

  screen.stroke()
end

function d_ui.rec_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
  end
  screen_dirty = true
end


return d_ui