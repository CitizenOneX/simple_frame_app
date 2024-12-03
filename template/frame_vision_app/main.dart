import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:simple_frame_app/frame_vision_app.dart';
import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:simple_frame_app/tx/plain_text.dart';

void main() => runApp(const MainApp());

final _log = Logger("MainApp");

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> with SimpleFrameAppState, FrameVisionAppState {

  // the image and metadata to show
  Image? _image;
  ImageMetadata? _imageMeta;
  bool _processing = false;

  MainAppState() {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  @override
  void initState() {
    super.initState();
    // kick off the connection to Frame and start the app if possible
    tryScanAndConnectAndStart(andRun: true);
  }

  @override
  Future<void> onRun() async {
    await frame!.sendMessage(
      TxPlainText(
        msgCode: 0x0a,
        text: '3-Tap: take photo'
      )
    );
  }

  @override
  Future<void> onCancel() async {
    // app-specific cleanup
  }

  @override
  Future<void> onTap(int taps) async {
    switch (taps) {
      case 1:
        // next
        break;
      case 2:
        // prev
        break;
      case 3:
        // check if there's processing in progress already and drop the request if so
        if (!_processing) {
          _processing = true;
          // start new vision capture
          // asynchronously kick off the capture/processing pipeline
          capture().then(process);
        }
        break;
      default:
    }
  }

  /// The vision pipeline to run when a photo is captured
  FutureOr<void> process((Uint8List, ImageMetadata) photo) async {
    var imageData = photo.$1;
    var meta = photo.$2;

    try {
      // NOTE: Frame camera is rotated 90 degrees clockwise, so if we need to make it upright for image processing.
      // Some processing packages e.g. ML Kit allow us to pass in a rotation parameter
      // but if we need to bake in the correct rotation we can do it like so:
      // import 'package:image/image.dart' as image_lib;
      // image_lib.Image? im = image_lib.decodeJpg(imageData);
      // im = image_lib.copyRotate(im, angle: 270);

      // update Widget UI
      // For the widget we rotate it upon display with a transform, not changing the source image
      Image im = Image.memory(imageData, gaplessPlayback: true,);

      setState(() {
        _image = im;
        _imageMeta = meta;
      });

      // TODO Perform vision processing pipeline on the current image

      // indicate that we're done processing
      _processing = false;

    } catch (e) {
      _log.severe('Error processing photo: $e');
      // TODO rethrow;?
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Vision',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Frame Vision'),
          actions: [getBatteryWidget()]
        ),
        drawer: getCameraDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Transform(
                    alignment: Alignment.center,
                    // images are rotated 90 degrees clockwise from the Frame
                    // so reverse that for display
                    transform: Matrix4.rotationZ(-pi*0.5),
                    child: _image,
                  ),
                  const Divider(),
                  if (_imageMeta != null) _imageMeta!,
                ],
              )
            ),
            const Divider(),
          ],
        ),
        floatingActionButton: getFloatingActionButtonWidget(const Icon(Icons.camera_alt), const Icon(Icons.cancel)),
        persistentFooterButtons: getFooterButtonsWidget(),
      ),
    );
  }
}
