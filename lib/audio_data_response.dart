import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger("AudioDR");

// Frame to Phone flags
const nonFinalChunkFlag = 0x05;
const finalChunkFlag = 0x06;

/// Audio data stream using non-final and final message types
Stream<Uint8List> audioDataResponse(Stream<List<int>> dataResponse) {

  // the image data as a list of bytes that accumulates with each packet
  BytesBuilder audioData = BytesBuilder(copy: false);
  int rawOffset = 0;

  // the subscription to the underlying data stream
  StreamSubscription<List<int>>? dataResponseSubs;

  // Our stream controller that transforms/accumulates the raw data into audio (as bytes)
  StreamController<Uint8List> controller = StreamController();

  controller.onListen = () {
    dataResponseSubs = dataResponse
        .where(
            (data) => data[0] == nonFinalChunkFlag || data[0] == finalChunkFlag)
        .listen((data) {
      if (data[0] == nonFinalChunkFlag) {
        _log.finer('Non-final: ${data.length}');
        // pity that BytesBuilder doesn't take an Iterable<int> so I can't use data.skip(1), so the List is copied into a new List before being iterated over anyway
        audioData.add(data.sublist(1));
        rawOffset += data.length - 1;
      }
      // the last chunk has a first byte of 8 so stop after this
      else if (data[0] == finalChunkFlag) {
        _log.finer('Final: ${data.length}');
        audioData.add(data.sublist(1));
        rawOffset += data.length - 1;

        // When full audio data is received, emit it and clear the buffer
        controller.add(audioData.takeBytes());
        rawOffset = 0;
      }
      _log.finer('Chunk size: ${data.length - 1}, rawOffset: $rawOffset');
    }, onDone: controller.close, onError: controller.addError);
    _log.fine('Controller being listened to');
  };

  controller.onCancel = () {
    dataResponseSubs?.cancel();
    controller.close();
    _log.fine('Controller cancelled');
  };

  return controller.stream;
}
