-- sample pages

m_sample = {}

local Timber = include "lib/m_timber"
local MusicUtil = require "musicutil"
local Formatters = require "formatters"

local NUM_SAMPLES = 128  -- max 256

-- sample_status[sample_id] playing == 1, stopped == 0
sample_status = {}

-- indicates if sample is currently playing in reverse (1 and 0)
sample_reversed = {}
STATUS = {
  STOPPED = 0,
  PLAYING = 1
}

-- sample IDs for each bank. use [bank][row][col].
-- (recordings use `partitions`)
banks = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}
bank_folders = {}

BANK = 1  -- currently selected sample bank
TRACK = 1  -- currently selected track
SAMPLE = 0  -- currently selected sample

-----------------------------------------------------------------
-- PARAMETERS
-----------------------------------------------------------------

function m_sample.build_timber_params()

  Timber.add_params()
  params:add_separator("Timber Samples")
  
  -- Index zero to align with MIDI note numbers
  for i = 0, NUM_SAMPLES - 1 do
    local extra_params = {
      {type = "option", id = "launch_mode_" .. i, name = "Launch Mode", options = {"Gate", "Toggle"}, default = 1, action = function(value)
        Timber.setup_params_dirty = true
      end}
    }
    Timber.add_sample_params(i, true, extra_params)
  end
end

function m_sample.build_sample_track_params()

  for t = 1,7 do
    params:add_group("Track " .. t, 11)  -- # of track parameters

    -- AMPLITUDE
    params:add_control('track_' .. t .. '_amp', 'track_' .. t .. '_amp',
                       specs.AMP1)
    params:set_action('track_' .. t .. '_amp', 
      function(value)
        last_value = track_param_level[t]['amp']

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id

          -- convert db to amp, then squelch
          db_ = params:get('amp_' .. id)
          amp_ = util.dbamp(db_)
          db_ = m_seq.squelch_amp(last_value, value, amp_, true)

          params:set('amp_' .. id, db_)
        end

        track_param_level[t]['amp'] = value
        grid_dirty = true
      end
    )

    -- PANNING
    params:add_control('track_' .. t .. '_pan', 'track_' .. t .. '_pan', 
                       controlspec.PAN, Formatters.round(0.01))
    params:set_action('track_' .. t .. '_pan', 
      function(value)
        local last_value = track_param_level[t]['pan']
        local pan_in, pan

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          pan_in = params:get('pan_' .. id)
          
          pan = m_seq.squelch_pan({last_value, 1}, {value, 1}, pan_in)
          params:set('pan_' .. id, pan)

        end

        track_param_level[t]['pan'] = value
        grid_dirty = true
      end
    )

    -- FILTER TYPE
    params:add_option('track_' .. t .. '_filter_type', 
                      'track_' .. t .. '_filter_type',
                      options.FILTER_TYPE, 1)
    params:set_action('track_' .. t .. '_filter_type',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          params:set('filter_type_' .. id, value)
        end

        track_param_level[t]['filter_type'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- FILTER FREQ
    params:add_control('track_' .. t .. '_filter_freq', 
                       'track_' .. t .. '_filter_freq',
                       specs.FILTER_FREQ)
    params:set_action('track_' .. t .. '_filter_freq', 
      function(value)
        last_value = track_param_level[t]['filter_freq']
        local pass = track_param_level[t]['filter_type']
        local sign = pass == 1 and 1 or -1
        local freq

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          freq_in = params:get('filter_freq_' .. id)

          freq = m_seq.squelch_filter(last_value * sign, value * sign, freq_in)
          params:set('filter_freq_' .. id, freq)
        end

        track_param_level[t]['filter_freq'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- FILTER RESONANCE
    params:add_control('track_' .. t .. '_filter_resonance', 
                       'track_' .. t .. '_filter_resonance',
                       specs.FILTER_RESONANCE)
    params:set_action('track_' .. t .. '_filter_resonance', 
      function(value)
        -- set samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          params:set('filter_resonance_' .. id, value)
        end
        screen_dirty = true
      end
    )

    -- DELAY
    params:add_control('track_' .. t .. '_delay', 
                       'track_' .. t .. '_delay',
                       specs.AMP0)
    params:set_action('track_' .. t .. '_delay', 
    function(value)
      last_value = track_param_level[t]['delay']

      -- set samples in current track pool
      for i = 1, #track_pool[t] do
        id = track_pool[t][i]  -- sample id
        delay_in = params:get('delay_' .. id)
        delay_out = m_seq.squelch_amp(last_value, value, delay_in, false)
        params:set('delay_' .. id, delay_out)
      end

      track_param_level[t]['delay'] = value
      screen_dirty = true
      grid_dirty = true
    end
    )

    -- NOISE
    params:add_control('track_' .. t .. '_noise', 
                       'track_' .. t .. '_noise',
                       specs.NOISE)
    params:set_action('track_' .. t .. '_noise', 
    function(value)
        -- set samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id
          params:set('noise_' .. id, value)
        end
        screen_dirty = true
      end
    )

    -- SCALE
    params:add_number('track_' .. t .. '_scale', 
                      'track_' .. t .. '_scale',
                      0, 5, 2)
    params:set_action('track_' .. t .. '_scale',
      function(value)
        local last_value = track_param_level[t]['scale']

        -- squelch samples in current track pool
        for i = 1, #track_pool[t] do
          id = track_pool[t][i]  -- sample id

          transpose_in = params:get('transpose_' .. id)
          scale_in = transpose_to_scale(transpose_in, t)
          scale = m_seq.squelch_scale({last_value, 5}, {value, 5}, scale_in)
          transpose_out = scale_to_transpose(scale, t)
          params:set('transpose_' .. id, transpose_out)
          
        end

        track_param_level[t]['scale'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- Forward or Reverse
    params:add_option('track_' .. t .. '_scale_type', 
                      'track_' .. t .. '_scale_type',
                       {"Forward", "Reverse"}, 1)
    params:set_action('track_' .. t .. '_scale_type',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          m_sample.reverse_buffer(id)
        end

        track_param_level[t]['scale_type'] = value
        screen_dirty = true
        grid_dirty = true
      end
    )

    -- INTERVAL
    params:add_number('track_' .. t .. '_interval',
                      'track_' .. t .. '_interval',
                      1, 11, 7, 
      function(param)
        v = param:get()
        if v == param_levels.interval[1] then return '2nd'
        elseif v == param_levels.interval[2] then return '3rd'
        elseif v == param_levels.interval[3] then return '4th'
        elseif v == param_levels.interval[4] then return '5th'
        elseif v == param_levels.interval[5] then return '6th'
        elseif v == param_levels.interval[6] then return '7th'
        else return v .. ' st' end
      end)
    params:set_action('track_' .. t .. '_interval',
      function(value)

        for i = 1, #track_pool[t] do
          id = track_pool[t][i]
          transpose_in = params:get('transpose_' .. id)
          -- new interval is used in the next two functions
          scale_in = transpose_to_scale(transpose_in, t)
          transpose_out = scale_to_transpose(scale_in, t)
          params:set('transpose_' .. id, transpose_out)
        end

        track_param_level[t]['interval'] = value
        screen_dirty = true
        grid_dirty = true
      end
      )
    
    -- PROBABILITY
    params:add_control('track_' .. t .. '_prob',
                       'track_' .. t .. '_prob',
                       specs.AMP1, Formatters.percentage)
  
  end

end

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_sample.timber_init()

  for i = 0, NUM_SAMPLES - 1 do sample_status[i] = STATUS.STOPPED end

  -- Timber callbacks  ------------------------------------------
  Timber.sample_changed_callback = function(id)
    
    -- Set loop default based on sample length or name
    if Timber.samples_meta[id].manual_load and Timber.samples_meta[id].streaming == 0 and Timber.samples_meta[id].num_frames / Timber.samples_meta[id].sample_rate < 1 and string.find(string.lower(params:get("sample_" .. id)), "loop") == nil then
      params:set("play_mode_" .. id, 4)  -- One shot
    end
    
    grid_dirty = true
    m_sample.callback_set_screen_dirty(id)
  end

  Timber.meta_changed_callback = function(id)
    if Timber.samples_meta[id].playing then
      sample_status[id] = STATUS.PLAYING
    else
      sample_status[id] = STATUS.STOPPED
    end

    grid_dirty = true
    m_sample.callback_set_screen_dirty(id)
  end

  Timber.waveform_changed_callback = m_sample.callback_set_waveform_dirty
  Timber.play_positions_changed_callback = m_sample.callback_set_waveform_dirty
  Timber.views_changed_callback = m_sample.callback_set_screen_dirty

  -- Timber views  ----------------------------------------------
  sample_setup_view = Timber.UI.SampleSetup.new(0, nil)
  waveform_view = Timber.UI.Waveform.new(0)
  filter_amp_view = Timber.UI.FilterAmp.new(0)
  amp_env_view = Timber.UI.AmpEnv.new(0)
  mod_env_view = Timber.UI.ModEnv.new(0)
  lfos_view = Timber.UI.Lfos.new(0)
  mod_matrix_view = Timber.UI.ModMatrix.new(0)
  
  -- initial sample
  m_sample.set_sample_id(SAMPLE)

end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- determine whether a sample is in Gated or Inf. Loop mode
-- if it's either of these, then the sample must be "held",
-- and it's killed when "let go".
function play_mode_is_hold(id)
  local play_mode

  if samples_meta[id].streaming > 0 then
    play_mode = options.PLAY_MODE_STREAMING[params:get('play_mode_' .. id)]
  else
    play_mode = options.PLAY_MODE_BUFFER[params:get('play_mode_' .. id)]
  end

  if play_mode == 'Gated' or play_mode == 'Inf. Loop' then
    return true
  else
    return false
  end
end

-- clear all samples associated with `bank` that are loaded into any
-- track pools or track pool cues.
function m_sample.clear_bank_pools(bank)

  -- range of ids in the bank [min, max + 1] (exclusive on the end)
  local bank_id_range = {32 * (bank - 1), 32 * bank}

  -- only attributed to sample tracks (namely those using this `bank`)
  for track = 1,7 do
    -- check track pool (note, `track_pool` can only have samples from one bank)
    if #track_pool[track] > 0 
      and bank_id_range[1] <= track_pool[track][1]
      and track_pool[track][1] < bank_id_range[2] then
        -- set parameters back to default
        m_sample.sample_params_to_default(track_pool[track])
        -- clear track pool
        track_pool[track] = {}
        track_pool_i[track] = 0
      end

    -- check track pool cue
    if #track_pool_cue[track][bank] > 0 then
      -- set parameters back to default
      m_sample.sample_params_to_default(track_pool_cue[track][bank])
      -- clear track pool cue
      track_pool_cue[track][bank] = {}
    end
  end
  
end

-- convert *string* "<rowcol>" syntax to 0-indexed id for timber
-- going L->R, Top->Bottom down 4 4x8 matrices, 0-indexed
function rowcol_id(rowcol, bank)
  rowcol = tonumber(rowcol)
  local n_rows_above = (rowcol - 10) // 10  -- in bank
  local n_cols_over = rowcol % 10
  local bank_id = 8 * n_rows_above + n_cols_over - 1 -- 0-index
  return 32 * (bank - 1) + bank_id
end

-- return triple: bank, row, col from a 0-indexed id number
function id_bankrowcol(id)
  local bank = (id // 32) + 1
  local row = (id - (bank - 1) * 32) // 8 + 1
  local col = (id - (bank - 1) * 32) % 8 + 1
  return bank, row, col
end


function m_sample:load_bank(bank)
  file_select_active = true
  Timber.FileSelect.enter(_path.audio, function(file)
    file_select_active = false
    if file ~= "cancel" then
      m_sample.clear_bank_pools(bank)
      self.load_folder(file, bank)
    end
  end)
end

function m_sample.load_folder(file, bank)
  
  -- first sample in bank
  local sample_id = (bank - 1) * 32
  
  Timber.clear_samples(sample_id, bank * 32 - 1)
  banks[bank] = {{}, {}, {}, {}}
  
  -- filename
  local split_at = string.match(file, "^.*()/")
  local folder = string.sub(file, 1, split_at)
  file = string.sub(file, split_at + 1)

  -- folder name
  local folder_ = string.sub(folder, 1, -2)
  split_at = string.match(folder_, "^.*()/")
  local folder_name = string.sub(folder_, split_at + 1)
  
  local found = false
  for k, v in ipairs(Timber.FileSelect.list) do
    if v == file then found = true end
    if found then
      -- get lowercase filename
      local lower_v = v:lower()
        
      -- find rowcol* if "<rowcol>*..." naming convention (* = space|-|_)
      local rowcol = string.match(lower_v, "^[1-4][1-8][%s-_]")
      
      if rowcol ~= nil then
        -- remove the split character
        rowcol = string.sub(rowcol, 1, 2)
        sample_id = rowcol_id(rowcol, bank)
      end

      if sample_id >= bank * 32 then
        print("Max files loaded in bank.")
        break
      end

      if string.match(lower_v, ".wav$") or string.match(lower_v, ".aif$") or string.match(lower_v, ".aiff$") or string.match(lower_v, ".ogg$") then
        bank_, row, col = id_bankrowcol(sample_id)

        if bank ~= bank_ then
          error("bank calculation is incorrect for " .. lower_v)
        end

        Timber.load_sample(sample_id, folder .. v)
        banks[bank][row][col] = sample_id
        sample_id = sample_id + 1

      else
        print("Skipped ", v)
      end
    end
  end
  bank_folders[bank] = folder_name
  screen_dirty = true
  grid_dirty = true
end

function m_sample.note_on(sample_id, vel)
  if sample_id ~= nil and (params:get('sample_' .. sample_id) ~= "-") 
      and (sum(sample_status) < 7) then

    print("note_on: " .. sample_id)
    vel = vel or 1
    engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
    sample_status[sample_id] = 1

    -- sample_status[sample_id] = STATUS.PLAYING
    -- global_view:add_play_visual()
    -- screen_dirty = true
    -- grid_dirty = true
  elseif sample_id == nil then
    print("sample_id is nil, likely nothing loaded in the sample pool.")
  else
    print("no sample " .. sample_id .. " OR too many already playing.")
  end
end

-- reverse buffer samples less than 5 seconds long. 
-- streaming samples (> 5 sec) cannot be reversed ... sad day.
function m_sample.reverse_buffer(id)

  if samples_meta[id]['streaming'] == 0 then
    local start_frame = params:get("start_frame_" .. id)
    local loop_start_frame = params:get("loop_start_frame_" .. id)
    local loop_end_frame = params:get("loop_end_frame_" .. id)

    params:set("start_frame_" .. id, params:get("end_frame_" .. id))
    params:set("end_frame_" .. id, start_frame)
    params:set("loop_start_frame_" .. id, loop_start_frame)
    params:set("loop_end_frame_" .. id, loop_end_frame)

    if sample_reversed[id] then
      sample_reversed[id] = nil
    else
      sample_reversed[id] = 1
    end
  end
  
end

function m_sample.note_off(sample_id)
  if sample_id then print("note_off: " .. sample_id) end
  engine.noteOff(sample_id)
  if sample_id ~= nil then
    sample_status[sample_id] = 0
  end
  -- screen_dirty = true
  -- grid_dirty = true
end

function m_sample.note_kill_all()
  engine.noteKillAll()
  -- screen_dirty = true
  -- grid_dirty = true
end

-- calculate sum of numeric or boolean (true == 1) values
function sum(t)
  s = 0
  for i=1,#t do
    if t[i] == true then v = 1 else v = t[i] end
    s = s + v
  end
  return s
end

function m_sample.callback_set_screen_dirty(id)
  if id == nil or id == SAMPLE then
    screen_dirty = true
    grid_dirty = true
  end
end

function m_sample.callback_set_waveform_dirty(id)
  if (id == nil or id == SAMPLE) then
    screen_dirty = true
    grid_dirty = true
  end
end

function m_sample.set_sample_id(id)
  SAMPLE = id

  -- update play mode options on grid
  if samples_meta[SAMPLE]['streaming'] == 1 then
    g_play_modes = shallow_copy(g_play_modes_all.streaming)
  else
    g_play_modes = shallow_copy(g_play_modes_all.buffer)
  end

  waveform_view:set_sample_id(id)
  -- filter_amp_view:set_sample_id(id)
  -- sample_setup_view:set_sample_id(id)
  amp_env_view:set_sample_id(id)
  -- mod_env_view:set_sample_id(id)
  -- lfos_view:set_sample_id(id)
  -- mod_matrix_view:set_sample_id(id)
end

-- set a collection of sample ids back to default
function m_sample.sample_params_to_default(sample_ids)
  local id
  local timber_params = {
    'amp', 'transpose', 'noise',
    'pan', 'delay', 'filter_freq', 'filter_type', 'filter_resonance'
  }

  for i = 1,#sample_ids do
    id = sample_ids[i]

    for p,v in pairs(track_param_default) do
      if p == 'amp' then
        -- convert to db
        amp = util.clamp(ampdb(v), specs.AMP.minval, 0)
        params:set('amp_' .. id, amp)

      elseif p == 'transpose' then
        -- check for reversal
        params:set('transpose_' .. id, v)
        if sample_reversed[id] then m_sample.reverse_buffer(id) end

      elseif tab.contains(timber_params, p) then
        -- set timber parameters
        params:set(p .. '_' .. id, v)
      end
    end

  end

end

-- set a collection of sample ids to the track levels
function m_sample.sample_params_to_track(sample_ids, track)
  -- do this before a sample is added to a track_pool
  local id, p_track

  for i = 1,#sample_ids do
    id = sample_ids[i]

    -- AMP
    p_track = params:get('track_' .. track .. '_amp')
    amp = util.clamp(ampdb(p_track), specs.AMP.minval, 0)
    params:set('amp_' .. id, amp)

    -- OTHER TIMBER PARAMS
    local params_ = {
      "pan", "filter_freq", "filter_type", "filter_resonance", 'delay',
      'noise'
    }

    for i,p in ipairs(params_) do
      p_track = params:get('track_' .. track .. '_' .. p)
      params:set(p .. '_' .. id, p_track)
    end

    -- get scale and direction
    scale = params:get('track_' .. track .. '_scale')
    scale_type = params:get('track_' .. track .. '_scale_type')

    -- revert to main octave, set scale, then direction
    transpose = scale_to_transpose(scale, track)
    params:set('transpose_' .. id, transpose)

    if sample_reversed[id] then
      if scale_type == 1 then m_sample.reverse_buffer(id) end
    elseif scale_type == 2 then
      m_sample.reverse_buffer(id)
    end

  end
end

-- return the *text* of a sample's play mode
function m_sample.play_mode_option(id)
  local play_mode_lookup = params:lookup_param("play_mode_" .. id)
  local i = play_mode_lookup['selected']
  local options_ = play_mode_lookup['options']

  return options_[i]
end

-- return the *index* of a play mode (to pass into params:set)
function m_sample.play_mode_i(id, option)
  local play_mode_lookup = params:lookup_param("play_mode_" .. id)
  local options_ = play_mode_lookup['options']

  return index_of(options_, option)
end

-- return the *text* of a sample's option-based parameter value
-- `id` is the sample id, `param` is without the trailing underscore
-- and `options` is an optional argument (e.g., options.FILTER_TYPE)
function m_sample.param_option(id, param, options)
  local lookup = params:lookup_param(param .. "_" .. id)
  local i = lookup['selected']
  local options_ = options or lookup['options']

  return options_[i]
end

-- return the *index* of an option-based parameter's option
-- ... (to pass into params:set). `options` is optional.
function m_sample.option_param_i(id, param, option, options)
  local lookup = params:lookup_param(param .. "_" .. id)
  local options_ = options or lookup['options']

  return index_of(options_, option)
end

function m_sample.sample_length(id)
  local duration = math.abs(params:get("end_frame_" .. id) - 
                            params:get("start_frame_" .. id)) / 
                            samples_meta[id].sample_rate
  return duration
end

-- given a scale value from `param_levels.scale`, convert to number of
-- semitones for a given track
function scale_to_transpose(scale, track, interval)

  interval = interval or params:get('track_' .. track .. '_interval')

  if scale == 0 then return -12
  elseif scale == 1 then return interval - 12
  elseif scale == 2 then return 0
  elseif scale == 3 then return interval
  elseif scale == 4 then return 12
  elseif scale == 5 then return 24  -- this *could* be another interval ...
  end
end

-- given a transposition, convert to the `param_levels.scale` value, 
-- given a track (inverse of `scale_to_transpose`)
function transpose_to_scale(transpose_in, track, interval)

  interval = interval or params:get('track_' .. track .. '_interval')

  if transpose_in == -12 then scale = 0
  elseif transpose_in == interval - 12 then scale = 1
  elseif transpose_in == 0 then scale = 2
  elseif transpose_in == interval then scale = 3
  elseif transpose_in == 12 then scale = 4
  elseif transpose_in == 24 then scale = 5 
  else scale = 3
  end

  return scale
end

-- convert amp [0, 1] to decibels [-inf, 0]
function ampdb(amp)
  return math.log(amp, 10) * 20.0
end

-- create a shallow copy of a table `t`
function shallow_copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

return m_sample