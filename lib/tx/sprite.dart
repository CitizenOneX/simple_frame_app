import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:simple_frame_app/tx_msg.dart';

class TxSprite extends TxMsg {
  late final int _width;
  late final int _height;
  late final int _numColors;
  late final Uint8List _paletteData;
  late final Uint8List _pixelData;

  /// Create a sprite with the specified size, palette data and pixel data, identified by the specified message code (the identifier used on the Lua side to label this sprite)
  /// width(Uint16), height(Uint16), bpp(Uint8), numColors(Uint8), palette (Uint8 r, Uint8 g, Uint8 b)*numColors, data (length: width x height bytes content: palette index)
  TxSprite(
      {required super.msgCode,
      required int width,
      required int height,
      required int numColors,
      required Uint8List paletteData,
      required Uint8List pixelData})
      : _width = width,
        _height = height,
        _numColors = numColors,
        _paletteData = paletteData,
        _pixelData = pixelData;

  /// Create a sprite from a PNG
  /// Sprites should be PNGs with palettes of up to 2, 4, or 16 colors (1-, 2-, or 4-bit indexed palettes)
  /// Alpha channel (4th-RGBA), if present, is dropped before sending to Frame (RGB only, but color 0 is VOID)
  TxSprite.fromPngBytes({required super.msgCode, required Uint8List pngBytes}) {
    var imgPng = img.PngDecoder().decode(pngBytes);

    if (imgPng != null &&
        imgPng.hasPalette &&
        imgPng.palette!.numColors <= 16) {
      // resize the image if it's too big - we really shouldn't have to do this for project sprites, just user-picked images
      if (imgPng.width > 640 || imgPng.height > 400) {
        // use nearest interpolation, we can't use any interpretation that averages colors
        imgPng = img.copyResize(imgPng,
            width: 640,
            height: 400,
            maintainAspect: true,
            interpolation: img.Interpolation.nearest);
      }

      _width = imgPng.width;
      _height = imgPng.height;
      _numColors = imgPng.palette!.numColors;
      _pixelData = imgPng.data!.toUint8List();

      // we can process RGB or RGBA format palettes, but any others we just exclude here
      if (imgPng.palette!.numChannels == 3 ||
          imgPng.palette!.numChannels == 4) {
        if (imgPng.palette!.numChannels == 3) {
          _paletteData = imgPng.palette!.toUint8List();
        } else if (imgPng.palette!.numChannels == 4) {
          // strip out the alpha channel from the palette
          _paletteData = _extractRGB(imgPng.palette!.toUint8List());
        }

        //_log.fine('Sprite: ${imgPng.width} x ${imgPng.height}, ${imgPng.palette!.numColors} cols, ${sprite.pack().length} bytes');
      } else {
        throw Exception(
            'PNG colors must have 3 or 4 channels to be converted to a sprite');
      }
    } else {
      throw Exception(
          'PNG must be a valid PNG image with a palette (indexed color) and 16 colors or fewer to be converted to a sprite');
    }
  }

  /// Strips the Alpha byte out of a list of RGBA colors
  /// Takes a Uint8List of length 4n made of RGBA bytes, and takes the first 3 bytes out of each 4 (RGB)
  Uint8List _extractRGB(Uint8List rgba) {
    // The output list will have 3/4 the length of the input list
    Uint8List rgb = Uint8List((rgba.length * 3) ~/ 4);

    int rgbIndex = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      rgb[rgbIndex++] = rgba[i]; // R
      rgb[rgbIndex++] = rgba[i + 1]; // G
      rgb[rgbIndex++] = rgba[i + 2]; // B
    }

    return rgb;
  }

  /// Corresponding parser should be called from frame_app.lua data_handler()
  @override
  Uint8List pack() {
    int widthMsb = _width >> 8;
    int widthLsb = _width & 0xFF;
    int heightMsb = _height >> 8;
    int heightLsb = _height & 0xFF;
    int bpp = 0;
    Uint8List packed;
    switch (_numColors) {
      case <= 2:
        bpp = 1;
        packed = pack1Bit(_pixelData);
        break;
      case <= 4:
        bpp = 2;
        packed = pack2Bit(_pixelData);
        break;
      case <= 16:
        bpp = 4;
        packed = pack4Bit(_pixelData);
        break;
      default:
        throw Exception(
            'Image must have 16 or fewer colors. Actual: $_numColors');
    }

    // preallocate the list of bytes to send - sprite header, palette, pixel data
    // (packed.length already adds the extra byte if WxH is not divisible by 8)
    Uint8List payload =
        Uint8List.fromList(List.filled(6 + _numColors * 3 + packed.length, 0));

    // NB: palette data could be numColors=12 x 3 (RGB) bytes even if bpp is 4 (max 16 colors)
    // hence we provide both numColors and bpp here.
    // sendMessage will prepend the data byte, msgCode to each packet
    // and the Uint16 payload length to the first packet
    payload
        .setAll(0, [widthMsb, widthLsb, heightMsb, heightLsb, bpp, _numColors]);
    payload.setAll(6, _paletteData);
    payload.setAll(6 + _numColors * 3, packed);

    return payload;
  }

  static Uint8List pack1Bit(Uint8List bpp1) {
    int byteLength =
        (bpp1.length + 7) ~/ 8; // Calculate the required number of bytes
    Uint8List packed =
        Uint8List(byteLength); // Create the Uint8List to hold packed bytes

    for (int i = 0; i < bpp1.length; i++) {
      int byteIndex = i ~/ 8;
      int bitIndex = i % 8;
      packed[byteIndex] |= (bpp1[i] & 0x01) << (7 - bitIndex);
    }

    return packed;
  }

  static Uint8List pack2Bit(Uint8List bpp2) {
    int byteLength =
        (bpp2.length + 3) ~/ 4; // Calculate the required number of bytes
    Uint8List packed =
        Uint8List(byteLength); // Create the Uint8List to hold packed bytes

    for (int i = 0; i < bpp2.length; i++) {
      int byteIndex = i ~/ 4;
      int bitOffset = (3 - (i % 4)) * 2;
      packed[byteIndex] |= (bpp2[i] & 0x03) << bitOffset;
    }

    return packed;
  }

  static Uint8List pack4Bit(Uint8List bpp4) {
    int byteLength =
        (bpp4.length + 1) ~/ 2; // Calculate the required number of bytes
    Uint8List packed =
        Uint8List(byteLength); // Create the Uint8List to hold packed bytes

    for (int i = 0; i < bpp4.length; i++) {
      int byteIndex = i ~/ 2;
      int bitOffset = (1 - (i % 2)) * 4;
      packed[byteIndex] |= (bpp4[i] & 0x0F) << bitOffset;
    }

    return packed;
  }

  /// Convert TxSprite back to an image for testing/verification
  img.Image toImage() {
    // set up the indexed palette
    img.PaletteUint8 pal = img.PaletteUint8(_numColors, 3);
    pal.buffer.asUint8List().setAll(0, _paletteData);

    // TODO Image.palette() doesn't seem to correctly create indexed image.
    // instead, expand out the image to RGB pixels since this is just for phoneside display
    var data = img.ImageDataUint8(_width, _height, 3);
    int pixNum = 0;

    for (var palEntry in _pixelData) {
      data.setPixelRgb(
        pixNum % _width,
        pixNum ~/ _width,
        _paletteData[palEntry * 3],
        _paletteData[palEntry * 3 + 1],
        _paletteData[palEntry * 3 + 2]);

      pixNum++;
    }

    return img.Image.fromBytes(width: _width, height: _height, bytes: data.buffer, numChannels: 3);
  }
}
