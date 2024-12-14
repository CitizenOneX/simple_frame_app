-- Module to encapsulate taking and sending photos as simple frame app messages
_M = {}

-- Frame to phone flags
local IMAGE_MSG = 0x07
local IMAGE_FINAL_MSG = 0x08

-- parse the camera_settings message from the host into a table we can use with the camera_capture_and_send function
function _M.parse_camera_settings(data)
	local quality_values = {10, 25, 50, 100}
	local metering_values = {'SPOT', 'CENTER_WEIGHTED', 'AVERAGE'}

	local camera_settings = {}
	-- quality and metering mode are indices into arrays of values (0-based phoneside; 1-based in Lua)
	camera_settings.quality = quality_values[string.byte(data, 1) + 1]
	camera_settings.auto = string.byte(data, 2) > 0

	if camera_settings.auto == true then
		camera_settings.auto_exp_gain_times = string.byte(data, 2)
		camera_settings.auto_exp_interval = string.byte(data, 3) / 1000.0
		camera_settings.metering = metering_values[string.byte(data, 4) + 1]
		camera_settings.exposure = string.byte(data, 5) / 255.0
		camera_settings.exposure_speed = string.byte(data, 6) / 255.0
		camera_settings.shutter_limit = string.byte(data, 7) << 8 | string.byte(data, 8) & 0x3FFF
		camera_settings.analog_gain_limit = string.byte(data, 9) & 0xFF
		camera_settings.white_balance_speed = string.byte(data, 10) / 255.0
	else
		camera_settings.manual_shutter = string.byte(data, 11) << 8 | string.byte(data, 12) & 0x3FFF
		camera_settings.manual_analog_gain = string.byte(data, 13) & 0xFF
		camera_settings.manual_red_gain = string.byte(data, 14) << 8 | string.byte(data, 15) & 0x3FF
		camera_settings.manual_green_gain = string.byte(data, 16) << 8 | string.byte(data, 17) & 0x3FF
		camera_settings.manual_blue_gain = string.byte(data, 18) << 8 | string.byte(data, 19) & 0x3FF
	end

	return camera_settings
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

function _M.camera_capture_and_send(args)
	local quality = args.quality or 50

	if args.auto then
		local auto_exp_gain_times = args.auto_exp_gain_times or 0
		local auto_exp_interval = args.auto_exp_interval or 0.1
		local metering = args.metering or 'AVERAGE'
		local exposure = args.exposure or 0.18
		local exposure_speed = args.exposure_speed or 0.5
		local shutter_limit = args.shutter_limit or 800
		local analog_gain_limit = args.analog_gain_limit or 248.0
		local white_balance_speed = args.white_balance_speed or 0.5

		for run=1,auto_exp_gain_times,1 do
			frame.camera.auto { metering = metering, exposure = exposure, exposure_speed = exposure_speed, shutter_limit = shutter_limit, analog_gain_limit = analog_gain_limit, white_balance_speed = white_balance_speed }
			frame.sleep(auto_exp_interval)
		end
	else
		local manual_shutter = args.manual_shutter or 800
		local manual_analog_gain = args.manual_analog_gain or 100
		local manual_red_gain = args.manual_red_gain or 512
		local manual_green_gain = args.manual_green_gain or 512
		local manual_blue_gain = args.manual_blue_gain or 512

		frame.camera.set_shutter(manual_shutter)
		frame.camera.set_gain(manual_analog_gain)
		frame.camera.set_white_balance(manual_red_gain, manual_green_gain, manual_blue_gain)

		-- TODO remove after testing if manual shutter or gain needs a delay to take effect on the first capture after a setting change
		frame.sleep(0.1)
	end

	frame.camera.capture { quality_factor = quality }
	-- wait until the capture is finished and the image is ready before continuing
	while not frame.camera.image_ready() do
		frame.sleep(0.05)
	end

	local data = ''

	while true do
        data = frame.camera.read_raw(frame.bluetooth.max_length() - 1)

        if (data ~= nil) then
			send_data(string.char(IMAGE_MSG) .. data)
		else
			send_data(string.char(IMAGE_FINAL_MSG))
			break
		end
	end
end

return _M