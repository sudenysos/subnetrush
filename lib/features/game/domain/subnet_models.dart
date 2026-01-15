
enum QuestionType { network, broadcast, firstUsable, lastUsable }

class SubnetQuestion {
  final String ipAddress;
  final int cidr;
  final String correctAnswer;
  final List<String> options;
  final QuestionType type;

  SubnetQuestion({
    required this.ipAddress,
    required this.cidr,
    required this.correctAnswer,
    required this.options,
    this.type = QuestionType.network,
  });

  String get questionTitle {
    switch (type) {
      case QuestionType.broadcast:
        return 'FIND THE BROADCAST ADDRESS';
      case QuestionType.firstUsable:
        return 'FIND THE FIRST USABLE ADDRESS';
      case QuestionType.lastUsable:
        return 'FIND THE LAST USABLE ADDRESS';
      case QuestionType.network:
      default:
        return 'FIND THE NETWORK ADDRESS';
    }
  }

  @override
  String toString() => 'Type: ${type.name} | IP: $ipAddress/$cidr | Ans: $correctAnswer';
}

class IPUtils {
  /// Converts an IP string (e.g., "192.168.1.1") to a 32-bit integer.
  static int ipToInt(String ip) {
    try {
      var parts = ip.split('.');
      if (parts.length != 4) throw FormatException('Invalid IP format');
      return (int.parse(parts[0]) << 24) |
             (int.parse(parts[1]) << 16) |
             (int.parse(parts[2]) << 8) |
             int.parse(parts[3]);
    } catch (e) {
      // Fallback for safety, though technically checking beforehand is better
      return 0;
    }
  }

  /// Converts a 32-bit integer to an IP string.
  static String intToIp(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ].join('.');
  }
}
