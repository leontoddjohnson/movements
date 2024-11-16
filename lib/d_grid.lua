-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local d_grid = {}

local g_map = {
  sample_seq = {},
  sample_time = {},
  sample_config = {},
  sample_levels = {},
  rec_config = {},
  rec_levels = {}
}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  bank_sample_empty = 0,
  bank_sample_loaded = 3,
  bank_sample_selected = 8,
  bank_sample_playing = 15,
  bank_empty = 2,
  bank_loaded = 4,
  bank_selected = 8,
  nav_page_inactive = 2,
  nav_page_active = 5,
  mode_focus = 0,
  mode_play = 10,
  alt_off = 0,
  alt_on = 15,
  step_active = 12,
  step_inactive = 3,
  step_empty = 0,
  bar_active = 12,
  bar_empty = 0,
  bar_populated = 5
}

g_pages = {
  'sample_seq', 'sample_time', 'sample_config', 'sample_levels',
  'rec_config', 'rec_levels'
}

G_PAGE = 'sample_config'
PLAY_MODE = false
ALT = false

SEQ_BAR = 1

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_grid.init()
  -- -- sample.config sections
  -- g_map.sample.config = {
  --   origin = 
  -- }
end


-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

function d_grid.draw_nav()
  local origin = {9, 8}
  
  -- pages
  for i = 1, #g_pages do
    x, y = global_xy(origin, i, 1)

    if G_PAGE == g_pages[i] then
      g:led(x, y, g_brightness.nav_page_active)
    else
      g:led(x, y, g_brightness.nav_page_inactive)
    end
  end

  -- mode
  if PLAY_MODE then
    g:led(15, 8, g_brightness.mode_play)
  else
    g:led(15, 8, g_brightness.mode_focus)
  end

  -- alt
  if ALT then
    g:led(16, 8, g_brightness.alt_on)
  else
    g:led(16, 8, g_brightness.alt_off)
  end

end

function d_grid.nav_key(x, y, z)

  -- page selection
  if 9 <= x and x < 15 and y == 8 then
    if z == 1 then
      G_PAGE = g_pages[x - 8]
    end
  
  -- mode
  elseif x == 15 and y == 8 then
    if z == 1 then
      PLAY_MODE = not PLAY_MODE
    end
  
  -- alt
  elseif x == 16 and y == 8 then
    if z == 1 then
      ALT = true
    else
      ALT = false
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE SEQ 
-----------------------------------------------------------------

function d_grid.sample_seq_redraw()

  -- draw steps
  for track = 1,7 do
    for s = 1,16 do
      step_ = (SEQ_BAR - 1) * 16 + s
      
      if step_ == step[track] then
        g:led(s, track, g_brightness.step_active)
      elseif pattern[track][bank[track]][step_] > 0 then
        g:led(s, track, g_brightness.step_inactive)
      else
        g:led(s, track, g_brightness.step_empty)
      end
    end
  end

  -- draw sequence bars
  draw_sequence_bars(1, 8, {1, 7})

end

function d_grid.sample_seq_key(x, y, z)
  step_ = (SEQ_BAR - 1) * 16 + x

  -- switch between a step that exists (1) or not (0)
  if y < 8 and z == 1 then
    empty_step_ = pattern[y][bank[y]][step_] == 0
    pattern[y][bank[y]][step_] = empty_step_ and 1 or 0
  end
  
  if y == 8 and x < 9 then
    SEQ_BAR = x
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE TIME
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.sample_time_redraw()

  for x = 1,16 do
    g:led(x, 2, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.sample_time_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE CONFIG 
-----------------------------------------------------------------

function d_grid.draw_bank(bank)
  local origin = {9, 1}

  -- draw bank samples
  for row = 1,4 do
    for col = 1,8 do
      x, y = global_xy(origin, col, row)
      sample_id_ = banks[bank][row][col]
      if sample_id_ then
        if sample_id_ == SAMPLE then
          g:led(x, y, g_brightness.bank_sample_selected)
        elseif sample_status[sample_id_] == 1 then
          g:led(x, y, g_brightness.bank_sample_playing)
        else
          g:led(x, y, g_brightness.bank_sample_loaded)
        end
      else
        g:led(x, y, g_brightness.bank_sample_empty)
      end
    end
  end

  -- draw bank indicators
  origin = {13, 5}
  for bank_ = 1,4 do
    x, y = global_xy(origin, bank_, 1)
    if bank_folders[bank_] then
      g:led(x, y, g_brightness.bank_loaded)
    elseif BANK == bank_ then
      g:led(x, y, g_brightness.bank_selected)
    else
      g:led(x, y, g_brightness.bank_empty)
    end
  end

end

function d_grid.sample_config_redraw()
  d_grid.draw_bank(BANK)
end

function d_grid.sample_config_key(x, y, z)

  -- bank selection
  if 12 < x and y == 5 then
    if z == 1 then
      origin = {13, 5}
      BANK, _ = rel_xy(origin, x, y)
    end
  end

  -- sample selection
  if 8 < x and y < 5 then
    if z == 1 then
      row_ = y
      col_ = x - 8
      sample_id = rowcol_id(row_ .. col_, BANK)

      d_sample.set_sample_id(sample_id)

      if sample_status[sample_id] == 1 then
        d_sample.note_off(sample_id)
      else
        d_sample.note_on(sample_id, 1)
      end
      
    end
  end

  grid_dirty = true
  screen_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE LEVELS
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.sample_levels_redraw()

  for x = 1,16 do
    g:led(x, 4, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.sample_levels_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REC CONFIG
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_config_redraw()

  for x = 1,16 do
    g:led(x, 5, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_config_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REC LEVELS
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_levels_redraw()

  for x = 1,16 do
    g:led(x, 6, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_levels_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REDRAW
-----------------------------------------------------------------

function d_grid:grid_redraw()
  g:all(0)
  d_grid[G_PAGE .. '_redraw']()
  d_grid.draw_nav()
  g:refresh()
end


function g.key(x, y, z)

  if x > 8 and y == 8 then
    d_grid.nav_key(x, y, z)
  else
    d_grid[G_PAGE .. '_key'](x, y, z)
  end

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- "global" grid x and y from *relative* x and y from origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function global_xy(origin, x_rel, y_rel)
  x = origin[1] - 1 + x_rel
  y = origin[2] - 1 + y_rel
  return x, y
end 

-- "relative" grid x and y from *global* x and y given origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function rel_xy(origin, x_global, y_global)
  x = x_global - origin[1] + 1
  y = y_global - origin[2] + 1
  return x, y
end

-- draw 8 sequence bars starting at y starting at x_start on grid
-- only consider the tracks from track_range[1] to track_range[2]
function draw_sequence_bars(x_start, y, track_range)
  local last_bar = 1
  local track_last_bar = 1

  for t = track_range[1],track_range[2] do
    track_last_bar = n_bars(t)
    last_bar = track_last_bar > last_bar and track_last_bar or last_bar
  end

  for bar = 1,8 do
    if bar <= last_bar then
      g:led(x_start - 1 + bar, y, g_brightness.bar_populated)
    else
      g:led(x_start - 1 + bar, y, g_brightness.bar_empty)
    end

    if SEQ_BAR == bar then
      g:led(x_start - 1 + bar, y, g_brightness.bar_active)
    end
  end
end

return d_grid