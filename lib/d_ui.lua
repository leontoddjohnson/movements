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

d_input = include 'lib/d_input'

d_ui.pages = {'input', 'blank'}

d_ui.glyphs = {
  input = "'.•",
  blank = "--"
}

-- these map to named parameter indices
-- might add more (3 and 4) with shift
d_ui.params = {
  input = {'a', 'b'},
  blank = {'c', 'd'}
}

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

------------------- INPUT PAGE -------------------

function d_ui.input_redraw()
  local p = nil

  -- baseline
  screen.move(14, 20)
  screen.line(114, 20)

  -- voice position (above or below line)
  for i=1,4 do
    p = d_input.positions[i]
    p = util.linlin(0, params:get('input_loop_length'), 14, 114, p)

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


------------------- BLANK PAGE -------------------

function d_ui.blank_redraw()
  screen.move(64, 32)
  screen.text_center('blank!')
  screen.stroke()
end


return d_ui