import 'dart:convert';
// import 'dart:async'; // Removed Timer import, handled in GameTimer now
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../domain/match_model.dart';
import '../domain/subnet_game_engine.dart';
import '../domain/subnet_models.dart';
import 'widgets/game_timer.dart'; // Import GameTimer
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final String matchId;
  final int matchSeed;
  final String currentUserId;
  final Map<String, dynamic>? initialMatchData;

  const GameScreen({
    super.key,
    required this.matchId,
    required this.matchSeed,
    required this.currentUserId,
    this.initialMatchData,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final SubnetGameEngine _engine;
  SubnetQuestion? _currentQuestion;
  int _score = 0;  
  // int _questionsAnswered = 0; // Infinite mode
  // static const int _maxQuestions = 20; // Infinite mode

  // static const int _maxQuestions = 20; // Duplicate removed

  // Timer logic moved to GameTimer widget
  // int _timeLeft = 60; 
  // int _totalDuration = 60;
  // Timer? _gameTimer;

  bool _isGameActive = false;
  bool _isGameFinished = false;
  
  // Interaction State
  bool _isChecking = false;
  String? _selectedOption;
  String? _correctOption;
  int _streak = 0; // Track consecutive correct answers
  
  // Image Cache
  final Map<String, MemoryImage> _imageCache = {};

  // Player Data
  String? _playerAvatarBase64;
  String? _opponentAvatarBase64;
  String? _playerUsername;
  String? _opponentUsername;

  @override
  void initState() {
    super.initState();
    _engine = SubnetGameEngine(seed: widget.matchSeed);
    _fetchPlayerProfiles();
    
    // Check initial data to bypass loading screen
    if (widget.initialMatchData != null) {
      final status = widget.initialMatchData!['status'];
      if (status == 'in_progress') {
        _isGameActive = true;
        _currentQuestion = _engine.generateQuestion();
      }
    }
  }

  Future<void> _fetchPlayerProfiles() async {
    try {
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!matchDoc.exists) return;
      
      final data = matchDoc.data();
      final List<dynamic> players = data?['players'] ?? [];
      
      if (players.length < 2) return; // Need 2 players
      
      final p1Id = players[0].toString();
      final p2Id = players[1].toString();

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(p1Id).get(),
        FirebaseFirestore.instance.collection('users').doc(p2Id).get(),
      ]);
      
      final p1Data = results[0].data();
      final p2Data = results[1].data();
      
      final p1Avatar = p1Data?['profilePhotoBase64'];
      final p2Avatar = p2Data?['profilePhotoBase64'];
      final p1Name = p1Data?['username'];
      final p2Name = p2Data?['username'];

      if (mounted) {
        setState(() {
          if (p1Id == widget.currentUserId) {
             _playerAvatarBase64 = p1Avatar;
             _opponentAvatarBase64 = p2Avatar;
             _playerUsername = p1Name;
             _opponentUsername = p2Name;
          } else {
             _playerAvatarBase64 = p2Avatar;
             _opponentAvatarBase64 = p1Avatar;
             _playerUsername = p2Name;
             _opponentUsername = p1Name;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching game profiles: $e");
    }
  }

  @override
  void dispose() {
    // _gameTimer?.cancel(); // Handled by GameTimer widget
    super.dispose();
  }

  // _startTimer removed - logic moved to GameTimer

  void _loadNextQuestion() {
    // Infinite Mode: Check removed. Game only ends on Timer.
    /*
    if (_questionsAnswered >= _maxQuestions) {
      _finishGame();
      return;
    }
    */
    
    setState(() {
      _currentQuestion = _engine.generateQuestion();
    });
  }

  Future<void> _finishGame() async {
    // 0. Disable Interaction Immediately but keep UI visible
    setState(() {
      _isGameActive = false;
      _isGameFinished = true;
    });

    try {
      // 1. Fetch Final Match Data (Sync Scores)
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      final data = matchDoc.data();
      
      if (data == null) {
        // Fallback if error
        if (mounted) Navigator.pop(context); 
        return;
      }

      // 2. Extract Scores
      final scores = data['scores'] as Map<String, dynamic>? ?? {};
      // Ensure my local score is precise (sometimes sync lag happens)
      scores[widget.currentUserId] = _score;

      int opponentScore = 0;
      scores.forEach((key, value) {
        if (key != widget.currentUserId) {
          opponentScore = value as int;
        }
      });
      
      // 3. Determine Outcome
      final bool isVictory = _score > opponentScore;
      // Draw Logic: technically not victory, treat as defeat or handle specially.
      // For now: Draw = Defeat (strictly > to win)

      // 4. Calculate Rewards
      // Victory: Base 50 + Score
      // Defeat: Base 10 + Score
      final int baseXp = isVictory ? 50 : 10;
      final int earnedXp = baseXp + _score;

      // 5. Update Firestore (Sync final state)
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
            'status': 'finished',
            'scores': scores, // Ensure authoritative final scores
      });

      // --- HIGH SCORE LOGIC ---
      try {
        // Get Duration to identify mode
        final int duration = data['duration'] ?? 60;
        final String durationKey = duration.toString();

        // Fetch User's current best scores
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(widget.currentUserId);
        final userDoc = await userDocRef.get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final Map<String, dynamic> bestScores = userData['bestScores'] as Map<String, dynamic>? ?? {};
          
          final int currentBest = bestScores[durationKey] as int? ?? 0;
          
          if (_score > currentBest) {
            // New Record! Update DB
            await userDocRef.set({
              'bestScores': {
                durationKey: _score
              }
            }, SetOptions(merge: true));
            debugPrint("New Personal Best for ${duration}s: $_score!");
          }
        }
      } catch (e) {
        debugPrint("Error updating high score: $e");
      }
      // ------------------------

      // Update XP (Simple increment for now, logic can be centralized later)
      // await userDocRef.update({'xp': FieldValue.increment(earnedXp)});

      if (!mounted) return;

      // 6. Navigate to Result Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            isVictory: isVictory,
            myScore: _score,
            opponentScore: opponentScore,
            earnedXp: earnedXp,
            myAvatarBase64: _playerAvatarBase64,
            opponentAvatarBase64: _opponentAvatarBase64,
            myUserName: _playerUsername ?? "YOU",
            opponentUserName: _opponentUsername ?? "OPPONENT",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error finishing game: $e");
      if (mounted) Navigator.pop(context); // Fail safe
    }
  }



  Future<void> _onAnswerSelected(String selectedOption) async {
    if (!_isGameActive || _currentQuestion == null || _isChecking) return;

    final isCorrect = selectedOption == _currentQuestion!.correctAnswer;
    
    // Step 1: Immediate Visual Feedback State
    setState(() {
      _isChecking = true;
      _selectedOption = selectedOption;
      _correctOption = _currentQuestion!.correctAnswer;
    });

    // Step 2 and 3 Combined: Wait for flash
    await Future.delayed(const Duration(seconds: 1));

    // Step 4: Logic Processing
    if (!mounted) return;

    if (isCorrect) {
      setState(() {
        _streak++;
        // Step B: Calculate points based on NEW streak
        int pointsEarned = 10 * _streak;
        
        // Step C: Add to score
        _score += pointsEarned;
        // debugPrint("Streak: $_streak, Points: +$pointsEarned");
      });
      
      // FIREBASE WRITE: Sync Score
      FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'scores.${widget.currentUserId}': _score,
      });
    } else {
      setState(() {
        _streak = 0; // Reset streak
        _score -= 5; // Penalty
        if (_score < 0) _score = 0; // Floor protection
      });

      // Sync penalty immediately
      FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'scores.${widget.currentUserId}': _score,
      });
    }

    // Reset interaction state for next question
    setState(() {
      _isChecking = false;
      _selectedOption = null;
      _correctOption = null;
    });

    _loadNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    // If waiting (and not finished), show LOBBY UI
    if (!_isGameActive && !_isGameFinished) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              // Listen for Game Start Signal (Even in lobby view)
              if (snapshot.hasData && snapshot.data != null) {
                 final data = snapshot.data!.data() as Map<String, dynamic>?;
                 if (data != null) {
                    final status = data['status'];
                    if (status == 'in_progress' && !_isGameActive) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                         if (mounted) {
                           setState(() {
                             _isGameActive = true;
                             _currentQuestion = _engine.generateQuestion();
                             
                              // Initialize Game Active State
                             // Timer logic is now self-contained in GameTimer widget
                             // which renders below based on data['duration']
                           });
                         }
                       });
                    }
                 }
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulse Animation (Simplified for now)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_tethering,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'FINDING OPPONENT...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for a challenger...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),
                    TextButton.icon(
                      onPressed: () async {
                         // Cancel Match
                         // Assuming we can simply delete it or leave it. 
                         // Ideally we check if we are host using MatchService but for now straightforward delete/pop.
                         // Check service import... we need to instantiate or make static.
                         // For simplicity: firestore delete directly here or scaffold logic?
                         // Better: direct delete since we have ID.
                         await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).delete();
                         if (!context.mounted) return;
                         Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      label: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // GAME UI
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // --- TOP SECTION: HUD ---
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('matches')
                    .doc(widget.matchId)
                    .snapshots(),
                builder: (context, snapshot) {
                  int opponentScore = 0;
                  int matchDuration = 60; // Default duration

                  if (snapshot.hasData && snapshot.data != null) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                       final match = MatchModel.fromMap(data);
                       matchDuration = match.duration; // Capture duration

                       // Find opponent score
                       final opponentId = match.players.firstWhere(
                         (id) => id != widget.currentUserId, 
                         orElse: () => '',
                       );
                       if (opponentId.isNotEmpty) {
                         opponentScore = match.scores[opponentId] ?? 0;
                       }
                    }
                  }

                  return _buildHUD(
                    opponentScore: opponentScore,
                    playerAvatar: _playerAvatarBase64,
                    opponentAvatar: _opponentAvatarBase64,
                    isWaiting: false, // Always false here now
                    duration: matchDuration,
                  );
                },
              ),
              const Spacer(flex: 1), 

              _buildQuestionCard(),
              const Spacer(flex: 1),

              _buildAnswerDeck(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildHUD({
    required int opponentScore,
    String? playerAvatar,
    String? opponentAvatar,
    bool isWaiting = false,
    int duration = 60,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0), // Rule: Comfortable Top Padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Player Info (Expanded -> Start)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3), // Rule: Thicker Border
                  ),
                  child: CircleAvatar(
                    radius: 28, // Rule: Larger Avatar
                    backgroundImage: _getAvatarProvider(playerAvatar),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _score.toString(),
                  style: const TextStyle(
                    fontSize: 24, // Rule: Bigger Score
                    fontWeight: FontWeight.w900, // Rule: ExtraBold
                    color: Colors.white, // Rule: White Score
                  ),
                ),
              ],
            ),
          ),

          // Center: Game Timer Widget
          GameTimer(
            duration: duration,
            onTimeUp: _finishGame,
          ),

          // Right: Opponent Info (Expanded -> End)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  opponentScore.toString(),
                  style: const TextStyle(
                    fontSize: 24, // Rule: Bigger Score
                    fontWeight: FontWeight.w900, // Rule: ExtraBold
                    color: Colors.white, // Rule: White Score
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3), // Rule: Thicker Border
                  ),
                  child: CircleAvatar(
                    radius: 28, 
                    backgroundColor: Colors.white24, // Placeholder bg
                    backgroundImage: isWaiting 
                        ? null // Show nothing/icon if waiting
                        : _getAvatarProvider(opponentAvatar),
                    child: isWaiting 
                        ? const Icon(Icons.question_mark, color: Colors.white) 
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    if (_currentQuestion == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24), // Rule: Increased Padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _currentQuestion!.questionTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700, // Rule: Bold Label
              color: Colors.grey[850], // Rule: Darker Label
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16), // Rule: Spacing

          // Rule: Dual-Color Styling (RichText)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _currentQuestion!.ipAddress,
                  style: const TextStyle(
                    color: Colors.black, // Rule: Black IP
                  ),
                ),
                TextSpan(
                  text: ' /${_currentQuestion!.cidr}', // Added Space
                  style: const TextStyle(
                    color: AppColors.primary, // Rule: Purple CIDR
                    fontWeight: FontWeight.bold, // Rule: Matched Weight
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900, // Rule: Extra Bold shared by both
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerDeck() {
    if (_currentQuestion == null) return const SizedBox();
    
    final options = _currentQuestion!.options;

    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildAnswerButton(index, text),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerButton(int index, String text) {
    const labels = ['A', 'B', 'C', 'D'];
    final label = labels[index];

    // Determine Logic Color
    Color buttonColor = Colors.white;
    Color textColor = Colors.black87;
    
    if (_isChecking) {
       if (text == _correctOption) {
         // Case A & C: ALWAYS show Green for the correct answer
         buttonColor = const Color(0xFF4CAF50); // Material Green 500
         textColor = Colors.white;
       } else if (text == _selectedOption) {
         // Case B: Selected but Wrong -> Red
         buttonColor = const Color(0xFFE57373); // Material Red 300
         textColor = Colors.white;
       } else {
         // Case D: Others -> Dim/White
         buttonColor = Colors.white.withValues(alpha: 0.5);
       }
    }

    return _SolidTapButton(
      onTap: () => _onAnswerSelected(text),
      // Pass dynamic color to the button helper
      backgroundColorOverride: _isChecking ? buttonColor : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0), // Rule: Chunky Touch
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Absolutely Centered Data
            Align(
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 22, // Rule: Increase Size
                  fontWeight: FontWeight.w800, // Rule: ExtraBold
                  color: textColor, // Rule: Dynamic Text Color
                  // Rule: Removed Monospace (Match Question Font)
                ),
              ),
            ),
            
            // Layer 2: Left-Anchored Clean Badge OR Feedback Icon
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 40, // Fixed width for stability
                alignment: Alignment.center,
                child: () {
                   // Logic: Show Icon if Checking AND (Selected OR Correct)
                   bool showIcon = _isChecking && (text == _selectedOption || text == _correctOption);
                   
                   if (showIcon) {
                     if (text == _correctOption) {
                       return const Icon(Icons.check_circle, color: Colors.white, size: 28);
                     } else {
                       return const Icon(Icons.cancel, color: Colors.white, size: 28);
                     }
                   } 
                   
                   // Default: Show Label
                   return Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800, // Rule: Bold
                      color: AppColors.primary,
                    ),
                  );
                }(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  ImageProvider _getAvatarProvider(String? base64String) {
    if (base64String != null && base64String.isNotEmpty) {
      // 1. Check Cache
      if (_imageCache.containsKey(base64String)) {
        return _imageCache[base64String]!;
      }

      // 2. Decode & Cache
      try {
        final cleanBase64 = base64String.contains(',') ? base64String.split(',').last : base64String;
        final image = MemoryImage(base64Decode(cleanBase64));
        _imageCache[base64String] = image; // Cache it!
        return image;
      } catch (e) {
        debugPrint('Avatar Error: $e');
      }
    }
    return const NetworkImage('https://i.pravatar.cc/150?img=11'); // Fallback
  }

}

// --- Helper Widget: Solid Tap Button ---
class _SolidTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? backgroundColorOverride;

  const _SolidTapButton({
    required this.child, 
    required this.onTap,
    this.backgroundColorOverride,
  });

  @override
  State<_SolidTapButton> createState() => _SolidTapButtonState();
}

class _SolidTapButtonState extends State<_SolidTapButton> {
  Color _backgroundColor = Colors.white;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _backgroundColor = Colors.grey[200]!;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    // Only invoke tap if override is null (meaning no active check)
    // Actually, parent handles logic, but visual reset needed
    setState(() {
      _backgroundColor = Colors.white;
    });
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() {
      _backgroundColor = Colors.white;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50), // Instant but smooth
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.backgroundColorOverride ?? _backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
