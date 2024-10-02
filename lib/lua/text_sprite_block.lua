-- Module to parse Sprites sent from phoneside app as TxTextSpriteBlock messages
_M = {}

-- Parse the text sprite block message raw data. Unpack the header fields.
-- width(Uint16), height(Uint16), lines(Uint8), [x_offset (Uint16), y_offset (Uint16)] * lines
function _M.parse_text_sprite_block(data, prev)
	if string.byte(data, 1) == 0xFF then
		-- new block
		local text_sprite_block = {}
		text_sprite_block.width = string.byte(data, 2) << 8 | string.byte(data, 3)
		text_sprite_block.height = string.byte(data, 4) << 8 | string.byte(data, 5)
		text_sprite_block.lines = string.byte(data, 6)
		-- for each line, parse the offsets
		local offsets = {}
		for i=0,text_sprite_block.lines-1 do
			local xy = {}
			xy.x = string.byte(data, 6+(4*i)+1) << 8 | string.byte(data, 6+(4*i)+2)
			xy.y = string.byte(data, 6+(4*i)+3) << 8 | string.byte(data, 6+(4*i)+4)
			table.insert(offsets, xy)
		end
		text_sprite_block.offsets = offsets
		text_sprite_block.sprites = {}
		return text_sprite_block
	else
		-- new text sprite line
		local sprite = {}
		sprite.width = string.byte(data, 1) << 8 | string.byte(data, 2)
		sprite.height = string.byte(data, 3) << 8 | string.byte(data, 4)
		sprite.bpp = string.byte(data, 5)
		sprite.num_colors = string.byte(data, 6)
		sprite.palette_data = string.sub(data, 7, 7 + sprite.num_colors * 3 - 1)
		sprite.pixel_data = string.sub(data, 7 + sprite.num_colors * 3)

		table.insert(prev.sprites, sprite)

		return prev
	end
end

return _M