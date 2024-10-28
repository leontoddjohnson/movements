-- user interface
-- i.e., redraw, key, and enc for each page

-- each page should be paired with a grid page
-- "shift" on grid associated with K1
-- E1 changes page
-- each page only uses E/K 2 and 3

-- not sure about this yet ...:
-- grid page change --> affect display page
-- display page change --> NO grid page change

local ui = {}

ui.pages = {'input', 'blank'}

ui.glyphs = {
  input = "'.•",
  blank = "--"
}

-- these map to named parameter indices
-- might add more (3 and 4) with shift
ui.params = {
  input = {'a', 'b'},
  blank = {'c', 'd'}
}

-- main navigation bar
function ui.draw_nav(page)
  nav_buffer = 10
  nav_y = 6
  n = 2
  nav_bar_len = 128 - (2 + n - 1) * nav_buffer
  nav_bar_len = nav_bar_len / n

  -- TODO: fix call to glyphs ...
  for i = 1,#ui.pages do
    x = nav_buffer + (i - 1) * (nav_bar_len + nav_buffer)
    screen.move(x, nav_y)
    screen.level(ui.pages[i] == page and 15 or 5)
    screen.line(x + nav_bar_len, nav_y)
    screen.move(x + nav_bar_len / 2, nav_y - 2)
    screen.text_center(ui.glyphs[page])
    screen.stroke()
  end
end


-- parameters to adjust with K2 and K3
function ui.draw_params(page)
  screen.move(10, 62)
  screen.text(ui.params[page][1])
  screen.move(118, 62)
  screen.text_right(ui.params[page][2])
end

------------------- INPUT PAGE -------------------

function ui.input_redraw()
  -- baseline
  screen.move(14, 20)
  screen.line(114, 20)

  -- voice position (above or below line)
  for i=1,4 do
    lr = i % 2 == 0 and 1 or -1
    screen.move(14 + position_to_pixels(i), 20)
    if i < 3 then
      screen.line_rel(0, 12 * lr)
    else
      screen.line_rel(0, 6 * lr * (i == 3 and 1.2 or 1))
    end
  end

  -- contrived waveform using amp poll?

  screen.stroke()
end


------------------- BLANK PAGE -------------------

function ui.blank_redraw()
  screen.move(64, 32)
  screen.text_center('blank!')
  screen.stroke()
end


return ui