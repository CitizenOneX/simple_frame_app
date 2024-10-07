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
	-- exposure maps from 0..255 to -2.0..+2.0
	camera_settings.quality = quality_values[string.byte(data, 1) + 1]
	camera_settings.auto_exp_gain_times = string.byte(data, 2)
	camera_settings.metering = metering_values[string.byte(data, 3) + 1]
	camera_settings.exposure = string.byte(data, 4) / 255.0
	camera_settings.exposure_speed = string.byte(data, 5) / 255.0
	camera_settings.shutter_limit = string.byte(data, 6) << 8 | string.byte(data, 7)
	camera_settings.analog_gain_limit = string.byte(data, 8)
	camera_settings.white_balance_speed = string.byte(data, 9) / 255.0
	return camera_settings
end

function _M.camera_capture_and_send(args)
	quality = args.quality or 50
	auto_exp_gain_times = args.auto_exp_gain_times or 0
	metering = args.metering or 'AVERAGE'
	exposure = args.exposure or 0.18
	exposure_speed = args.exposure_speed or 0.5
	shutter_limit = args.shutter_limit or 800
	analog_gain_limit = args.analog_gain_limit or 248.0
	white_balance_speed = args.white_balance_speed or 0.5

	for run=1,auto_exp_gain_times,1 do
		frame.camera.auto { metering = metering, exposure = exposure, exposure_speed = exposure_speed, shutter_limit = shutter_limit, analog_gain_limit = analog_gain_limit, white_balance_speed = white_balance_speed }
		frame.sleep(0.1)
	end

	frame.camera.capture { quality_factor = quality }
	-- wait until the capture is finished and the image is ready before continuing
	while not frame.camera.image_ready() do
		frame.sleep(0.05)
	end

	local bytes_sent = 0

	local data = ''

	while true do
        data = frame.camera.read_raw(frame.bluetooth.max_length() - 4)
        if (data ~= nil) then
            pcall(frame.bluetooth.send, string.char(IMAGE_MSG) .. data)
            bytes_sent = bytes_sent + string.len(data)
            frame.sleep(0.0125)
		else
            pcall(frame.bluetooth.send, string.char(IMAGE_FINAL_MSG))
            frame.sleep(0.0125)
            break
		end
	end
end

return _M