import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import '../tx_msg.dart';
import 'sprite.dart';

class TxTextSpriteBlock extends TxMsg {
  final int _msgCode;
  final int _width;
  int get width => _width;
  final int _fontSize;
  int get fontSize => _fontSize;
  final List<TxSprite> _lines = [];
  List<TxSprite> get lines => _lines;

  late final List<ui.LineMetrics> _lineMetrics;
  late final int _totalHeight;
  late final ui.Picture _picture;
  late final ui.Image _image;

  static img.PaletteUint8? monochromePal;

  /// return a 2-color, 3-channel palette (just black then white)
  static img.PaletteUint8 _getPalette() {
    if (monochromePal == null) {
      monochromePal = img.PaletteUint8(2, 3);
      monochromePal!.setRgb(0, 0, 0, 0);
      monochromePal!.setRgb(1, 255, 255, 255);
    }

    return monochromePal!;
  }

  /// Represents an (optionally) multi-line block of text of a specified width and number of visible rows at a specified lineHeight
  /// If the supplied text string is longer, only displayRows will be shown but each TextSpriteLine will be rendered and sent to Frame
  /// If the supplied text string has fewer than displayRows, only the number of actual rows will be rendered and sent to Frame
  /// If any given line of text is shorter than width, the TextSpriteLine will be set to the actual width required.
  /// When sending TxTextSpriteBlock to Frame, the sendMessage() will send the header with block dimensions and line-by-line offsets
  /// and the user then sends each line[] as a TxSprite message with the same msgCode as the Block, and the frame app will use the offsets
  /// to place each line. By sending each line separately we can display them as they arrive, as well as reducing overall memory
  /// requirement (each concat() call is smaller)
  TxTextSpriteBlock(
      {required super.msgCode,
      required int width,
      required int fontSize,
      required int displayRows,
      String? fontFamily,
      ui.TextAlign textAlign = ui.TextAlign.left,
      ui.TextDirection textDirection = ui.TextDirection.ltr,
      required String text})
      : _msgCode = msgCode,
        _width = width,
        _fontSize = fontSize {
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: textAlign,
      textDirection: textDirection,
      fontFamily: fontFamily, // gets platform default if null
      fontSize: _fontSize.toDouble(), // Adjust font size as needed
    ));

    // trim whitespace around text - in particular, a trailing newline char leads to a final line of text with zero
    // width, which results in a sprite that can't be drawn and caused problems frameside
    paragraphBuilder.addText(text.trim());
    final paragraph = paragraphBuilder.build();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);

    paragraph.layout(ui.ParagraphConstraints(width: width.toDouble()));

    canvas.drawParagraph(paragraph, ui.Offset.zero);
    _picture = pictureRecorder.endRecording();

    // work out height using metrics after paragraph.layout() call
    _lineMetrics = paragraph.computeLineMetrics();
    _totalHeight = (_lineMetrics.fold<double>(0, (prev, lm) {
      return prev + lm.height;
    })).toInt();
  }

  /// Since the Paragraph rasterizing to the Canvas, and the getting of the Image bytes
  /// are async functions
  Future<void> rasterize() async {
    if (_lineMetrics.isNotEmpty) {
      _image = await _picture.toImage(_width, _totalHeight);

      var byteData =
          (await _image.toByteData(format: ui.ImageByteFormat.rawUnmodified))!;

      // loop over each line of text in the paragraph and create a TxSprite
      for (var line in _lineMetrics) {
        int tlX = line.left.toInt();
        int tlY = (line.baseline - line.ascent).toInt();
        int lineWidth = line.width.toInt();
        int lineHeight = (line.ascent + line.descent).toInt();

        var linePixelData = Uint8List(lineWidth * lineHeight);

        for (int i = 0; i < lineHeight; i++) {
          // take one row of the source image byteData, remembering it's in RGBA so 4 bytes per pixel
          var sourceRow = byteData.buffer
              .asUint8List(((tlY + i) * _width + tlX) * 4, lineWidth * 4);

          for (int j = 0; j < lineWidth; j++) {
            // take only every 4th byte because the source buffer is RGBA
            // and map it to palette index 1 if it's 128 or bigger (monochrome palette only, and text rendering will be anti-aliased)
            linePixelData[i * lineWidth + j] = sourceRow[4 * j] >= 128 ? 1 : 0;
          }
        }

        // make a Sprite out of the line and add to the list
        _lines.add(TxSprite(
            msgCode: _msgCode,
            width: lineWidth,
            height: lineHeight,
            numColors: 2,
            paletteData: _getPalette().data,
            pixelData: linePixelData));
      }
    }
  }

  /// Convert TxTextSpriteBlock back to a single image for testing/verification
  Future<Uint8List> toPngBytes() async {
    if (_lineMetrics.isEmpty)
      throw Exception('call rasterize() before toPngBytes');

    // create an image for the whole block
    var preview = img.Image(width: width, height: _totalHeight);

    // copy in each of the sprites
    for (int i = 0; i < lines.length; i++) {
      img.compositeImage(preview, lines[i].toImage(),
          dstY: (_lineMetrics[i].baseline - _lineMetrics[i].ascent).toInt());
    }

    return img.encodePng(preview);
  }

  /// Corresponding parser should be called from frame_app data handler
  @override
  Uint8List pack() {
    int widthMsb = _width >> 8;
    int widthLsb = _width & 0xFF;
    int heightMsb = _totalHeight >> 8;
    int heightLsb = _totalHeight & 0xFF;

    // store the x (16-bit) and y (16-bit) offsets as pairs for each of the lines
    Uint8List offsets = Uint8List(_lineMetrics.length * 4);

    for (int i = 0; i < _lineMetrics.length; i++) {
      var lm = _lineMetrics[i];
      int xOffset = lm.left.toInt();
      int yOffset = (lm.baseline - lm.ascent).toInt();
      offsets[4 * i] = xOffset >> 8;
      offsets[4 * i + 1] = xOffset & 0xFF;
      offsets[4 * i + 2] = yOffset >> 8;
      offsets[4 * i + 3] = yOffset & 0xFF;
    }

    // special marker for Block header 0xFF, size of the block (WxH), num lines, offsets within block for each line
    return Uint8List.fromList([
      0xFF,
      widthMsb,
      widthLsb,
      heightMsb,
      heightLsb,
      _lines.length & 0xFF,
      ...offsets
    ]);
  }
}
