local data = require('data.min')
local battery = require('battery.min')

-- Phone to Frame flags
-- TODO sample messages only
USER_SPRITE = 0x20
CLEAR_MSG = 0x10

-- register the message parsers so they are automatically called when matching data comes in
data.parsers[USER_SPRITE] = sprite.parse_sprite
data.parsers[CLEAR_MSG] = code.parse_code

-- Main app loop
function app_loop()
	-- clear the display
	frame.display.text(" ", 1, 1)
	frame.display.show()
    local last_batt_update = 0

	while true do
		-- process any raw data items, if ready
		local items_ready = data.process_raw_items()

		-- one or more full messages received
		if items_ready > 0 then

			if (data.app_data[USER_SPRITE] ~= nil) then
				-- show the sprite
				local spr = data.app_data[USER_SPRITE]
				frame.display.bitmap(1, 1, spr.width, 2^spr.bpp, 0, spr.pixel_data)
				frame.display.show()

				data.app_data[USER_SPRITE] = nil
			end

			if (data.app_data[CLEAR_MSG] ~= nil) then
				-- clear the display
				frame.display.text(" ", 1, 1)
				frame.display.show()

				data.app_data[CLEAR_MSG] = nil
			end
		end

        -- periodic battery level updates, 120s for a camera app
        last_batt_update = battery.send_batt_if_elapsed(last_batt_update, 120)
		frame.sleep(0.1)
	end
end

-- run the main app loop
app_loop()