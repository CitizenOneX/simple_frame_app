import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing only the msgCode and a single optional byte
/// suitable for signalling the frameside app to take some action
/// (e.g. toggle streaming, take a photo with default parameters etc.)
class TxCode extends TxMsg {
  int value;

  TxCode({required super.msgCode, this.value = 0});

  @override
  Uint8List pack() {
    return Uint8List.fromList([value & 0xFF]);
  }
}
