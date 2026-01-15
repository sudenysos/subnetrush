
class MatchModel {
  final String id;
  final String createdBy;
  final List<String> players;
  final int seed;
  final String status; // 'waiting', 'in_progress', 'finished'
  final int createdAt;
  final int duration; // Duration in seconds

  final Map<String, int> scores;

  final int? startTime;

  MatchModel({
    required this.id,
    required this.createdBy,
    required this.players,
    required this.seed,
    required this.status,
    required this.createdAt,
    required this.duration,
    this.scores = const {},

    this.startTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdBy': createdBy,
      'players': players,
      'seed': seed,
      'status': status,
      'createdAt': createdAt,
      'duration': duration,
      'scores': scores,

      'startTime': startTime,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] ?? '',
      createdBy: map['createdBy'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      seed: map['seed']?.toInt() ?? 0,
      status: map['status'] ?? 'waiting',
      createdAt: map['createdAt']?.toInt() ?? 0,
      duration: map['duration']?.toInt() ?? 60, // Default 60s
      scores: Map<String, int>.from(map['scores'] ?? {}),

      startTime: map['startTime']?.toInt(),
    );
  }
}
