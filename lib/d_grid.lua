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
  bank_sample_loaded = 2,
  bank_sample_selected = 15,
  bank_sample_tracked = 5,
  bank_sample_playing = 10,
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
  bar_populated = 5,
  track_playing = 10,
  track_stopped = 0,
  time_beats = 10,
  time_seconds = 2,
  clock_frac_selected = 7,
  clock_frac_deselected = 0,
  clock_frac_fours = 3
}

g_pages = {
  'sample_seq', 'sample_time', 'sample_config', 'sample_levels',
  'rec_config', 'rec_levels'
}

G_PAGE = 'sample_config'
PLAY_MODE = false
ALT = false

-- keys held [y][x] or [row][col]
-- 1 == held and 0 == not held
KEY_HOLD = {}

SEQ_BAR = 1  -- current sequence bar
TRACK = 1    -- selected (sample) track
BUFFER = 1   -- recording buffer selected (1 -> L, 2 -> R)

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_grid.init()
  -- key_hold map
  for r = 1,8 do
    KEY_HOLD[r] = {}
    for c = 1,16 do
      KEY_HOLD[r][c] = 0
    end
  end
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
function d_grid.sample_time_redraw()

  for t = 1,7 do
    -- play/stop column
    if transport[t] then
      g:led(1, t, g_brightness.track_playing)
    else
      g:led(1, t, g_brightness.track_stopped)
    end

    -- beat/sec column
    if time_type[t] == 'beats' then
      g:led(2, t, g_brightness.time_beats)
    else
      g:led(2, t, g_brightness.time_seconds)
    end

    -- time rows
    local frac = 1
    for c = 4,16 do
      frac = c - 3
      -- in selected range
      if clock_range[t][1] <= frac and frac <= clock_range[t][2] then
        g:led(c, t, g_brightness.clock_frac_selected)
      -- indicate 1/8, 1/4, 1, and 4
      elseif frac == 1 or frac == 5 or frac == 8 or frac == 11 then
        g:led(c, t, g_brightness.clock_frac_fours)
      else
        g:led(c, t, g_brightness.clock_frac_deselected)
      end
    end
  end

end

function d_grid.sample_time_key(x, y, z)
  
  if y < 8 then
    -- play/stop
    if x == 1 and z == 1 then
      if transport[y] then
        d_seq.stop_transport(y)
      else
        d_seq.start_transport(y)
      end
    end

    -- beats or seconds
    if x == 2 and z == 1 then
      if time_type[y] == 'beats' then
        time_type[y] = 'seconds'
      else
        time_type[y] = 'beats'
      end
    end

    -- clock fraction range
    if x > 3 then
      if z == 1 then
        KEY_HOLD[y][x] = 1
        hold_span = span(KEY_HOLD[y])
        clock_range[y][1] = hold_span[1] - 3
        clock_range[y][2] = hold_span[2] - 3
      else
        KEY_HOLD[y][x] = 0
      end
    end
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
        if sample_status[sample_id_] == 1 then
          g:led(x, y, g_brightness.bank_sample_playing)
        elseif sample_track[bank][row][col] == TRACK then
          g:led(x, y, g_brightness.bank_sample_tracked)
        else
          g:led(x, y, g_brightness.bank_sample_loaded)
        end
      else
        g:led(x, y, g_brightness.bank_sample_empty)
      end

      -- temporarily brighten selected sample
      if KEY_HOLD[y][x] == 1 and 8 < x and y < 5 then
        g:led(x, y, g_brightness.bank_sample_selected)
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
    row_ = y
    col_ = x - 8
    sample_id = rowcol_id(row_ .. col_, BANK)
    
    if z == 1 then
      KEY_HOLD[y][x] = 1

      d_sample.set_sample_id(sample_id)
      
      if PLAY_MODE then
        if sample_status[sample_id] == 1 then
          d_sample.note_off(sample_id)
        else
          d_sample.note_on(sample_id, 1)
        end
      end

    else
      
      if PLAY_MODE and sample_status[sample_id] > 0 and play_mode_is_hold(sample_id) then
        d_sample.note_off(sample_id)
      end
      
      KEY_HOLD[y][x] = 0
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

-- for a "2-dimensional" table (array), get the "column" values
-- `t` is the table, and `col` is the column index.
function array_column(t, col)
  local c = {}
  for i=1,#t do
    table.insert(c, t[i][col])
  end
  return c
end

return d_grid