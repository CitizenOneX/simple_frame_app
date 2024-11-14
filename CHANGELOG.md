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

## 1.0.0

* removed deprecated `*DataResponse` functions, use `Rx` classes instead (`RxAudio`, `RxPhoto`, `RxTap`)

## 1.0.1

* fixed `TextUtils` to change `wrapTextSplit` to `wrapText`, i.e. `wrapText` now returns `List<String>`, so `join('\n')` the result if a single string is required

## 1.1.0

* implemented `TxTextSpriteBlock` more fully to support multi-line text, including scrolling frameside when the number of lines sent exceeds maxDisplayRows. The call to `rasterize()` has been updated to require providing indices for lines to rasterize.

## 1.1.1

* removed extra logging statements in `text_sprite_block.lua`

## 1.2.0

* Updated TxCameraSettings and camera.lua to support both autoexposure and manual exposure/gain photos

## 1.3.0

* Added TxImageSpriteBlock for splitting an image into lines of TxSprite, allowing for progressive/incremental rendering. Also supports in-place updates of sprite lines for continuously updating images.

## 1.4.0

* Added RxIMU parser and corresponding frameside sender for streaming magnetometer (compass) and accelerometer data from Frame

## 1.4.1

* Tweaked Lua source file for image_sprite_block to prevent a bug introduced by the minifier stripping out necessary parentheses

## 1.5.0

* Added simple moving average smoothing option for IMU data

## 1.5.1

* Corrected 'GRAY' to 'GRAY' for plain_text display to match firmware

## 1.6.0

* Added rudimentary support for TxSprite.fromImageBytes() to load arbitrary PNG or JPG files for display on Frame (previously limited to indexed PNG files of 2, 4, or 16 colors only)