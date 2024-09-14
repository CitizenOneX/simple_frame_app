import 'dart:convert';
import 'dart:typed_data';

import 'package:simple_frame_app/tx_msg.dart';

/// A message containing the msgCode and a String of plain text
/// without any font, formatting or layout information
class TxPlainText extends TxMsg {
  final String _text;

  TxPlainText({required super.msgCode, required String text}) : _text = text;

  @override
  Uint8List pack() => utf8.encode(_text);
}