import 'package:image/image.dart' as img;
import 'sprite.dart';

class TxTextSpriteBlock {
  final List<TxTextSpriteLine> _lines = [];
  List<TxTextSpriteLine> get lines => _lines;
  final int _width;
  int get width => _width;
  final int _lineHeight;
  int get lineHeight => _lineHeight;

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
  TxTextSpriteBlock({required int msgCode, required int width, required int lineHeight, required int displayRows, required img.BitmapFont font, required String text}) : _width = width, _lineHeight = lineHeight {
    // split the string - add newlines at width boundary, existing newlines remain
    var textLines = text.split('\n');

    // if any textLine is longer than allowed width, we need to split it too.
    // TODO Some languages have spaces between words and others don't, so for now just break on any character
    // but in future this could be smarter, possibly looking at character ranges (or the presence of spaces)
    // to work out if/how the line should be split
    // Characters that aren't in the font we replace with U+FFFD unknown replacement character '�'
    // which hopefully will be in the font, otherwise a space of 20
    int unknownCharWidth = font.characters[0xFFFD]?.xAdvance ?? 20;
    int stringWidth = 0;

    for (var line in textLines) {
      int initialCodePointNum = 0;

      List<int> runeList = line.runes.toList();

      for (var i = 0; i < runeList.length; i++) {
        int codePoint = runeList[i];
        var runeWidth = font.characters[codePoint]?.xAdvance ?? unknownCharWidth;

        // check if this rune is wide enough to push us past the allowed sprite width or not
        if (stringWidth + runeWidth <= width) {
          stringWidth += runeWidth;

          if (i == runeList.length - 1) {
            // last rune in the list, we're done
            _lines.add(TxTextSpriteLine(msgCode: msgCode, width: stringWidth, height: lineHeight, font: font, pal: _getPalette(), textLine: line.substring(initialCodePointNum, i + 1)));
            stringWidth = 0;
          }
        } else {
          // make a SpriteTextLine out of the line so far and add to the list
          _lines.add(TxTextSpriteLine(msgCode: msgCode, width: stringWidth, height: lineHeight, font: font, pal: _getPalette(), textLine: line.substring(initialCodePointNum, i)));

          // and start a new line starting from this character
          stringWidth = 0;
          initialCodePointNum = i;
        }
      }
    }
  }

  /// Convert TxTextSpriteBlock back to a single image for testing/verification
  img.Image toImage() {
    var preview = img.Image(width: width, height: lines.length*lineHeight);
    for (int i=0; i<lines.length; i++) {
      img.compositeImage(preview, lines[i].sprite.toImage(), dstY: i*lineHeight);
    }
    return preview;
  }
}

/// Represents a single line of text that will be rendered onto a TxSprite to send to Frame
class TxTextSpriteLine {
  late final img.Image _image;
  late final TxSprite _sprite;
  TxSprite get sprite => _sprite;

  TxTextSpriteLine({required int msgCode, required int width, required int height, required img.BitmapFont font, required img.PaletteUint8 pal, required String textLine}) {
    _image = img.Image(width: width, height: height, withPalette: true, palette: pal);
    img.drawString(_image, textLine, font: font, x: 0, y: 0, color: img.ColorUint8.rgb(255, 255, 255));

    // post-process to turn 255s into 1s, since the drawString isn't setting pixels to a palette index
    var bytes = _image.toUint8List();
    for (int i=0; i < bytes.length; i++) {
      if (bytes[i] != 0) bytes[i] = 1;
    }

    _sprite = TxSprite(msgCode: msgCode, width: width, height: height, numColors: 2, paletteData: pal.data, pixelData: _image.buffer.asUint8List());
  }
}
