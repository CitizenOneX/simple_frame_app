import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:logging/logging.dart';
import 'package:simple_frame_app/src/jpeg_headers.dart';

final _log = Logger("RxPhoto");

/// Returns a photo as a JPEG image from Frame.
/// Note: The camera sensor on Frame is rotated 90 degrees clockwise, so raw images are rotated, but by default
/// RxPhoto will correct this by rotating -90 degrees.
/// If you want to save the cost of copyRotate here you can specify upright=false in the constructor
/// since some ML packages allow for specifying the orientation of the image when passing it in.
/// Pairs with frame.camera.read_raw(), that is, jpeg header and footer
/// are not sent from Frame - only the content, using non-final and final message types
/// Jpeg header and footer are added in here on the client, so a quality level
/// must be provided to select the correct header. Returns a Stream with exactly one jpeg as bytes, then is Done
class RxPhoto {

  // Frame to Phone flags
  final int nonFinalChunkFlag;
  final int finalChunkFlag;
  final int qualityLevel;
  final bool upright;
  StreamController<Uint8List>? _controller;

  /// qualityLevel must be valid (10, 25, 50, 100)
  RxPhoto({
    this.nonFinalChunkFlag = 0x07,
    this.finalChunkFlag = 0x08,
    this.qualityLevel = 10,
    this.upright = true,
  });

  /// Attach this RxPhoto to the Frame's dataResponse characteristic stream.
  Stream<Uint8List> attach(Stream<List<int>> dataResponse) {
    // TODO check for illegal state - attach() already called on this RxPhoto etc?
    // might be possible though after a clean close(), do I want to prevent it?

    // qualityLevel must be valid (10, 25, 50, 100)
    if (!jpegHeaderMap.containsKey(qualityLevel)) {
      throw Exception(
          'Invalid quality level for jpeg: $qualityLevel - must be one of: ${jpegHeaderMap.keys}');
    }

    // the image data as a list of bytes that accumulates with each packet
    List<int> imageData = List.empty(growable: true);
    int rawOffset = 0;

    // add the jpeg header bytes for this quality level (623 bytes)
    imageData.addAll(jpegHeaderMap[qualityLevel]!);

    // the subscription to the underlying data stream
    StreamSubscription<List<int>>? dataResponseSubs;

    // Our stream controller that transforms/accumulates the raw data into images (as bytes)
    _controller = StreamController();

    _controller!.onListen = () {
      _log.fine('ImageDataResponse stream subscribed');
      dataResponseSubs = dataResponse
          .where(
              (data) => data[0] == nonFinalChunkFlag || data[0] == finalChunkFlag)
          .listen((data) {
        if (data[0] == nonFinalChunkFlag) {
          imageData += data.sublist(1);
          rawOffset += data.length - 1;
        }
        // the last chunk has a first byte of 8 so stop after this
        else if (data[0] == finalChunkFlag) {
          imageData += data.sublist(1);
          rawOffset += data.length - 1;

          // add the jpeg footer bytes (2 bytes)
          imageData.addAll(jpegFooter);

          // When full image data is received,
          // rotate the image counter-clockwise 90 degrees to make it upright
          // unless requested otherwise (to save processing)
          if (upright) {
            image_lib.Image? im = image_lib.decodeJpg(Uint8List.fromList(imageData));
            im = image_lib.copyRotate(im!, angle: 270);
            // emit the rotated jpeg bytes
            _controller!.add(image_lib.encodeJpg(im));
          }
          else {
            // emit the original rotation jpeg bytes
            _controller!.add(Uint8List.fromList(imageData));
          }

          // clear the buffer
          imageData.clear();
          rawOffset = 0;

          // and close the stream
          _controller!.close();
        }
        _log.finer(() => 'Chunk size: ${data.length - 1}, rawOffset: $rawOffset');
      }, onDone: _controller!.close, onError: _controller!.addError);
      _log.fine('Controller being listened to');
    };

    _controller!.onCancel = () {
      _log.fine('ImageDataResponse stream unsubscribed');
      dataResponseSubs?.cancel();
      _controller!.close();
    };

    return _controller!.stream;
  }
}