import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing only the msgCode and no additional data
/// suitable for signalling the frameside app to take some action
/// (e.g. toggle streaming, take a photo with default parameters etc.)
class TxCode extends TxMsg {
  TxCode({required super.msgCode});

  @override
  Uint8List pack() => Uint8List(0);
}