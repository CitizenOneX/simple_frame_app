import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger("RxIMU");

/// IMU data stream, returns raw 3-axis magnetometer and 3-axis accelerometer data
/// and optionally computes derived values
/// Note, a proper calculation of Heading requires magnetometer calibration,
/// tilt compensation (which we can do here from the accelerometer), and magnetic
/// declination adjustment (which is lat-long and time-dependent).
/// Magnetometer calibration and declination adjustments need to be done outside this class.
class RxIMU {

  // Frame to Phone flags
  final int imuFlag;
  StreamController<IMUData>? _controller;

  RxIMU({
    this.imuFlag = 0x0A,
  });

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

          _controller!.add(IMUData(
            // parse out the raw values into (x,y,z) records for compass and accel
            compass: (s16[0], s16[1], s16[2]),
            accel: (s16[3], s16[4], s16[5]),
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

class IMUData {
  final (int x, int y, int z) compass;
  final (int x, int y, int z) accel;

  IMUData({
    required this.compass,
    required this.accel
  });

  double get pitch => atan2(accel.$2, accel.$3) * 180.0 / pi;
  double get roll => atan2(accel.$1, accel.$3) * 180.0 / pi;
}