import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String name;
  final String surname;
  final String? profilePhotoBase64;
  final DateTime joinDate;
  final int totalScore;
  final int level;
  final List<String> friendIds;
  final Map<String, dynamic> bestScores;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.name,
    required this.surname,
    this.profilePhotoBase64,
    required this.joinDate,
    this.totalScore = 0,
    this.level = 1,
    this.friendIds = const [],
    this.bestScores = const {},
  });

  String get fullName => '$name $surname';
  
  // Format join date as Day/Month/Year string
  String get formattedJoinDate {
    return '${joinDate.day}/${joinDate.month}/${joinDate.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'name': name,
      'surname': surname,
      'profilePhotoBase64': profilePhotoBase64,
      'joinDate': Timestamp.fromDate(joinDate),
      'totalScore': totalScore,
      'level': level,
      'friendIds': friendIds,
      'bestScores': bestScores,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
      profilePhotoBase64: map['profilePhotoBase64'],
      joinDate: (map['joinDate'] as Timestamp).toDate(),
      totalScore: map['totalScore'] ?? 0,
      level: map['level'] ?? 1,
      friendIds: List<String>.from(map['friendIds'] ?? []),
      bestScores: map['bestScores'] as Map<String, dynamic>? ?? {},
    );
  }
}
