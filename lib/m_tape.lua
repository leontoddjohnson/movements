-- tape

-- softcut buffer length = 5 minutes 49.52 seconds
-- first 20 for delay, start at 30 for the rest.

local m_tape = {}

local Formatters = require "formatters"

-- {start, stop} for each partion. use [partition][row][col].
-- (samples use `banks`)
partitions = {
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}},
  {{}, {}, {}, {}}
}

armed = {}  -- 1 or 0 for whether armed[track] is armed for recording

PARTITION = 1  -- currently selected record partition
SLICE = {nil, nil}  -- currently selected slice

-----------------------------------------------------------------
-- BUILD PARAMETERS
-----------------------------------------------------------------

function m_tape.build_params()

  params:add{id="input_tape_level", name="input tape level",
		type="control", 
		controlspec=controlspec.AMP,
		action=function(x) audio.level_adc_cut(x) end}

	params:add{id="sample_tape_level", name="sample tape level",
		type="control", 
		controlspec=controlspec.AMP,
		action=function(x) audio.level_eng_cut(x) end}
  
end

function m_tape.build_tape_track_params()

  for t = 8, 11 do
    params:add_group("Track " .. t, 6)  -- # of track parameters

    -- AMPLITUDE
    params:add_control('track_' .. t .. '_amp', 'track_' .. t .. '_amp',
                       controlspec.AMP, Formatters.round(0.01))
    params:set_action('track_' .. t .. '_amp', 
      function(value)
        last_value = track_param_level[t]['amp']

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_amp(last_value, value, id)
        -- end

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
        local ranges = {}  -- ranges for `last_value` and `value`

        for i, v in ipairs({last_value, value}) do
          if v < 0 then
            ranges[i] = {-1, v + 1/3}
          elseif v > 0 then
            ranges[i] = {v - 1/3, 1}
          else
            ranges[i] = {-1, 1}
          end
        end

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_pan(ranges[1], ranges[2], id)
        -- end

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
        last_value = track_param_level[t]['filter_type']
        local freq = track_param_level[t]['filter_freq']
        sign_in = last_value == 1 and 1 or -1
        sign_out = value == 1 and 1 or -1

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_filter(freq * sign_in, freq * sign_out, id)
        -- end

        track_param_level[t]['filter_type'] = value
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

        -- -- squelch samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   m_sample.squelch_sample_filter(last_value * sign, value * sign, id)
        -- end

        track_param_level[t]['filter_freq'] = value
        grid_dirty = true
      end
    )

    -- FILTER RESONANCE
    params:add_control('track_' .. t .. '_filter_resonance', 
                       'track_' .. t .. '_filter_resonance',
                       specs.FILTER_RESONANCE)
    params:set_action('track_' .. t .. '_filter_resonance', 
      function(value)
        -- -- set samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   params:set('filter_resonance_' .. id, value)
        -- end
      end
    )

    -- DELAY
    params:add_control('track_' .. t .. '_delay', 
                       'track_' .. t .. '_delay',
                       controlspec.AMP)
    params:set_action('track_' .. t .. '_delay', 
    function(value)
        -- -- set samples in current track pool
        -- for i = 1, #track_pool[t] do
        --   id = track_pool[t][i]  -- sample id
        --   params:set('delay_' .. id, value)
        -- end
      end
    )
    
    -- TAG: param 5, add params ABOVE.
  
  end

end

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_tape.init()
  -- send levels
	audio.level_cut(1)

  -- these will only change when recording is armed
	audio.level_adc_cut(0)
	audio.level_eng_cut(0)

  -- waveform setup
  waveform_samples = {}
  wave_gain = {}

  -- only tape tracks 8-11
  for i = 8, 11 do
    waveform_samples[i] = {}
    wave_gain[i] = {}
  end
  view_buffer = false

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------


-- arm a track for recording
function m_tape.arm(track)
  
  -- armed
 
  if span(armed)[2] > 0 then
    audio.level_adc_cut(params:get('input_tape_level'))
	  audio.level_eng_cut(params:get('sample_tape_level'))
  end

end

-- disarm a track from recording
function m_tape.disarm(track)
  -- ...

  -- stop sending audio to delay if nothing is armed
  if span(armed)[2] == 0 then
    audio.level_adc_cut(0)
	  audio.level_eng_cut(0)
  end
end


-- function m_tape.sc_stop()
--   for i=1,4 do
--     softcut.rec(i, 0)
--     softcut.play(i, 0)
--     softcut.enable(i, 0)

--     -- input
--     if i < 3 then
--       softcut.position(i, 0)
--       m_dots.positions[i] = 0

--     -- dots
--     else
--       softcut.position(i, params:get('dots_loop_length'))
--       m_dots.positions[i] = params:get('dots_loop_length')
--     end
--   end

--   softcut.poll_stop_phase()
--   softcut.buffer_clear()
-- end

-- function m_tape.sc_start()
--   softcut.buffer_clear()

--   for i=1,4 do
--     -- init for all four
--     softcut.enable(i, 1)
--     softcut.buffer(i, 1)
--     softcut.rate(i, 1)
--     softcut.loop(i, 1)
--     softcut.loop_start(i, 0)
--     softcut.loop_end(i, params:get('dots_loop_length'))
--     softcut.fade_time(i, 0.1)
--     softcut.pan(i, i % 2 == 0 and 1 or -1)

--     -- watch position
--     softcut.phase_quant(i, 0.01)

--     -- input
--     if i < 3 then
--       softcut.position(i, 0)
--       softcut.rec_level(i, 1)
--       softcut.pre_level(i, 0)
--       softcut.level_input_cut(i, i, 1)
--       softcut.level(i, 0)
--       softcut.play(i, 1)
--       softcut.rec(i, 1)

--     -- dots
--     else
--       softcut.play(i, 0)
--       softcut.level(i, 1)
--       softcut.position(i, params:get('dots_loop_length'))
--       m_dots.positions[i] = params:get('dots_loop_length')
--     end
--   end

--   softcut.event_phase(m_dots.update_position)
--   softcut.poll_start_phase()
-- end


-- WAVEFORM (cr: sonocircuit) -----------------------------------

-- function wave_render(ch, start, i, s)
--   waveform_samples[TRACK] = {}
--   waveform_samples[TRACK] = s
--   waveviz_reel = false
--   wave_gain[TRACK] = wave_getmax(waveform_samples[TRACK])

--   screen_dirty = true
-- end

-- function wave_getmax(t)
--   local max = 0
--   for _,v in pairs(t) do
--     if math.abs(v) > max then
--       max = math.abs(v)
--     end
--   end
--   return util.clamp(max, 0.4, 1)
-- end

-- function render_splice()
--   if view == vTAPE and not (view_splice_info or view_presets) then 
--     if view_buffer then
--       local start = tp[TRACK].s
--       local length = tp[TRACK].e - tp[TRACK].s
--       local buffer = tp[TRACK].side
--       softcut.render_buffer(buffer, start, length, 128)
--     else
--       local n = track[TRACK].splice_focus
--       local start = tp[TRACK].splice[n].s
--       local length = tp[TRACK].splice[n].e - tp[TRACK].splice[n].s
--       local buffer = tp[TRACK].side
--       softcut.render_buffer(buffer, start, length, 128)
--     end
--   end
-- end

return m_tape

