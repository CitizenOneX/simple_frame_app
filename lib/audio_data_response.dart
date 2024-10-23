import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger("AudioDR");

// Frame to Phone flags
const nonFinalChunkFlag = 0x05;
const finalChunkFlag = 0x06;

/// Audio data stream with a single element of a raw audio clip
/// (using non-final and final message types to accumulate from Frame)
@Deprecated('Use RxAudio.attach()')
Stream<Uint8List> audioDataResponse(Stream<List<int>> dataResponse) {

  // the image data as a list of bytes that accumulates with each packet
  BytesBuilder audioData = BytesBuilder(copy: false);
  int rawOffset = 0;

  // the subscription to the underlying data stream
  StreamSubscription<List<int>>? dataResponseSubs;

  // Our stream controller that transforms/accumulates the raw data into audio (as bytes)
  StreamController<Uint8List> controller = StreamController();

  controller.onListen = () {
    _log.fine('AudioDataResponse stream subscribed');
    dataResponseSubs = dataResponse
        .where(
            (data) => data[0] == nonFinalChunkFlag || data[0] == finalChunkFlag)
        .listen((data) {
      if (data[0] == nonFinalChunkFlag) {
        _log.finer(() => 'Non-final: ${data.length}');
        audioData.add(UnmodifiableListView(data.skip(1)));
        rawOffset += data.length - 1;
      }
      // the last chunk has a first byte of 8 so stop after this
      else if (data[0] == finalChunkFlag) {
        _log.finer(() => 'Final: ${data.length}');
        audioData.add(UnmodifiableListView(data.skip(1)));
        rawOffset += data.length - 1;

        // When full audio data is received, emit it and clear the buffer
        controller.add(audioData.takeBytes());
        rawOffset = 0;

        // and close the stream
        controller.close();
      }
      _log.finer(() => 'Chunk size: ${data.length - 1}, rawOffset: $rawOffset');
    }, onDone: controller.close, onError: controller.addError);
  };

  controller.onCancel = () {
    _log.fine('AudioDataResponse stream unsubscribed');
    dataResponseSubs?.cancel();
    controller.close();
  };

  return controller.stream;
}

/// Real-time Audio data stream
/// A listener can subscribe and unsubscribe and resubscribe to the returned broadcast Stream
/// multiple times. The Stream only is Done when the final chunk message code is sent
/// from Frame
@Deprecated('Use RxAudio(streaming: true).attach')
Stream<Uint8List> audioDataStreamResponse(Stream<List<int>> dataResponse) {

  // the subscription to the underlying data stream
  StreamSubscription<List<int>>? dataResponseSubs;

  // Our stream controller that transforms/accumulates the raw data into audio (as bytes)
  // It needs to be a broadcast stream so users can subscribe, unsubscribe, then resubscribe
  // to the same stream
  StreamController<Uint8List> controller = StreamController.broadcast();

  controller.onListen = () {
    _log.fine('AudioDataResponse stream subscribed');
    dataResponseSubs?.cancel();
    dataResponseSubs = dataResponse
      .where(
          (data) => data[0] == nonFinalChunkFlag || data[0] == finalChunkFlag)
      .listen((data) {
        // start or middle of an audio stream
        if (data[0] == nonFinalChunkFlag) {
          _log.finer(() => 'Non-final: ${data.length}');
          assert(data.length % 2 == 1); // whole 16-bit pcm samples only (plus msgCode in data[0] makes it odd)
          controller.add(Uint8List.fromList(data.skip(1).toList()));
        }
        // the last chunk has a first byte of finalChunkFlag so stop after this
        else if (data[0] == finalChunkFlag) {

          _log.finer(() => 'Final: ${data.length}');

          if (data.length > 1) {
            controller.add(Uint8List.fromList(data.skip(1).toList()));
          }

          // upstream is done so close the downstream
          _log.fine('About to close AudioDataResponse stream');
          controller.close();
          _log.fine('AudioDataResponse stream closed');
        }
        // close or pass on errors if the upstream dataResponse closes/errors
      }, onDone: controller.close, onError: controller.addError);
  };

  controller.onCancel = () {
    _log.fine('AudioDataResponse stream unsubscribed');
    // unsubscribe from upstream dataResponse
    dataResponseSubs?.cancel();

    // don't close the controller, if the listener re-subscribes
    // then we continue sending data
  };

  return controller.stream;
}
