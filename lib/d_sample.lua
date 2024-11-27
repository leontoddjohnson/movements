-- sample pages

d_sample = {}

local MusicUtil = require "musicutil"
local Formatters = require "formatters"
local BeatClock = require "beatclock"

local Timber = include "lib/d_timber"

local NUM_SAMPLES = 128  -- max 256

local beat_clock
local note_queue = {}

-- sample_status[sample_id] playing == 1, stopped == 0
sample_status = {}
STATUS = {
  STOPPED = 0,
  PLAYING = 1
}

-- sample IDs for each bank. use [bank][row][col].
banks = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}
bank_folders = {}

-- track assigned for sample [bank][row][col] = track # (1-7)
-- a track can only have one bank of samples loaded at once
sample_track = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}

-- samples to cycle through for each track
track_samples = {{}, {}, {}, {}, {}, {}, {}}
track_samples_cue = {{}, {}, {}, {}, {}, {}, {}}

BANK = 1  -- currently selected sample bank
TRACK = 1  -- currently selected track
SAMPLE = nil  -- currently selected sample

-----------------------------------------------------------------
-- PARAMETERS
-----------------------------------------------------------------

function d_sample.build_params()

  Timber.add_params()

  params:add_separator("Samples")
  
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

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function d_sample.init()

  for i = 0, NUM_SAMPLES - 1 do sample_status[i] = STATUS.STOPPED end

  -- Timber callbacks  ------------------------------------------
  Timber.sample_changed_callback = function(id)
    
    -- Set loop default based on sample length or name
    if Timber.samples_meta[id].manual_load and Timber.samples_meta[id].streaming == 0 and Timber.samples_meta[id].num_frames / Timber.samples_meta[id].sample_rate < 1 and string.find(string.lower(params:get("sample_" .. id)), "loop") == nil then
      params:set("play_mode_" .. id, 3) -- One shot
    end
    
    grid_dirty = true
    d_sample.callback_set_screen_dirty(id)
  end

  Timber.meta_changed_callback = function(id)
    if Timber.samples_meta[id].playing then
      sample_status[id] = STATUS.PLAYING
    else
      sample_status[id] = STATUS.STOPPED
    end

    grid_dirty = true
    d_sample.callback_set_screen_dirty(id)
  end

  Timber.waveform_changed_callback = d_sample.callback_set_waveform_dirty
  Timber.play_positions_changed_callback = d_sample.callback_set_waveform_dirty
  Timber.views_changed_callback = d_sample.callback_set_screen_dirty

  -- Timber views  ----------------------------------------------
  -- sample_setup_view = Timber.UI.SampleSetup.new(0, nil)
  waveform_view = Timber.UI.Waveform.new(0)
  filter_amp_view = Timber.UI.FilterAmp.new(0)
  amp_env_view = Timber.UI.AmpEnv.new(0)
  mod_env_view = Timber.UI.ModEnv.new(0)
  lfos_view = Timber.UI.Lfos.new(0)
  mod_matrix_view = Timber.UI.ModMatrix.new(0)
  
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

-- convert *string* "<rowcol>" syntax to 0-indexed id for timber
-- going L->R, Top->Bottom down 4 4x8 matrices, 0-indexed
function rowcol_id(rowcol, bank)
  rowcol = tonumber(rowcol)
  local n_rows_above = (rowcol - 10) // 10  -- in bank
  local n_cols_over = rowcol % 10
  local bank_id = 8 * n_rows_above + n_cols_over - 1 -- 0-index
  return 32 * (bank - 1) + bank_id
end

-- return triple: bank, row, col from the id number
function id_bankrowcol(id)
  local bank = (id // 32) + 1
  local row = (id - (bank - 1) * 32) // 8 + 1
  local col = (id - (bank - 1) * 32) % 8 + 1
  return bank, row, col
end


function d_sample:load_bank(bank)
  Timber.FileSelect.enter(_path.audio, function(file)
    file_select_active = false
    if file ~= "cancel" then
      self.load_folder(file, bank)
    end
  end)
end

function d_sample.load_folder(file, bank)
  
  -- first sample in bank
  local sample_id = (bank - 1) * 32
  
  Timber.clear_samples(sample_id, bank * 32 - 1)
  
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
      local rowcol = string.match(lower_v, "^%d%d[%s-_]")
      
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
        Timber.load_sample(sample_id, folder .. v)
        bank_, row, col = id_bankrowcol(sample_id)

        if bank ~= bank_ then
          error("bank calculation is incorrect")
        end

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

-- load `track_samples` from `track_samples_cue`, and clear out cue
-- loads from *current bank*
function d_sample.load_track_samples(track)
  track_samples[track] = track_samples_cue[track]
  track_samples_cue[track] = {}
  for i=1,#track_samples[track] do
    b_, row_, col_ = id_bankrowcol(track_samples[track][i])
    sample_track[BANK][row_][col_] = track
  end
end

function d_sample.note_on(sample_id, vel)
  if (params:get('sample_' .. sample_id) ~= "-") 
      and (sum(sample_status) < 7) then

    print("note_on", sample_id)
    vel = vel or 1
    engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
    sample_status[sample_id] = 1

    -- sample_status[sample_id] = STATUS.PLAYING
    -- global_view:add_play_visual()
    -- screen_dirty = true
    -- grid_dirty = true
  else
    print("no sample " .. sample_id .. " OR too many already playing")
  end
end

function d_sample.note_off(sample_id)
  print("note_off", sample_id)
  engine.noteOff(sample_id)
  sample_status[sample_id] = 0
  -- screen_dirty = true
  -- grid_dirty = true
end

function d_sample.note_kill_all()
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

function d_sample.callback_set_screen_dirty(id)
  if id == nil or id == SAMPLE then
    screen_dirty = true
  end
end

function d_sample.callback_set_waveform_dirty(id)
  if (id == nil or id == SAMPLE) then
    screen_dirty = true
  end
end

function d_sample.set_sample_id(id)
  SAMPLE = id

  waveform_view:set_sample_id(id)
  filter_amp_view:set_sample_id(id)
  -- amp_env_view:set_sample_id(id)
  -- mod_env_view:set_sample_id(id)
  -- lfos_view:set_sample_id(id)
  -- mod_matrix_view:set_sample_id(id)
end

-- play the cued sample for track `track`
function d_sample.play_track_sample(track)
  print("playing sample for track ".. track)
end


return d_sample