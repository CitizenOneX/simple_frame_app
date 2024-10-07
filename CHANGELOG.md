## 0.0.1

* Early prototypes

## 0.0.6

* Added `TxTextSpriteBlock` message type to send a paragraph of text for display on Frame. Supports Unicode (including right-to-left) script. Rasterization is performed phoneside and text is sent as a series of TxSprites
* Renamed `tx/text.dart` and `lua/text.lua` to `plain_text` to match class names - no interface change, just update imports/assets

## 0.0.7

* updated camera code (lua and dart) with camera parameters from recent firmware updates - exposure_speed, analog_gain_limit, white_balance_speed etc.