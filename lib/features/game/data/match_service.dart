import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<MatchModel> findOrCreateMatch(int durationSeconds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final matchesRef = _firestore.collection('matches');
    


    // Step 1: Find valid waiting match
    // Query returns potentially ANY waiting match. We must filter out our own.
    final querySnapshot = await matchesRef
        .where('status', isEqualTo: 'waiting')
        .where('duration', isEqualTo: durationSeconds)
        // Firestore limitation: cannot filter by 'players' array containment AND status easily without composite index or simple client-side filter
        // We will fetch a batch and filter client-side.
        .limit(10) // Fetch a few to increase chance of finding a valid one
        .get();

    for (var doc in querySnapshot.docs) {
      final match = MatchModel.fromMap(doc.data());
      
      // Filter: Don't join if I created it or am already in it
      if (match.createdBy != user.uid && !match.players.contains(user.uid)) {
         // FOUND VALID MATCH! Join it.
         final updatedPlayers = List<String>.from(match.players)..add(user.uid);
         final startTime = DateTime.now().millisecondsSinceEpoch + 3000; // Sync: 3 Seconds future
        
         await matchesRef.doc(match.id).update({
           'players': updatedPlayers,
           'status': 'in_progress', // Start game!
           'startTime': startTime,
         });

         return MatchModel(
           id: match.id,
           createdBy: match.createdBy,
           players: updatedPlayers,
           seed: match.seed,
           status: 'in_progress',
           createdAt: match.createdAt,
           duration: match.duration,

           startTime: startTime,
         );
      }
    }
    
    // Step 2: Create HOST Match (No valid match found)
    // Generate Random Seed
    final seed = DateTime.now().millisecondsSinceEpoch; 
    final newMatchId = matchesRef.doc().id;

    final newMatch = MatchModel(
      id: newMatchId,
      createdBy: user.uid,
      players: [user.uid],
      seed: seed,
      status: 'waiting',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      duration: durationSeconds,
    );

    await matchesRef.doc(newMatchId).set(newMatch.toMap());

    return newMatch;
  }

  Future<void> deleteMatch(String matchId) async {
    await _firestore.collection('matches').doc(matchId).delete();
  }

  // Fetch completed matches for a specific user to display in Profile
  Future<List<MatchModel>> getUserMatches(String uid) async {
    try {
      final querySnapshot = await _firestore
          .collection('matches')
          .where('players', arrayContains: uid)
          .where('status', isEqualTo: 'finished')
          .orderBy('createdAt', descending: true)
          .limit(20) // Limit to 20 recent matches
          .get();

      return querySnapshot.docs
          .map((doc) => MatchModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print("Error fetching user matches: $e");
      // Fallback: If index is missing, try fetching without orderBy or handle gracefully
      return [];
    }
  }
}
