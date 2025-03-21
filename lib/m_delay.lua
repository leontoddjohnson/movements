-- softcut delay for tape
-- **USES VOICES 5 AND 6**

local m_delay = {}

local Formatters = require "formatters"

-- starting place on buffer for delay. the rest is for tape.
BUFFER_SPLIT = 322

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_delay.build_params()
	params:add_group("Tape Delay", 5)
  params:add{id="tape_delay_level", name="tape delay level",
		type="control", 
    controlspec=specs.AMP0,
    action=function(x) 
			softcut.level(5, x) 
			softcut.level(6, x)
			end}

	params:add{id="tape_delay_time_l", name="tape delay time (L)",
		type="number", 
    min=1,
		max=#clock_fraction,
		default=index_of(clock_fraction, 1),
		formatter=function(p)
			v = p:get()
			v = clock_fraction[v]
			return format_clock_fraction(v)
		end,
    action=function(x)
			local frac = clock_fraction[x]
			local secs = clock.get_beat_sec() * frac
			softcut.loop_end(5, BUFFER_SPLIT + secs)
		end}

	params:add{id="tape_delay_time_r", name="tape delay time (R)",
		type="number", 
		min=1,
		max=#clock_fraction,
		default=index_of(clock_fraction, 1),
		formatter=function(p)
			v = p:get()
			v = clock_fraction[v]
			return format_clock_fraction(v)
		end,
		action=function(x)
			local frac = clock_fraction[x]
			local secs = clock.get_beat_sec() * frac
			softcut.loop_end(6, BUFFER_SPLIT + secs)
		end}

  params:add{id="tape_delay_feedback_l", name="tape delay feedback (L)", 
		type="control", 
    controlspec=specs.DELAY_FEEDBACK,
		formatter=Formatters.unipolar_as_percentage,
    action=function(x) softcut.pre_level(5, x) end}

	params:add{id="tape_delay_feedback_r", name="tape delay feedback (R)", 
		type="control", 
    controlspec=specs.DELAY_FEEDBACK,
		formatter=Formatters.unipolar_as_percentage,
    action=function(x) softcut.pre_level(6, x) end}

end

function m_delay.init()

	for v=5,6 do
		ch = (v + 1) % 2 + 1

		softcut.enable(v, 1)
		softcut.buffer(v, ch)
		softcut.level_input_cut(ch, v, 1)
		softcut.level(v, 0)
		softcut.level_slew_time(v, 0.1)
		softcut.pan(v, v == 5 and -1 or 1)

		softcut.rate(v, 1)
		softcut.loop_start(v, BUFFER_SPLIT)
		softcut.loop_end(v, BUFFER_SPLIT + clock.get_beat_sec())
		softcut.loop(v, 1)
		softcut.position(v, BUFFER_SPLIT)
		softcut.fade_time(v, 0.1)
		softcut.rec_level(v, 1)
		softcut.pre_level(v, 0.5)
		softcut.play(v, 1)
		softcut.rec(v, 1)
	
	end
	
end


-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------


return m_delay