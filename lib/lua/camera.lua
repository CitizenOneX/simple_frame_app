-- Module to encapsulate taking and sending photos as simple frame app messages
local _M = {}

-- Frame to phone flags
local IMAGE_MSG = 0x07
local IMAGE_FINAL_MSG = 0x08

-- local state to capture the stateful camera settings
local quality_values = {'VERY_LOW', 'LOW', 'MEDIUM', 'HIGH', 'VERY_HIGH'}
local metering_values = {'SPOT', 'CENTER_WEIGHTED', 'AVERAGE'}

-- default settings
local auto_exp_settings = {
	metering = 'AVERAGE',
	exposure = 0.18,
	exposure_speed = 0.5,
	shutter_limit = 800,
	analog_gain_limit = 248.0,
	white_balance_speed = 0.5
}

local manual_exp_settings = {
	shutter = 800,
	analog_gain = 100,
	red_gain = 512,
	green_gain = 512,
	blue_gain = 512
}

-- auto/manual status, accessible outside the module
_M.is_auto_exp = true

-- helper function to update settings if they are present (otherwise keep defaults)
function update_if_present(settings, updates)
    for k, v in pairs(updates) do
        if v ~= nil then
            settings[k] = v
        end
    end
end

-- Update the saved auto exposure settings with the provided args
-- The caller still needs to _M.run_auto_exposure() every 100ms after this
function _M.set_auto_exp_settings(args)
	update_if_present(auto_exp_settings, args)
	_M.is_auto_exp = true
end

-- Turns off auto exposure flag if present and updates the manual exposure settings with the provided args
-- Sets the manual exposure settings into the camera using the low level functions
function _M.set_manual_exp_settings(args)
	_M.is_auto_exp = false
	update_if_present(manual_exp_settings, args)

	-- actually update the state of the camera
	frame.camera.set_shutter(manual_exp_settings.shutter)
	frame.camera.set_gain(manual_exp_settings.analog_gain)
	frame.camera.set_white_balance(manual_exp_settings.red_gain, manual_exp_settings.green_gain, manual_exp_settings.blue_gain)
end

-- parse the auto exposure settings message from the host into a table we can use with set_auto_exp_settings()
function _M.parse_auto_exp_settings(data)
	local settings = {}

	settings.metering = metering_values[string.byte(data, 1) + 1]
	settings.exposure = string.byte(data, 2) / 255.0
	settings.exposure_speed = string.byte(data, 3) / 255.0
	settings.shutter_limit = string.byte(data, 4) << 8 | string.byte(data, 5) & 0x3FFF
	settings.analog_gain_limit = string.byte(data, 6) & 0xFF
	settings.white_balance_speed = string.byte(data, 7) / 255.0

	return settings
end

-- parse the manual exposure settings message from the host into a table we can use with set_manual_exp_settings()
function _M.parse_manual_exp_settings(data)
	local settings = {}

    settings.shutter = string.byte(data, 1) << 8 | string.byte(data, 2) & 0x3FFF
	settings.analog_gain = string.byte(data, 3) & 0xFF
	settings.red_gain = string.byte(data, 4) << 8 | string.byte(data, 5) & 0x3FF
	settings.green_gain = string.byte(data, 6) << 8 | string.byte(data, 7) & 0x3FF
	settings.blue_gain = string.byte(data, 8) << 8 | string.byte(data, 9) & 0x3FF

	return settings
end

-- parse the capture settings message from the host into a table we can use with the capture_and_send function
function _M.parse_capture_settings(data)

	local settings = {}
	-- quality and metering mode are indices into arrays of values (0-based phoneside; 1-based in Lua)
	settings.quality = quality_values[string.byte(data, 1) + 1]
	local half_res = string.byte(data, 2) << 8 | string.byte(data, 3)
	settings.resolution = half_res * 2
	local pan_shifted = string.byte(data, 4) << 8 | string.byte(data, 5)
	settings.pan = pan_shifted - 140
	settings.raw = string.byte(data, 6) > 0

	return settings
end

-- send data with retries and no sleeps, bail after 2 seconds
function send_data(data)
	local sent = false
	local retry_count = 0
	-- 2 second time limit for this packet else bail out
	local try_until = frame.time.utc() + 2

	while frame.time.utc() < try_until do
		if pcall(frame.bluetooth.send, data) then
			sent = true
			break
		else
			retry_count = retry_count + 1
		end
	end

	--if retry_count > 0 then
	--	print('retries: ' .. tostring(retry_count))
	--end

	if not sent then
		error('Error sending photo data')
	end
end

-- Runs the auto exposure algorithm with the current settings (call this every 100ms)
function _M.run_auto_exposure()
	frame.camera.auto{auto_exp_settings}
end

-- takes a capture_settings table and sends the image data to the host
function _M.capture_and_send(args)
	frame.camera.capture { resolution=args.resolution, quality=args.quality, pan=args.pan }

	-- wait until the capture is finished and the image is ready before continuing
	while not frame.camera.image_ready() do
		frame.sleep(0.005)
	end

	local data = ''
	local raw = args.raw

	while true do
		-- skip the 623 byte header if the caller requested raw data
		if (raw) then
        	data = frame.camera.read_raw(frame.bluetooth.max_length() - 1)
		else
        	data = frame.camera.read(frame.bluetooth.max_length() - 1)
		end

        if (data ~= nil) then
			send_data(string.char(IMAGE_MSG) .. data)
		else
			send_data(string.char(IMAGE_FINAL_MSG))
			break
		end
	end
end

return _M