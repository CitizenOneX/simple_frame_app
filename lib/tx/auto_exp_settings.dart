import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing the msgCode and a collection of camera settings suitable for requesting
/// the frameside app enable auto exposure and gain with the specified settings
class TxAutoExpSettings extends TxMsg {
  final int _meteringIndex;
  final double _exposure;
  final double _exposureSpeed;
  final int _shutterLimit;
  final int _analogGainLimit;
  final double _whiteBalanceSpeed;

  TxAutoExpSettings({
      required super.msgCode,
      int meteringIndex = 2, // ['SPOT', 'CENTER_WEIGHTED', 'AVERAGE'];
      double exposure = 0.18, // 0.0 <= val <= 1.0
      double exposureSpeed = 0.5, // 0.0 <= val <= 1.0
      int shutterLimit = 800, // 4 <= val <= 16383
      int analogGainLimit = 248, // 0 <= val <= 248
      double whiteBalanceSpeed = 0.5, // 0.0 <= val <= 1.0
      })
      : _meteringIndex = meteringIndex,
        _exposure = exposure,
        _exposureSpeed = exposureSpeed,
        _shutterLimit = shutterLimit,
        _analogGainLimit = analogGainLimit,
        _whiteBalanceSpeed = whiteBalanceSpeed;

  @override
  Uint8List pack() {
    // several doubles in the range 0 to 1, so map that to an unsigned byte 0..255
    // by multiplying by 255 and rounding
    int intExp = (_exposure * 255).round() & 0xFF;
    int intExpSpeed = (_exposureSpeed * 255).round() & 0xFF;
    int intWhiteBalanceSpeed = (_whiteBalanceSpeed * 255).round() & 0xFF;

    // shutter limit has a range 4..16384 so just map it to a Uint16 over 2 bytes
    int intShutLimMsb = (_shutterLimit >> 8) & 0xFF;
    int intShutLimLsb = _shutterLimit & 0xFF;

    // 7 bytes of auto exposure settings. sendMessage will prepend the data byte & msgCode to each packet
    // and the Uint16 payload length to the first packet
    return Uint8List.fromList([
      _meteringIndex & 0xFF,
      intExp,
      intExpSpeed,
      intShutLimMsb,
      intShutLimLsb,
      _analogGainLimit & 0xFF,
      intWhiteBalanceSpeed,
    ]);
  }
}
