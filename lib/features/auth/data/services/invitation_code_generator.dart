import 'dart:math';

class InvitationCodeGenerator {
  static const String _characters =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static const int _codeLength = 8;

  final Random _random;

  InvitationCodeGenerator({
    Random? random,
  }) : _random = random ?? Random.secure();

  String generate() {
    final buffer = StringBuffer();

    for (var i = 0; i < _codeLength; i++) {
      final index = _random.nextInt(_characters.length);
      buffer.write(_characters[index]);
    }

    return 'GHI-${buffer.toString()}';
  }
}