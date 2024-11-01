import 'dart:typed_data';

import 'package:image/image.dart' as img;
import '../tx_msg.dart';
import 'sprite.dart';

class TxImageSpriteBlock extends TxMsg {
  final TxSprite _image;
  int get width => _image.width;
  int get height => _image.height;
  final int _spriteLineHeight;
  int get spriteLineHeight => _spriteLineHeight;

  final List<TxSprite> _spriteLines = [];
  List<TxSprite> get spriteLines => _spriteLines;

  /// After construction, an ImageSpriteBlock should be tested that it has a non-zero number of
  /// sprite lines to send, otherwise it should not be sent
  bool get isEmpty => _spriteLines.isEmpty;

  /// After construction, an ImageSpriteBlock should be tested that it has a non-zero number of
  /// sprite lines to send, otherwise it should not be sent
  bool get isNotEmpty => _spriteLines.isNotEmpty;

  /// Represents an image of a specified size sliced into a number of "sprite lines" of the full width of the image, and the specified height,
  /// and possibly a final sprite line of a different height.
  /// When sending TxImageSpriteBlock to Frame, the sendMessage() will send the header with block dimensions and sprite line height,
  /// and the user then sends each line[] as a TxSprite message with the same msgCode as the Block, and the frame app will use the line height
  /// to place each line. By sending each line separately we can display them as they arrive, as well as reducing overall memory
  /// requirement (each concat() call is smaller).
  /// Sending an ImageSpriteBlock with no lines is not intended usage.
  /// TODO flag for "display all at once or progressively"
  /// TODO flag for "after receiving all the sprite lines, if another sprite line comes then start replacing again from the top"
  /// That is, if the image is part of a stream of same-sized images, sending the sprite lines from a subsequent image
  /// can be made to overwrite the lines from the prior image (as long as a new block header is not sent).
  TxImageSpriteBlock(
    {required super.msgCode,
    required TxSprite image,
    required int spriteLineHeight})
    : _image = image,
      _spriteLineHeight = spriteLineHeight {
        // process the full-sized sprite lines
        for (int i = 0; i < image.height ~/ spriteLineHeight; i++) {
          _spriteLines.add(
            TxSprite(
              msgCode: msgCode,
              width: image.width,
              height: spriteLineHeight,
              numColors: image.numColors,
              paletteData: image.paletteData,
              pixelData: image.pixelData.buffer.asUint8List(i * spriteLineHeight * image.width, spriteLineHeight * image.width)));
        }

        // if there is some final, shorter sprite line, process it too
        int finalHeight  = image.height % spriteLineHeight;
        if (finalHeight > 0) {
          _spriteLines.add(
            TxSprite(
              msgCode: msgCode,
              width: image.width,
              height: finalHeight,
              numColors: image.numColors,
              paletteData: image.paletteData,
              pixelData: image.pixelData.buffer.asUint8List(_spriteLines.length * spriteLineHeight * image.width, finalHeight * image.width)));
        }
      }

  /// Convert TxImageSpriteBlock back to a single image for testing/verification
  /// startLine and endLine are inclusive
  Future<Uint8List> toPngBytes() async {
    if (_spriteLines.isEmpty) {
      throw Exception('_spriteLines is empty: no image to convert toPngBytes()');
    }

    // create an image for the whole block
    var preview = img.Image(width: width, height: height);

    // copy in each of the sprites
    for (int i = 0; i <= _spriteLines.length; i++) {
      img.compositeImage(preview, _spriteLines[i].toImage(),
          dstY: (i * spriteLineHeight).toInt());
    }

    return img.encodePng(preview);
  }

  /// Corresponding parser should be called from frame_app data handler
  @override
  Uint8List pack() {
    if (_spriteLines.isEmpty) {
      throw Exception('_spriteLines is empty: no image to pack()');
    }

    // pack the width and height of the image (Uint16 each)
    int widthMsb = width >> 8;
    int widthLsb = width & 0xFF;
    int heightMsb = height >> 8;
    int heightLsb = height & 0xFF;

    // store the spriteLineHeight (Uint16)
    int spriteLineHeightMsb = spriteLineHeight >> 8;
    int spriteLineHeightLsb = spriteLineHeight & 0xFF;

    // special marker for Block header 0xFF, width and height of the block, spriteLineHeight
    return Uint8List.fromList([
      0xFF,
      widthMsb,
      widthLsb,
      heightMsb,
      heightLsb,
      spriteLineHeightMsb,
      spriteLineHeightLsb,
    ]);
  }
}
