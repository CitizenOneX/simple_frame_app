import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger("RxIMU");

/// Buffer class to allow us to provide a smoothed moving average of samples
class SensorBuffer {
  final int maxSize;
  final List<(int x, int y, int z)> _buffer = [];

  SensorBuffer(this.maxSize);

  void add((int x, int y, int z) value) {
    _buffer.add(value);
    if (_buffer.length > maxSize) {
      _buffer.removeAt(0);
    }
  }

  (int x, int y, int z) get average {
    if (_buffer.isEmpty) return (0, 0, 0);

    int sumX = 0, sumY = 0, sumZ = 0;
    for (var value in _buffer) {
      sumX += value.$1;
      sumY += value.$2;
      sumZ += value.$3;
    }
    return (
      (sumX ~/ _buffer.length),
      (sumY ~/ _buffer.length),
      (sumZ ~/ _buffer.length)
    );
  }
}

/// IMU data stream, returns raw 3-axis magnetometer and 3-axis accelerometer data
/// and optionally computes derived values
/// Note, a proper calculation of Heading requires magnetometer calibration,
/// tilt compensation (which we can do here from the accelerometer), and magnetic
/// declination adjustment (which is lat-long and time-dependent).
/// Magnetometer calibration and declination adjustments need to be done outside this class.
class RxIMU {
  final int _smoothingSamples;

  // Frame to Phone flags
  final int imuFlag;
  StreamController<IMUData>? _controller;

  // Buffers for smoothing
  late final SensorBuffer _compassBuffer;
  late final SensorBuffer _accelBuffer;

  RxIMU({
    this.imuFlag = 0x0A,
    int smoothingSamples = 1,
  }) : _smoothingSamples = smoothingSamples {
    _compassBuffer = SensorBuffer(_smoothingSamples);
    _accelBuffer = SensorBuffer(_smoothingSamples);
  }

  /// Attach this RxIMU to the Frame's dataResponse characteristic stream.
  Stream<IMUData> attach(Stream<List<int>> dataResponse) {
    // TODO check for illegal state - attach() already called on this RxIMU etc?
    // might be possible though after a clean close(), do I want to prevent it?

    // the subscription to the underlying data stream
    StreamSubscription<List<int>>? dataResponseSubs;

    // Our stream controller that transforms the dataResponse elements into IMUData events
    _controller = StreamController();

    _controller!.onListen = () {
      dataResponseSubs = dataResponse
        .where((data) => data[0] == imuFlag)
        .listen((data) {
          Uint8List bytes = Uint8List.fromList(data);
          // reinterpret the bytes after offset 2 as signed 16-bit integers
          Int16List s16 = bytes.buffer.asInt16List(2);

          // Get raw values
          var rawCompass = (s16[0], s16[1], s16[2]);
          var rawAccel = (s16[3], s16[4], s16[5]);

          // Add to buffers
          _compassBuffer.add(rawCompass);
          _accelBuffer.add(rawAccel);

          _controller!.add(IMUData(
            compass: _compassBuffer.average,
            accel: _accelBuffer.average,
            raw: IMURawData(
              compass: rawCompass,
              accel: rawAccel,
            ),
          ));

      }, onDone: _controller!.close, onError: _controller!.addError);
      _log.fine('ImuDataResponse stream subscribed');
    };

    _controller!.onCancel = () {
      _log.fine('ImuDataResponse stream unsubscribed');
      dataResponseSubs?.cancel();
      _controller!.close();
    };

    return _controller!.stream;
  }
}

class IMURawData {
  final (int x, int y, int z) compass;
  final (int x, int y, int z) accel;

  IMURawData({
    required this.compass,
    required this.accel,
  });
}

class IMUData {
  final (int x, int y, int z) compass;
  final (int x, int y, int z) accel;
  final IMURawData? raw;

  IMUData({
    required this.compass,
    required this.accel,
    this.raw,
  });

  double get pitch => atan2(accel.$2, accel.$3) * 180.0 / pi;
  double get roll => atan2(accel.$1, accel.$3) * 180.0 / pi;
}