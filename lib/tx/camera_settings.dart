import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing the msgCode and a collection of camera settings suitable for requesting
/// the frameside app to take a photo with the specified settings
class TxCameraSettings extends TxMsg {
  final int _qualityIndex;
  final int _autoExpGainTimes;
  final int _autoExpInterval;
  final int _meteringIndex;
  final double _exposure;
  final double _exposureSpeed;
  final int _shutterLimit;
  final int _analogGainLimit;
  final double _whiteBalanceSpeed;
  final int _manualShutter;
  final int _manualAnalogGain;
  final int _manualRedGain;
  final int _manualGreenGain;
  final int _manualBlueGain;

  TxCameraSettings({
      required super.msgCode,
      int qualityIndex = 0, // [10, 25, 50, 100];
      int autoExpGainTimes =
          5, // val >= 0; number of times auto exposure and gain algorithm will be run every autoExpInterval ms
      int autoExpInterval = 100,
      int meteringIndex = 2, // ['SPOT', 'CENTER_WEIGHTED', 'AVERAGE'];
      double exposure = 0.18, // 0.0 <= val <= 1.0
      double exposureSpeed = 0.5, // 0.0 <= val <= 1.0
      int shutterLimit = 800, // 4 <= val <= 16383
      int analogGainLimit = 248, // 0 <= val <= 248
      double whiteBalanceSpeed = 0.5, // 0.0 <= val <= 1.0
      int manualShutter = 800, // 4 <= val <= 16383
      int manualAnalogGain = 124, // 0 <= val <= 248
      int manualRedGain = 512, // 0 <= val <= 1023
      int manualGreenGain = 512, // 0 <= val <= 1023
      int manualBlueGain = 512, // 0 <= val <= 1023
      })
      : _qualityIndex = qualityIndex,
        _autoExpGainTimes = autoExpGainTimes,
        _autoExpInterval = autoExpInterval,
        _meteringIndex = meteringIndex,
        _exposure = exposure,
        _exposureSpeed = exposureSpeed,
        _shutterLimit = shutterLimit,
        _analogGainLimit = analogGainLimit,
        _whiteBalanceSpeed = whiteBalanceSpeed,
        _manualShutter = manualShutter,
        _manualAnalogGain = manualAnalogGain,
        _manualRedGain = manualRedGain,
        _manualGreenGain = manualGreenGain,
        _manualBlueGain = manualBlueGain;

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

    // manual shutter has a range 4..16384 so just map it to a Uint16 over 2 bytes
    int intManShutterMsb = (_manualShutter >> 8) & 0xFF;
    int intManShutterLsb = _manualShutter & 0xFF;

    // manual color gains have a range 0..1023 so just map them to a Uint16 over 2 bytes
    int intManRedGainMsb = (_manualRedGain >> 8) & 0x03;
    int intManRedGainLsb = _manualRedGain & 0xFF;
    int intManGreenGainMsb = (_manualGreenGain >> 8) & 0x03;
    int intManGreenGainLsb = _manualGreenGain & 0xFF;
    int intManBlueGainMsb = (_manualBlueGain >> 8) & 0x03;
    int intManBlueGainLsb = _manualBlueGain & 0xFF;



    // 19 bytes of camera settings. sendMessage will prepend the data byte, msgCode to each packet
    // and the Uint16 payload length to the first packet
    return Uint8List.fromList([
      _qualityIndex & 0xFF,
      _autoExpGainTimes & 0xFF,
      _autoExpInterval & 0xFF,
      _meteringIndex & 0xFF,
      intExp,
      intExpSpeed,
      intShutLimMsb,
      intShutLimLsb,
      _analogGainLimit & 0xFF,
      intWhiteBalanceSpeed,
      intManShutterMsb,
      intManShutterLsb,
      _manualAnalogGain & 0xFF,
      intManRedGainMsb,
      intManRedGainLsb,
      intManGreenGainMsb,
      intManGreenGainLsb,
      intManBlueGainMsb,
      intManBlueGainLsb,
    ]);
  }
}
