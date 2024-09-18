import 'dart:typed_data';

abstract class TxMsg {
  final int _msgCode;

  /// The base class for all Tx (transmit phone to frame) messages that can be sent using sendMessage()
  /// which performs splitting across multiple MTU-sized packets
  /// an assembled automatically frameside by the data handler.
  TxMsg({required int msgCode}) : _msgCode = msgCode;

  int get msgCode => _msgCode;

  /// pack() should produce a message data payload that can be parsed by a corresponding
  /// parser in the frameside application (Lua)
  /// TxMsg needs to know its own message code, but it is not included in the payload bytes
  /// returned by pack; the 0x01 data byte and the msgCode byte are
  /// prepended to each bluetooth write() call by the sendDataRaw method,
  /// followed by the maximum amount of payload data that will fit until the whole message is sent.
  Uint8List pack();
}
