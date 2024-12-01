-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local d_grid = {}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  bank_sample_empty = 0,
  bank_sample_loaded = 2,
  bank_sample_selected = 15,
  bank_sample_playing = 12,
  bank_sample_tracked = 4,
  bank_sample_current_track = 6,
  bank_sample_cued = 9,
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
  step_inactive = 5,
  step_empty = 0,
  seq_track_selected = 2,
  level_met = 5,
  bar_active = 12,
  bar_empty = 0,
  bar_populated = 5,
  track_selected = 8,
  track_playing = 10,
  track_stopped = 0,
  time_beats = 10,
  time_seconds = 2,
  clock_frac_selected = 7,
  clock_frac_deselected = 0,
  clock_frac_fours = 3,
  param_selected = 5,
  param_deselected = 1
}

-- tables with 1 or 2 page options for each nav key
g_pages = {
  {'sample_seq', 'sample_levels'}, {'sample_time'}, {'sample_config'},
  {'rec_seq', 'rec_levels'}, {'rec_time'}, {'rec_config'},
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
PARAM = 'amp'

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_grid.init()
  -- param options at the bottom of config page.
  -- the last one is only assumed if all are deselected
  p_options.PARAMS = {
    'length', 'pan', 'filter', 'scale', 'rate', 'prob', 'amp'
  }
  
  p_options.PARAMS_MIDI = {
    'length', 'midi_1', 'midi_2', 'scale', 'rate', 'prob', 'vel'
  }

  d_grid.build_param_levels()

  -- key_hold map
  for r = 1,8 do
    KEY_HOLD[r] = {}
    for c = 1,16 do
      KEY_HOLD[r][c] = 0
    end
  end
end

function d_grid.build_param_levels()
  -- parameter level values on the grid (see p_options.PARAMS).
  -- *the "zero" value is the 7th item in the list!*
  param_levels = {}

  -- For amp, ignore peek ... #s are converted to [0, 1].
  -- *Timber Engine needs these converted to db*
  param_levels.amp = {-24, -18, -12, -6, -3, 0}
  for i=1,6 do param_levels.amp[i] = util.dbamp(param_levels.amp[i]) end
  table.insert(param_levels.amp, 0)

  param_levels.length = {1/6, 2/6, 3/6, 4/6, 5/6, 1, 0}
  param_levels.prob = {1/6, 2/6, 3/6, 4/6, 5/6, 1, 0}
  param_levels.pan = {-1, -2/3, -1/3, 1/3, 2/3, 1, 0}

  -- for filter, the "zero" value translates to swapping from HP <--> LP
  -- for LP, highlight up to the value, for HP, highlight above the value
  -- final value: filter > 0 = LP freq and filter < 0 = HP freq
  param_levels.filter = {20, 500, 1000, 2000, 10000, 20000, -1}

  param_levels.scale = {-3, -2, -1, 1, 2, 3, 0}
  param_levels.rate = {-2, -1, -1/2, 1/2, 1, 2, 0}

end


-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

function d_grid.draw_nav()
  local origin = {9, 8}
  
  -- pages
  for i = 1, #g_pages do
    x, y = global_xy(origin, i, 1)

    if tab.contains(g_pages[i], G_PAGE) then
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
      if #g_pages[x - 8] > 1 and tab.contains(g_pages[x - 8], G_PAGE) then
        i = index_of(g_pages[x - 8], G_PAGE)
        i = util.wrap(i + 1, 1, #g_pages[x - 8])
      else
        i = 1
      end
      G_PAGE = g_pages[x - 8][i]
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

  -- draw steps and selected track
  for track = 1,7 do
    for s = 1,16 do
      step_ = (SEQ_BAR - 1) * 16 + s
      
      if step_ == step[track] then
        g:led(s, track, g_brightness.step_active)
      elseif pattern[track][bank[track]][step_] > 0 then
        g:led(s, track, g_brightness.step_inactive)
      elseif track ~= TRACK then
        g:led(s, track, g_brightness.step_empty)
      else
        g:led(s, track, g_brightness.seq_track_selected)
      end
    end
  end

  -- draw sequence bars
  draw_sequence_bars(1, 8, {1, 7})

end

function d_grid.sample_seq_key(x, y, z)

  if y < 8 and z == 1 then
    step_ = (SEQ_BAR - 1) * 16 + x

    if not PLAY_MODE then
      -- select track
      if ALT then
        TRACK = y
      -- activate step
      else
        empty_step_ = pattern[y][bank[y]][step_] == 0
        pattern[y][bank[y]][step_] = empty_step_ and 1 or 0
      end
    else
      -- move all tracks to that step
      if ALT then
        for track_ = 1,7 do
          step[track_] = step_
        end
      -- move just the associated track to that step
      else
        step[y] = step_
      end
    end
  end
  
  if y == 8 and x < 9 then
    SEQ_BAR = x
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE LEVELS
-----------------------------------------------------------------

function d_grid.sample_levels_redraw()

  for s = 1,16 do
    step_ = (SEQ_BAR - 1) * 16 + s
    
    -- draw steps for selected track
    if step_ == step[TRACK] then
      g:led(s, 1, g_brightness.step_active)
    elseif pattern[TRACK][bank[TRACK]][step_] > 0 then
      g:led(s, 1, g_brightness.step_inactive)
    else
      g:led(s, 1, g_brightness.seq_track_selected)
    end

    -- draw levels for selected parameter
    if pattern[TRACK][bank[TRACK]][step_] > 0 then
      value_ = param_pattern[PARAM][TRACK][bank[TRACK]][step_]

      -- fill
      if tab.contains({'amp', 'length', 'prob'}, PARAM) then

        for i=1,6 do
          if value_ >= param_levels[PARAM][i] then
            g:led(s, 8 - i, g_brightness.level_met)
          end
        end

      end

      -- etc ...

    end

  end

  -- draw sequence bars
  draw_sequence_bars(1, 8, {1, 7})

end

function d_grid.sample_levels_key(x, y, z)
  if y < 8 then
    step_ = (SEQ_BAR - 1) * 16 + x
  end

  if y == 1 and z == 1 then
    if not PLAY_MODE then
      empty_step_ = pattern[TRACK][bank[TRACK]][step_] == 0
      pattern[TRACK][bank[TRACK]][step_] = empty_step_ and 1 or 0

      -- reset "new" step parameters to default
      if empty_step_ then
        default = track_param_default[PARAM]
        param_pattern[PARAM][TRACK][bank[TRACK]][step_] = default
      end
    else
      -- move track to that step
      step[TRACK] = step_
    end
  end
  
  if y == 8 and x < 9 then
    SEQ_BAR = x
  end

  if 1 < y and y < 8 and z == 1 and pattern[TRACK][bank[TRACK]][step_] > 0 then

    -- currrent parameter value at that step
    param_value = param_pattern[PARAM][TRACK][bank[TRACK]][step_]

    -- fill
    if tab.contains({'amp', 'length', 'prob'}, PARAM) then
      -- parameter value range of selected cell
      range_ = {param_levels[PARAM][8 - y], param_levels[PARAM][8 - y + 1]}

      if (range_[1] <= param_value and param_value < range_[2]) or
         (param_value == param_levels[PARAM][6] and y == 2) then
        
        -- if selecting already set value, make the "minimum"/"default"
        param_pattern[PARAM][TRACK][bank[TRACK]][step_] = param_levels[PARAM][7]
      
      else

        -- otherwise, assign value
        v = param_levels[PARAM][8-y]
        param_pattern[PARAM][TRACK][bank[TRACK]][step_] = v
      end
    end
    
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
        if tab.contains(track_pool_cue[TRACK], sample_id_) then
          g:led(x, y, g_brightness.bank_sample_cued)
        elseif sample_track[bank][row][col] then
          if TRACK == sample_track[bank][row][col] then
            g:led(x, y, g_brightness.bank_sample_current_track)
          else
            g:led(x, y, g_brightness.bank_sample_tracked)
          end

          -- show track that sample is loaded into
          if KEY_HOLD[y][x] == 1 then
            g:led(8, sample_track[bank][row][col], 
                  g_brightness.bank_sample_tracked)
          end
        else
          g:led(x, y, g_brightness.bank_sample_loaded)
        end
        
        if sample_status[sample_id_] == 1 and PLAY_MODE then
          g:led(x, y, g_brightness.bank_sample_playing)
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

    if BANK == bank_ then
      g:led(x, y, g_brightness.bank_selected)
    elseif bank_folders[bank_] then
      g:led(x, y, g_brightness.bank_loaded)
    else
      g:led(x, y, g_brightness.bank_empty)
    end

  end

  -- show selected sample (or bank it's in) if current bank is held
  for bank_ = 1,4 do
    x, y = global_xy(origin, bank_, 1)

    if KEY_HOLD[y][x] == 1 and SAMPLE and not PLAY_MODE then
      b_, r_, c_ = id_bankrowcol(SAMPLE)
      if b_ == BANK then
        -- highlight selected sample in bank
        g:led(c_ + 8, r_, g_brightness.bank_sample_selected)
      else
        -- highlight bank location
        g:led(b_ + 12, 5, g_brightness.bank_selected)
      end
    end
  end

  -- track selected for bank (overwrites the "find track")
  for y = 1,7 do
    if y == TRACK then
      g:led(8, y, g_brightness.track_selected)
    end
  end
  

end

function d_grid.draw_tracks()

  for y = 1,7 do
    for i=1,6 do

      -- fill
      if tab.contains({'amp'}, PARAM) then
        if params:get('track_' .. y .. '_amp') >= param_levels[PARAM][i] then
          g:led(i, y, g_brightness.level_met)
        end
      end

    end
  end

end

function d_grid.sample_config_redraw()
  d_grid.draw_bank(BANK)
  d_grid.draw_tracks()

  -- draw param selection
  for p = 1,6 do
    if PARAM == p_options.PARAMS[p] then
      g:led(p, 8, g_brightness.param_selected)
    else
      g:led(p, 8, g_brightness.param_deselected)
    end
  end

end

function d_grid.sample_config_key(x, y, z)

  -- bank selection
  if 12 < x and y == 5 then
    if z == 1 then
      origin = {13, 5}
      BANK, _ = rel_xy(origin, x, y)
    end
  end

  -- track selection
  if x == 8 and y < 8 then
    if z == 1 then
      -- load onto track (only if track already selected)
      if TRACK == y and ALT then
        d_seq.load_track_pool(TRACK)
      end
      TRACK = y

      -- show bank linked to track
      if #track_pool[TRACK] > 0 then
        BANK = bank[TRACK]
      end
    end
  end

  -- sample selection
  if 8 < x and y < 5 then
    row_ = y
    col_ = x - 8
    sample_id = rowcol_id(row_ .. col_, BANK)
    
    if z == 1 then
      d_sample.set_sample_id(sample_id)
      
      -- play sample
      if PLAY_MODE then
        if sample_status[sample_id] == 1 then
          d_sample.note_off(sample_id)
        else
          d_sample.note_on(sample_id, 1)
        end

      -- cue sample for track if it exists and is not already cued
      -- it also can't already be assigned
      elseif ALT and not tab.contains(track_pool_cue[TRACK], sample_id) and banks[BANK][row_][col_] and not sample_track[BANK][row_][col_] then
        table.insert(track_pool_cue[TRACK], sample_id)
      
      -- remove from cue if re-selected
      elseif ALT and tab.contains(track_pool_cue[TRACK], sample_id) then
        table.remove(track_pool_cue[TRACK], 
                     index_of(track_pool_cue[TRACK], sample_id))
      
      -- unassign track to sample
      elseif ALT and sample_track[BANK][row_][col_] == TRACK then
        sample_track[BANK][row_][col_] = nil
      end

    else
      
      if PLAY_MODE and sample_status[sample_id] > 0 and play_mode_is_hold(sample_id) then
        d_sample.note_off(sample_id)
      end
    end
  end

  -- track param levels
  if x < 7 and y < 8 and z == 1 then
    -- temp ... while building the rest of the params
    if PARAM == 'amp' then
      if params:get('track_' .. y .. '_amp') == param_levels[PARAM][x] then
        params:set('track_' .. y .. '_amp', param_levels[PARAM][7])
      else
        params:set('track_' .. y .. '_amp', param_levels[PARAM][x])
      end
    end
  end

  -- param selection
  if x < 7 and y == 8 and z == 1 then
    if p_options.PARAMS[x] == PARAM then
      PARAM = 'amp'
    else
      PARAM = p_options.PARAMS[x]
    end
  end

  grid_dirty = true
  screen_dirty = true
end

-----------------------------------------------------------------
-- REC SEQ
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_seq_redraw()

  for i = 1,8 do
    g:led(i, i, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_seq_key(x, y, z)
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

  for i = 1,8 do
    g:led(i + 2, i, 3)
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
-- REC TIME
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function d_grid.rec_time_redraw()

  for i = 1,8 do
    g:led(i + 4, i, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function d_grid.rec_time_key(x, y, z)
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

  for i = 1,8 do
    g:led(i + 6, i, 3)
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
-- REDRAW
-----------------------------------------------------------------

function d_grid:grid_redraw()
  g:all(0)
  d_grid[G_PAGE .. '_redraw']()
  d_grid.draw_nav()
  g:refresh()
end


function g.key(x, y, z)

  if z == 1 then
    KEY_HOLD[y][x] = 1
  else
    KEY_HOLD[y][x] = 0
  end

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

-- return index of value in table
function index_of(array, value)
  for i, v in ipairs(array) do
      if v == value then
          return i
      end
  end
  return nil
end

return d_grid