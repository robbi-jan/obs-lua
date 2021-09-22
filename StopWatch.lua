--[[
----------------------------------------------------------
----------------------------------------------------------
]]
obs           		= obslua
last_text    		= ""
source_name   		= ""
default_text   		= "00:00:00,00"
cur_seconds   		= 0
orig_time     		= 0
timer_cycle    		= 10 --milliseconds 
time_frequency 		= 0.016666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667
activated     		= false
timer_active  		= false
reset_activated    	= false
start_on_visible  	= false
disable_script   	= false
hotkey_id_reset     = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_pause     = obs.OBS_INVALID_HOTKEY_ID

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
local function log(name, msg)
  if msg ~= nil then
    msg = " > " .. tostring(msg)
  else
    msg = ""
  end
  obs.script_log(obs.LOG_DEBUG, name .. msg)
end

--[[
----------------------------------------------------------
	Used this in testing to measure accuracy

	The Text Source and the Log should produce the same value
	The Text source is updated by the time function while the bedug 
	uses start and end timestamps to get a value
----------------------------------------------------------
]]
function get_time_lapsed()
	local ns = obs.os_gettime_ns()
	local delta = (ns/1000000000.0) - (orig_time/1000000000.0)
	local ms = (delta / 1000000)
	local s = (ms / 1000)
	log('ns now', TimeFormat(delta))
end	

--[[
----------------------------------------------------------
	Convert Seconds to hours:minutes:seconds:miliseconds
----------------------------------------------------------
]]
function TimeFormat(time)
	local hour, minutes, seconds, mili = 0, 0, 0, 0
	hour = math.floor(time/3600)
	if hour < 10 then
		hour = "0"..hour
	end
	minutes = math.floor((time - math.floor(time/3600)*3600)/60)
	if minutes < 10 then
		minutes = "0"..minutes
	end
	seconds =  math.floor(time - math.floor(time/3600)*3600 - math.floor((time - math.floor(time/3600)*3600)/60)*60)
	if seconds < 10 then
		seconds = "0"..seconds
	end
	mili = math.floor((time - math.floor(time/3600)*3600 - math.floor((time - math.floor(time/3600)*3600)/60)*60 - math.floor(time - math.floor(time/3600)*3600 - math.floor((time - math.floor(time/3600)*3600)/60)*60))*100)
	if mili < 10 then
		mili = "0"..mili
	end
	return hour..":"..minutes..":"..seconds..","..mili	
end

--[[
----------------------------------------------------------
	Function to set the time text
----------------------------------------------------------
]]
function set_time_text()
	if reset_activated then 
		reset_activated = false
		fresh_start(true) 
	end		
	local text = tostring(TimeFormat(cur_seconds))
	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end
	last_text = text
end

--[[
----------------------------------------------------------
	Add timer here so we have a global setting
----------------------------------------------------------
]]
function start_timer()
	timer_active = true
	fresh_start(false)
	obs.timer_add(timer_callback, timer_cycle) --<- milliseconds 
end	

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function timer_callback()
	--[[
	higher increase time
	.01 seconds = 10 milliseconds
	1/60 = 0.0166666...
	]]
	cur_seconds = cur_seconds + time_frequency
	set_time_text()
end

--[[
----------------------------------------------------------
	Called if the counter is starting fresh
----------------------------------------------------------
]]
function fresh_start(reset_curent)
	
	if reset_curent ~= nil then
		if reset_curent then
			cur_seconds = 0
		end
	end
	
	orig_time = obs.os_gettime_ns()
end	

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function activate(activating)
	if disable_script then
		return		
	end	
	activated = activating
	if activating then	
		--obs.obs_frontend_recording_start()
		start_timer()
	else
		timer_active = false
		obs.timer_remove(timer_callback)
	end
end

--[[
----------------------------------------------------------
	Called when a source is activated/deactivated
----------------------------------------------------------
]]
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			if start_on_visible then
				activate(activating)
			end
		end
	end
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function source_activated(cd)
   if disable_script then
		return		
	end
	activate_signal(cd, true)
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function source_deactivated(cd)
	activate_signal(cd, false)
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function reset(pressed)
	if not pressed then
		return
	end
	reset_activated = true
	set_time_text()
	activate(false)
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function reset_button_clicked(props, p)
	reset(true)
	return false
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function pause_button_clicked(props, p)
	on_pause(true)
	return false
end

--[[
----------------------------------------------------------
----------------------------------------------------------
]]
function on_pause(pressed)
	if not pressed then
		return
	end
	if timer_active then
		timer_active = false
		activate(false)
		get_time_lapsed()
	else
		if activated == false then
			
			activate(true)
		end	
	end
end

--[[
----------------------------------------------------------
	A function named script_properties defines the properties that the user
	can change for the entire script module itself
----------------------------------------------------------
]]
function script_properties()
	local props = obs.obs_properties_create()
	local p = obs.obs_properties_add_list(props, "source", "Timer Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(p, "Select", "select")
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	obs.obs_properties_add_button(props, "reset_button", "Reset Stopwatch", reset_button_clicked)
	obs.obs_properties_add_button(props, "pause_button", "Start/Pause Stopwatch", pause_button_clicked)
    obs.obs_properties_add_bool(props, "start_on_visible", "Start Timer on Source Visible")
    obs.obs_properties_add_bool(props, "disable_script", "Disable Script")
	return props
end

--[[
----------------------------------------------------------
	A function named script_description returns the description shown to
	the user
----------------------------------------------------------
]]
function script_description()
	return "Stopwatch"
end

--[[
----------------------------------------------------------
	A function named script_update will be called when settings are changed
----------------------------------------------------------
]]

function script_update(settings)
	activate(false)
	source_name = obs.obs_data_get_string(settings, "source")
    start_on_visible = obs.obs_data_get_bool(settings,"start_on_visible")
    disable_script = obs.obs_data_get_bool(settings,"disable_script")
	reset(true)
end

--[[
----------------------------------------------------------
A function named script_defaults will be called to set the default settings
----------------------------------------------------------
]]
function script_defaults(settings)
	obs.obs_data_set_default_bool(settings, "start_on_visible", false)
	obs.obs_data_set_default_bool(settings, "disable_script", false)
end

--[[
----------------------------------------------------------
	A function named script_save will be called when the script is saved
	NOTE: This function is usually used for saving extra data (such as in this
	case, a hotkey's save data).  Settings set via the properties are saved
	automatically.
----------------------------------------------------------
]]
function script_save(settings)
	local hotkey_save_array_reset = obs.obs_hotkey_save(hotkey_id_reset)
	local hotkey_save_array_pause = obs.obs_hotkey_save(hotkey_id_pause)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array_reset)
	obs.obs_data_set_array(settings, "pause_hotkey", hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
end

--[[
----------------------------------------------------------
	a function named script_load will be called on startup	
	Connect hotkey and activation/deactivation signal callbacks
	--
	NOTE: These particular script callbacks do not necessarily have to
	be disconnected, as callbacks will automatically destroy themselves
	if the script is unloaded.  So there's no real need to manually
	disconnect callbacks that are intended to last until the script is
	unloaded.
----------------------------------------------------------
]]
function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
	hotkey_id_reset = obs.obs_hotkey_register_frontend("reset_stopwatch_thingy", "Reset Stopwatch", reset)
	hotkey_id_pause = obs.obs_hotkey_register_frontend("pause_stopwatch_thingy", "Start/Pause Stopwatch", on_pause)
	local hotkey_save_array_reset = obs.obs_data_get_array(settings, "reset_hotkey")
	local hotkey_save_array_pause = obs.obs_data_get_array(settings, "pause_hotkey")
	obs.obs_hotkey_load(hotkey_id_reset, hotkey_save_array_reset)
	obs.obs_hotkey_load(hotkey_id_pause, hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
	obs.obs_data_array_release(hotkey_save_array_pause)
end