## 0.0.1

* Early prototypes

## 0.0.6

* Added `TxTextSpriteBlock` message type to send a paragraph of text for display on Frame. Supports Unicode (including right-to-left) script. Rasterization is performed phoneside and text is sent as a series of TxSprites
* Renamed `tx/text.dart` and `lua/text.lua` to `plain_text` to match class names - no interface change, just update imports/assets
