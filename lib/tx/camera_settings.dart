import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing the msgCode and a collection of camera settings suitable for requesting
/// the frameside app to take a photo with the specified settings
class TxCameraSettings extends TxMsg {
  final int _qualityIndex;
  final int _autoExpGainTimes;
  final int _meteringModeIndex;
  final double _exposure;
  final double _shutterKp;
  final int _shutterLimit;
  final double _gainKp;
  final int _gainLimit;

  TxCameraSettings(
      {required super.msgCode,
      int qualityIndex = 2, // [10, 25, 50, 100];
      int autoExpGainTimes =
          0, // val >= 0; number of times auto exposure and gain algorithm will be run every 100ms
      int meteringModeIndex = 0, // ['SPOT', 'CENTER_WEIGHTED', 'AVERAGE'];
      double exposure = 0.0, // -2.0 <= val <= 2.0
      double shutterKp = 0.1, // val >= 0 (we offer 0.1 .. 0.5)
      int shutterLimit = 6000, // 4 < val < 16383
      double gainKp = 1.0, // val >= 0 (we offer 1.0 .. 5.0)
      int gainLimit = 248}) // 0 <= val <= 248
      : _qualityIndex = qualityIndex,
        _autoExpGainTimes = autoExpGainTimes,
        _meteringModeIndex = meteringModeIndex,
        _exposure = exposure,
        _shutterKp = shutterKp,
        _shutterLimit = shutterLimit,
        _gainKp = gainKp,
        _gainLimit = gainLimit;

  @override
  Uint8List pack() {
    // exposure is a double in the range -2.0 to 2.0, so map that to an unsigned byte 0..255
    // by multiplying by 64, adding 128 and truncating
    int intExp;
    if (_exposure >= 2.0) {
      intExp = 255;
    } else if (_exposure <= -2.0) {
      intExp = 0;
    } else {
      intExp = ((_exposure * 64) + 128).floor();
    }

    int intShutKp = (_shutterKp * 10).toInt() & 0xFF;
    int intShutLimMsb = (_shutterLimit >> 8) & 0xFF;
    int intShutLimLsb = _shutterLimit & 0xFF;
    int intGainKp = (_gainKp * 10).toInt() & 0xFF;

    // 9 bytes of camera settings. sendMessage will prepend the data byte, msgCode to each packet
    // and the Uint16 payload length to the first packet
    return Uint8List.fromList([
      _qualityIndex & 0xFF,
      _autoExpGainTimes & 0xFF,
      _meteringModeIndex & 0xFF,
      intExp,
      intShutKp,
      intShutLimMsb,
      intShutLimLsb,
      intGainKp,
      _gainLimit & 0xFF
    ]);
  }
}
