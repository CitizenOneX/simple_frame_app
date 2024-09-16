-- Module to parse Sprites sent from phoneside app as TxSprite messages
_M = {}

-- Parse the sprite message raw data. Unpack the header fields.
-- width(Uint16), height(Uint16), bpp(Uint8), numColors(Uint8), palette (Uint8 r, Uint8 g, Uint8 b)*numColors, data (length width x height x bpp/8)
function parse_sprite(data)
	local sprite = {}
	sprite.width = string.byte(data, 1) << 8 | string.byte(data, 2)
	sprite.height = string.byte(data, 3) << 8 | string.byte(data, 4)
	sprite.bpp = string.byte(data, 5)
	sprite.num_colors = string.byte(data, 6)
	sprite.palette_data = string.sub(data, 7, 7 + sprite.num_colors * 3 - 1)
	sprite.pixel_data = string.sub(data, 7 + sprite.num_colors * 3)
	return sprite
end

return _M