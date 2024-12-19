import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:simple_frame_app/rx/photo.dart';
import 'package:simple_frame_app/rx/tap.dart';
import 'package:simple_frame_app/tx/camera_settings.dart';
import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:simple_frame_app/tx/code.dart';
import 'package:simple_frame_app/tx/plain_text.dart';

final _log = Logger("FVA");

mixin FrameVisionAppState<T extends StatefulWidget> on SimpleFrameAppState<T> {

  final Stopwatch _stopwatch = Stopwatch();

  // camera settings
  int qualityIndex = 0;
  final List<double> qualityValues = [10, 25, 50];
  bool _isAutoExposure = true;

  // autoexposure/gain parameters
  int meteringIndex = 2;
  final List<String> meteringValues = ['SPOT', 'CENTER_WEIGHTED', 'AVERAGE'];
  int autoExpGainTimes = 2; // val >= 0; number of times auto exposure and gain algorithm will be run (every autoExpInterval ms)
  int autoExpInterval = 100; // 0<= val <= 255; sleep time between runs of the autoexposure algorithm
  double exposure = 0.18; // 0.0 <= val <= 1.0
  double exposureSpeed = 0.5;  // 0.0 <= val <= 1.0
  int shutterLimit = 16383; // 4 < val < 16383
  int analogGainLimit = 1;     // 0 (1?) <= val <= 248
  double whiteBalanceSpeed = 0.5;  // 0.0 <= val <= 1.0

  // manual exposure/gain parameters
  int manualShutter = 16383; // 4 < val < 16383
  int manualAnalogGain = 1;     // 0 (1?) <= val <= 248
  int manualRedGain = 64; // 0 <= val <= 1023
  int manualGreenGain = 64; // 0 <= val <= 1023
  int manualBlueGain = 64; // 0 <= val <= 1023

  // tap subscription
  StreamSubscription<int>? _tapSubs;

  /// abstract method that is called at the end of run() to give the implementing class
  /// a chance to print some instructions (or perform some other final setup)
  /// after the tap handler is hooked up
  Future<void> onRun();

  /// abstract method that is called at the start of cancel() to give the implementing class
  /// a chance to perform some cleanup
  Future<void> onCancel();

  /// abstract method that must be implemented by the class mixing in frame_vision_app
  /// to capture a photo and perform some action on a 1-, 2-, 3-, n-tap etc.
  Future<void> onTap(int taps);

  /// Implements simple_frame_app run() by listening for taps
  /// and handing off to a tapHandler() function
  /// in the class that mixes in frame_vision_app.
  /// That function would be expected to call capture() and
  /// then perform processing on the image
  @override
  Future<void> run() async {
    setState(() {
      currentState = ApplicationState.running;
    });

    // listen for taps for e.g. next(1)/prev(2) content and "new capture" (3)
    _tapSubs?.cancel();
    _tapSubs = RxTap().attach(frame!.dataResponse)
      .listen((taps) async {
        _log.fine(() => 'taps: $taps');
        // call the tap handler in the implementing class
        onTap(taps);
      }
    );

    // let Frame know to subscribe for taps and send them to us
    await frame!.sendMessage(TxCode(msgCode: 0x10, value: 1));

    // prompt the user to begin tapping or other app-specific setup
    await onRun();

    // run() completes but we stay in ApplicationState.running because the tap listener is active
  }

  /// request a photo from Frame
  Future<(Uint8List, ImageMetadata)> capture() async {
    try {
      // save a snapshot of the image metadata (camera settings) to show under the image
      ImageMetadata meta;

      if (_isAutoExposure) {
        meta = AutoExpImageMetadata(qualityValues[qualityIndex].toInt(), autoExpGainTimes, autoExpInterval, meteringValues[meteringIndex], exposure, exposureSpeed, shutterLimit, analogGainLimit, whiteBalanceSpeed);
      }
      else {
        meta = ManualExpImageMetadata(qualityValues[qualityIndex].toInt(), manualShutter, manualAnalogGain, manualRedGain, manualGreenGain, manualBlueGain);
      }

      // send the lua command to request a photo from the Frame based on the current settings
      _stopwatch.reset();
      _stopwatch.start();
      // Send the respective settings for autoexposure or manual
      if (_isAutoExposure) {
        await frame!.sendMessage(TxCameraSettings(
          msgCode: 0x0d,
          qualityIndex: qualityIndex,
          autoExpGainTimes: autoExpGainTimes,
          autoExpInterval: autoExpInterval,
          meteringIndex: meteringIndex,
          exposure: exposure,
          exposureSpeed: exposureSpeed,
          shutterLimit: shutterLimit,
          analogGainLimit: analogGainLimit,
          whiteBalanceSpeed: whiteBalanceSpeed,
        ));
      }
      else {
        await frame!.sendMessage(TxCameraSettings(
          msgCode: 0x0d,
          qualityIndex: qualityIndex,
          autoExpGainTimes: 0,
          manualShutter: manualShutter,
          manualAnalogGain: manualAnalogGain,
          manualRedGain: manualRedGain,
          manualGreenGain: manualGreenGain,
          manualBlueGain: manualBlueGain,
        ));
      }
      // synchronously await the image response
      Uint8List imageData = await RxPhoto(qualityLevel: qualityValues[qualityIndex].toInt()).attach(frame!.dataResponse).first;

      // received a whole-image Uint8List with jpeg header and footer included
      _stopwatch.stop();

      // add the size and elapsed time to the image metadata widget
      if (meta is AutoExpImageMetadata) {
        meta.size = imageData.length;
        meta.elapsedTimeMs = _stopwatch.elapsedMilliseconds;
      }
      else if (meta is ManualExpImageMetadata) {
        meta.size = imageData.length;
        meta.elapsedTimeMs = _stopwatch.elapsedMilliseconds;
      }

      _log.fine(() => 'Image file size in bytes: ${imageData.length}, elapsedMs: ${_stopwatch.elapsedMilliseconds}, ${((imageData.length / 1024.0) / (_stopwatch.elapsedMilliseconds / 1000.0)).toStringAsFixed(2)} kB/s');

      return (imageData, meta);

    } catch (e) {
      _log.severe('Error executing application: $e');
      rethrow;
    }
  }

  /// cancel tap-listening state and clear the display
  @override
  Future<void> cancel() async {
    setState(() {
      currentState = ApplicationState.canceling;
    });

    // perform app-specific cleanup
    await onCancel();

    // let Frame know to stop sending taps
    await frame!.sendMessage(TxCode(msgCode: 0x10, value: 0));

    // clear the display
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: ' '));

    setState(() {
      currentState = ApplicationState.ready;
    });
  }

  Drawer getCameraDrawer() {
    return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text('Camera Settings',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
              ),
              ListTile(
                title: const Text('Quality'),
                subtitle: Slider(
                  value: qualityIndex.toDouble(),
                  min: 0,
                  max: qualityValues.length - 1,
                  divisions: qualityValues.length - 1,
                  label: qualityValues[qualityIndex].toString(),
                  onChanged: (value) {
                    setState(() {
                      qualityIndex = value.toInt();
                    });
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Auto Exposure/Gain'),
                value: _isAutoExposure,
                onChanged: (bool value) {
                  setState(() {
                    _isAutoExposure = value;
                  });
                },
                subtitle: Text(_isAutoExposure ? 'Auto' : 'Manual'),
              ),
              if (_isAutoExposure) ...[
                // Widgets visible in Auto mode
                ListTile(
                  title: const Text('Auto Exposure/Gain Runs'),
                  subtitle: Slider(
                    value: autoExpGainTimes.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: autoExpGainTimes.toInt().toString(),
                    onChanged: (value) {
                      setState(() {
                        autoExpGainTimes = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Auto Exposure Interval (ms)'),
                  subtitle: Slider(
                    value: autoExpInterval.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: autoExpInterval.toInt().toString(),
                    onChanged: (value) {
                      setState(() {
                        autoExpInterval = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Metering'),
                  subtitle: DropdownButton<int>(
                    value: meteringIndex,
                    onChanged: (int? newValue) {
                      setState(() {
                        meteringIndex = newValue!;
                      });
                    },
                    items: meteringValues
                        .map<DropdownMenuItem<int>>((String value) {
                      return DropdownMenuItem<int>(
                        value: meteringValues.indexOf(value),
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                ListTile(
                  title: const Text('Exposure'),
                  subtitle: Slider(
                    value: exposure,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: exposure.toString(),
                    onChanged: (value) {
                      setState(() {
                        exposure = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Exposure Speed'),
                  subtitle: Slider(
                    value: exposureSpeed,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: exposureSpeed.toString(),
                    onChanged: (value) {
                      setState(() {
                        exposureSpeed = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Shutter Limit'),
                  subtitle: Slider(
                    value: shutterLimit.toDouble(),
                    min: 4,
                    max: 16383,
                    divisions: 10,
                    label: shutterLimit.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        shutterLimit = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Analog Gain Limit'),
                  subtitle: Slider(
                    value: analogGainLimit.toDouble(),
                    min: 0,
                    max: 248,
                    divisions: 8,
                    label: analogGainLimit.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        analogGainLimit = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('White Balance Speed'),
                  subtitle: Slider(
                    value: whiteBalanceSpeed,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: whiteBalanceSpeed.toString(),
                    onChanged: (value) {
                      setState(() {
                        whiteBalanceSpeed = value;
                      });
                    },
                  ),
                ),
              ] else ...[
                // Widgets visible in Manual mode
                ListTile(
                  title: const Text('Manual Shutter'),
                  subtitle: Slider(
                    value: manualShutter.toDouble(),
                    min: 4,
                    max: 16383,
                    divisions: 100,
                    label: manualShutter.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        manualShutter = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Manual Analog Gain'),
                  subtitle: Slider(
                    value: manualAnalogGain.toDouble(),
                    min: 0,
                    max: 248,
                    divisions: 50,
                    label: manualAnalogGain.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        manualAnalogGain = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Red Gain'),
                  subtitle: Slider(
                    value: manualRedGain.toDouble(),
                    min: 0,
                    max: 1023,
                    divisions: 100,
                    label: manualRedGain.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        manualRedGain = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Green Gain'),
                  subtitle: Slider(
                    value: manualGreenGain.toDouble(),
                    min: 0,
                    max: 1023,
                    divisions: 100,
                    label: manualGreenGain.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        manualGreenGain = value.toInt();
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Blue Gain'),
                  subtitle: Slider(
                    value: manualBlueGain.toDouble(),
                    min: 0,
                    max: 1023,
                    divisions: 100,
                    label: manualBlueGain.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        manualBlueGain = value.toInt();
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        );
  }
}

abstract class ImageMetadata extends StatelessWidget {
  const ImageMetadata({super.key});
}

// ignore: must_be_immutable
class AutoExpImageMetadata extends ImageMetadata {
  final int quality;
  final int exposureRuns;
  final int exposureInterval;
  final String metering;
  final double exposure;
  final double exposureSpeed;
  final int shutterLimit;
  final int analogGainLimit;
  final double whiteBalanceSpeed;

  AutoExpImageMetadata(this.quality, this.exposureRuns, this.exposureInterval, this.metering, this.exposure, this.exposureSpeed, this.shutterLimit, this.analogGainLimit, this.whiteBalanceSpeed, {super.key});

  late int size;
  late int elapsedTimeMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Quality: $quality\nExposureRuns: $exposureRuns\nExpInterval: $exposureInterval\nMetering: $metering'),
        const Spacer(),
        Text('\nExposure: $exposure\nExposureSpeed: $exposureSpeed\nShutterLim: $shutterLimit\nAnalogGainLim: $analogGainLimit'),
        const Spacer(),
        Text('\nWBSpeed: $whiteBalanceSpeed\nSize: ${(size/1024).toStringAsFixed(1)} kb\nTime: $elapsedTimeMs ms'),
      ],
    );
  }
}

// ignore: must_be_immutable
class ManualExpImageMetadata extends ImageMetadata {
  final int quality;
  final int shutter;
  final int analogGain;
  final int redGain;
  final int greenGain;
  final int blueGain;

  ManualExpImageMetadata(this.quality, this.shutter, this.analogGain, this.redGain, this.greenGain, this.blueGain, {super.key});

  late int size;
  late int elapsedTimeMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Quality: $quality\nShutter: $shutter\nAnalogGain: $analogGain'),
        const Spacer(),
        Text('RedGain: $redGain\nGreenGain: $greenGain\nBlueGain: $blueGain'),
        const Spacer(),
        Text('Size: ${(size/1024).toStringAsFixed(1)} kb\nTime: $elapsedTimeMs ms'),
      ],
    );
  }
}