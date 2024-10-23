## 0.0.1

* Early prototypes

## 0.0.6

* Added `TxTextSpriteBlock` message type to send a paragraph of text for display on Frame. Supports Unicode (including right-to-left) script. Rasterization is performed phoneside and text is sent as a series of TxSprites
* Renamed `tx/text.dart` and `lua/text.lua` to `plain_text` to match class names - no interface change, just update imports/assets

## 0.0.7

* Updated camera code (lua and dart) with camera parameters from recent firmware updates - exposure_speed, analog_gain_limit, white_balance_speed etc.

## 0.0.8

* Added initial `audioDataResponse` support for Frame audio data as whole audio clips

## 0.0.9

* Added `audioDataStreamResponse` support for real-time streaming of Frame audio data
* Added `tapDataReponse` as a multi-tap-detection subscription from Frame
* Added `wrapTextSplit` and deprecated `wrapText` in `TextUtils`, returning a `List<String>` instead of a `String` so the caller to quickly select the first, last or a sliding window of Strings to enable scrolling. If a newline-joined single String is desired, it can quickly be assembled with a `join()`
* Performance: modified logging calls with expensive string interpolations to use a closure so they are not evaluated if not logged at the current logging level

## 0.1.0

* Added `Rx` classes in place of `imageDataResponse`, `audioDataResponse`, `tapDataResponse`.
* Deprecated `TextUtils.wrapText(Split)`, going forward use the `wrapText` that returns a List of Strings and join them if you need the single String