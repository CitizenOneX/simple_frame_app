local data = require('data.min')
local battery = require('battery.min')
local camera = require('camera.min')
local code = require('code.min')
local plain_text = require('plain_text.min')

-- Phone to Frame flags
CAMERA_SETTINGS_MSG = 0x0d
TEXT_MSG = 0x0a
TAP_SUBS_MSG = 0x10

-- register the message parser so it's automatically called when matching data comes in
data.parsers[CAMERA_SETTINGS_MSG] = camera.parse_camera_settings
data.parsers[TEXT_MSG] = plain_text.parse_plain_text
data.parsers[TAP_SUBS_MSG] = code.parse_code

-- Frame to Phone flags
TAP_MSG = 0x09

function handle_tap()
	pcall(frame.bluetooth.send, string.char(TAP_MSG))
end

-- draw the current text on the display
function print_text()
    local i = 0
    for line in data.app_data[TEXT_MSG].string:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            frame.display.text(line, 1, i * 60 + 1)
            i = i + 1
        end
    end
end

function clear_display()
    frame.display.text(" ", 1, 1)
    frame.display.show()
    frame.sleep(0.04)
end

-- Main app loop
function app_loop()
	clear_display()
    local last_batt_update = 0

	while true do
        rc, err = pcall(
            function()
				-- process any raw data items, if ready (parse into take_photo, then clear data.app_data_block)
				local items_ready = data.process_raw_items()

				if items_ready > 0 then

					if (data.app_data[CAMERA_SETTINGS_MSG] ~= nil) then
						rc, err = pcall(camera.camera_capture_and_send, data.app_data[CAMERA_SETTINGS_MSG])

						if rc == false then
							print(err)
						end

						data.app_data[CAMERA_SETTINGS_MSG] = nil
					end

					if (data.app_data[TEXT_MSG] ~= nil and data.app_data[TEXT_MSG].string ~= nil) then
						print_text()
						frame.display.show()

						data.app_data[TEXT_MSG] = nil
					end

					if (data.app_data[TAP_SUBS_MSG] ~= nil) then

						if data.app_data[TAP_SUBS_MSG].value == 1 then
							-- start subscription to tap events
							frame.imu.tap_callback(handle_tap)
						else
							-- cancel subscription to tap events
							frame.imu.tap_callback(nil)
						end

						data.app_data[TAP_SUBS_MSG] = nil
					end

				end

				-- periodic battery level updates, 120s for a camera app
				last_batt_update = battery.send_batt_if_elapsed(last_batt_update, 120)
				frame.sleep(0.1)
			end
		)
		-- Catch the break signal here and clean up the display
		if rc == false then
			-- send the error back on the stdout stream
			print(err)
			frame.display.text(" ", 1, 1)
			frame.display.show()
			frame.sleep(0.04)
			break
		end
	end
end

-- run the main app loop
app_loop()