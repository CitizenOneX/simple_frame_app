-- Module to parse Sprites sent from phoneside app as TxImageSpriteBlock messages
_M = {}

-- Parse the image sprite block message raw data. Unpack the header fields.
-- width(Uint16), height(Uint16), sprite_line_height(Uint16), progressive_render(bool as Uint8), updatable(bool as Uint8)
function _M.parse_image_sprite_block(data, prev)
	if string.byte(data, 1) == 0xFF then
		-- new block
		local image_sprite_block = {}
		image_sprite_block.width = string.byte(data, 2) << 8 | string.byte(data, 3)
		image_sprite_block.height = string.byte(data, 4) << 8 | string.byte(data, 5)
		image_sprite_block.sprite_line_height = string.byte(data, 6) << 8 | string.byte(data, 7)
		image_sprite_block.progressive_render = string.byte(data, 8) == 1
		image_sprite_block.updatable = string.byte(data, 9) == 1
		image_sprite_block.sprites = {}
		image_sprite_block.total_sprites = (image_sprite_block.height + image_sprite_block.sprite_line_height - 1) // image_sprite_block.sprite_line_height
		image_sprite_block.active_sprites = 0
		image_sprite_block.current_sprite_index = 0
		return image_sprite_block
	-- Otherwise this is a TxSprite, so parse it
	else
		-- no existing ImageSpriteBlock to accumulate into, drop this sprite
		if prev == nil then
			return nil
		end

		-- increment our counters (and index into sprites table)
		prev.current_sprite_index = prev.current_sprite_index + 1
		if prev.current_sprite_index > prev.total_sprites then
			if prev.updatable then
				-- image sprite block is getting updated, return to first sprite
				prev.current_sprite_index = 1
			else
				-- not updatable, drop this sprite
				return prev
			end
		end

		-- we just accumulate up to total_sprites then stop
		if prev.active_sprites < prev.total_sprites then
			prev.active_sprites = prev.active_sprites + 1
		end

		-- new text sprite line
		local sprite = {}
		sprite.width = string.byte(data, 1) << 8 | string.byte(data, 2)
		sprite.height = string.byte(data, 3) << 8 | string.byte(data, 4)
		sprite.bpp = string.byte(data, 5)
		sprite.num_colors = string.byte(data, 6)
		sprite.palette_data = string.sub(data, 7, 7 + sprite.num_colors * 3 - 1)
		sprite.pixel_data = string.sub(data, 7 + sprite.num_colors * 3)

		-- add this sprite to the current slot
		prev.sprites[prev.current_sprite_index] = sprite

		return prev
	end
end

return _M