import 'dart:typed_data';

const int customExerciseImageMaxBytes = 2 * 1024 * 1024;

class CustomImageValidationException implements Exception {
  final String message;

  const CustomImageValidationException(this.message);

  @override
  String toString() => message;
}

typedef ValidatedCustomImage = ({
  Uint8List bytes,
  String extension,
  String mimeType,
});

ValidatedCustomImage validateCustomImageBytes(Uint8List bytes) {
  if (bytes.length > customExerciseImageMaxBytes) {
    throw const CustomImageValidationException(
      'La imagen no puede superar 2 MB',
    );
  }
  if (_isJpeg(bytes)) {
    return (bytes: bytes, extension: 'jpg', mimeType: 'image/jpeg');
  }
  if (_isPng(bytes)) {
    return (bytes: bytes, extension: 'png', mimeType: 'image/png');
  }
  if (_isWebp(bytes)) {
    return (bytes: bytes, extension: 'webp', mimeType: 'image/webp');
  }
  throw const CustomImageValidationException(
    'Elige una imagen JPEG, PNG o WebP válida',
  );
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 6 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;
}

bool _isPng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 33) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  const end = [0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82];
  for (var i = 0; i < end.length; i++) {
    if (bytes[bytes.length - end.length + i] != end[i]) return false;
  }
  return bytes[12] == 0x49 &&
      bytes[13] == 0x48 &&
      bytes[14] == 0x44 &&
      bytes[15] == 0x52;
}

bool _isWebp(Uint8List bytes) {
  if (bytes.length < 16) return false;
  const riff = [0x52, 0x49, 0x46, 0x46];
  const webp = [0x57, 0x45, 0x42, 0x50];
  for (var i = 0; i < 4; i++) {
    if (bytes[i] != riff[i] || bytes[i + 8] != webp[i]) return false;
  }
  final declaredLength =
      bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);
  if (declaredLength + 8 > bytes.length) return false;
  return bytes[12] == 0x56 &&
      bytes[13] == 0x50 &&
      bytes[14] == 0x38 &&
      (bytes[15] == 0x20 || bytes[15] == 0x4c || bytes[15] == 0x58);
}
