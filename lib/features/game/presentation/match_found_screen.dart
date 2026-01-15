import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'game_screen.dart';

class MatchFoundScreen extends StatefulWidget {
  final String matchId;
  final int matchSeed;
  final String currentUserId;
  final Map<String, dynamic> matchData;

  const MatchFoundScreen({
    super.key,
    required this.matchId,
    required this.matchSeed,
    required this.currentUserId,
    required this.matchData,
  });

  @override
  State<MatchFoundScreen> createState() => _MatchFoundScreenState();
}

class _MatchFoundScreenState extends State<MatchFoundScreen> with TickerProviderStateMixin {
  // Controllers
  late AnimationController _lineController;
  late AnimationController _textInController;
  late AnimationController _textOutController;
  late AnimationController _avatarMoveController;
  late AnimationController _nameFadeController;
  late AnimationController _vsScaleController;

  // Player Data (Perspective)
  // Player Data (Perspective) - Nullable for Loading State
  String? _myDisplayName;
  String? _myAvatarBase64;
  String? _opponentDisplayName;
  String? _opponentAvatarBase64;

  // Animations
  late Animation<double> _textOpacityIn;
  late Animation<double> _textOpacityOut;
  late Animation<Offset> _p1SlideAnimation;
  late Animation<Offset> _p2SlideAnimation;
  late Animation<double> _avatarFadeAnimation;
  late Animation<double> _nameOpacity;

  Timer? _navigationTimer;

  // Use primary color
  final Color _primaryColor = const Color(0xFF6C63FF); 

  @override
  void initState() {
    super.initState();
    _fetchAndSetData();
    _initAnimations();
    _startSequence();
  }

  Future<void> _fetchAndSetData() async {
    print("DEBUG: Starting Data Fetch with Corrected Structure...");
     
    // 1. Extract IDs from the 'players' List
    List<dynamic> players = widget.matchData['players'] ?? [];
     
    if (players.length < 2) {
      print("ERROR: 'players' array is missing or has fewer than 2 players!");
      // Handle fallback or error
      if (mounted) {
        setState(() {
          _myDisplayName = "Player 1";
          _opponentDisplayName = "Player 2";
        });
      }
      return;
    }

    // Assuming the array contains strings (UIDs). 
    final String p1Id = players[0].toString();
    final String p2Id = players[1].toString();
     
    print("DEBUG: Extracted P1 ID: $p1Id");
    print("DEBUG: Extracted P2 ID: $p2Id");

    try {
      // 2. Fetch User Docs concurrently
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(p1Id).get(),
        FirebaseFirestore.instance.collection('users').doc(p2Id).get(),
      ]);

      final p1Snapshot = results[0];
      final p2Snapshot = results[1];

      if (!p1Snapshot.exists) print("DEBUG: P1 User Doc does not exist!");
      if (!p2Snapshot.exists) print("DEBUG: P2 User Doc does not exist!");

      final p1Data = p1Snapshot.data() ?? {};
      final p2Data = p2Snapshot.data() ?? {};

      // 3. Extract Specific Fields (username & profilePhotoBase64)
      // Use default values if fields are missing
      String p1Name = p1Data['username'] ?? "Player 1";
      String p1Avatar = p1Data['profilePhotoBase64'] ?? "";

      String p2Name = p2Data['username'] ?? "Player 2";
      String p2Avatar = p2Data['profilePhotoBase64'] ?? "";
       
      print("DEBUG: P1 Name: $p1Name, Avatar Length: ${p1Avatar.length}");

      if (!mounted) return;

      // 4. Set Perspective (Me vs Opponent)
      final currentUserId = widget.currentUserId;

      setState(() {
        if (currentUserId == p1Id) {
          _myDisplayName = p1Name;
          _myAvatarBase64 = p1Avatar;
          _opponentDisplayName = p2Name;
          _opponentAvatarBase64 = p2Avatar;
        } else {
          // I am Player 2 (or second in list)
          _myDisplayName = p2Name;
          _myAvatarBase64 = p2Avatar;
          _opponentDisplayName = p1Name;
          _opponentAvatarBase64 = p1Avatar;
        }
      });
    } catch (e) {
      print("CRITICAL ERROR in Fetch: $e");
      // Fallback
      if (mounted) {
        setState(() {
          _myDisplayName = "Player 1";
          _opponentDisplayName = "Player 2";
        });
      }
    }
  }

  void _initAnimations() {
    // 1. Line Animation (1.0s)
    _lineController = AnimationController(
       vsync: this, duration: const Duration(seconds: 1));

    // 2. Text In (500ms)
    _textInController = AnimationController(
       vsync: this, duration: const Duration(milliseconds: 500));
    _textOpacityIn = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textInController, curve: Curves.easeIn));

    // 3. Text Out (300ms)
    _textOutController = AnimationController(
       vsync: this, duration: const Duration(milliseconds: 300));
    _textOpacityOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _textOutController, curve: Curves.easeOut));

    // 4. Avatars Move (1.0s)
    _avatarMoveController = AnimationController(
       vsync: this, duration: const Duration(milliseconds: 1000));
    
    // P1: Top (-5) to Center (0,0) - Strict Vertical Drop
    _p1SlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -5.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _avatarMoveController, curve: Curves.easeOutCubic));

    // P2: Bottom (5) to Center (0,0) - Strict Vertical Rise
    _p2SlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 5.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _avatarMoveController, curve: Curves.easeOutCubic));

    // NEW: Avatar Fade In (Sync with movement to avoid "pop")
    _avatarFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _avatarMoveController, curve: Curves.easeIn));

    // 5. Names Fade (500ms)
    _nameFadeController = AnimationController(
       vsync: this, duration: const Duration(milliseconds: 500));
    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _nameFadeController, curve: Curves.easeIn));

    // 6. VS Pop (400ms)
    _vsScaleController = AnimationController(
       vsync: this, duration: const Duration(milliseconds: 400));
  }

  void _startSequence() {
    // Step 1: Lines
    _lineController.forward();
    _lineController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Step 2: Text In
        _textInController.forward();
      }
    });

    _textInController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Step 2b: Hold Text briefly (2s) then Fade Out
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _textOutController.forward();
        });
      }
    });

    _textOutController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Step 3: Avatars Fly In
        _avatarMoveController.forward();
      }
    });

    _avatarMoveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Step 4: Names Fade In & VS Pop
        _nameFadeController.forward();
        _vsScaleController.forward();
      }
    });

    _nameFadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Step 5: Final Hold (2s) then Go
        _navigationTimer = Timer(const Duration(milliseconds: 2000), () {
          _navigateToGame();
        });
      }
    });
  }

  void _navigateToGame() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
            matchId: widget.matchId,
            matchSeed: widget.matchSeed,
            currentUserId: widget.currentUserId,
            initialMatchData: widget.matchData,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var curve = Curves.easeOutQuart;
            var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

            return ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  Uint8List _safeBase64Decode(String? source) {
    if (source == null || source.isEmpty) return Uint8List(0);
    try {
      if (source.contains(',')) {
        return base64Decode(source.split(',').last);
      }
      return base64Decode(source);
    } catch (e) {
      return Uint8List(0);
    }
  }

  ImageProvider _getAvatarImage(String? base64String) {
    if (base64String != null && base64String.isNotEmpty) {
      return MemoryImage(_safeBase64Decode(base64String));
    }
    return const NetworkImage('https://i.pravatar.cc/150'); // Fallback
  }

  @override
  void dispose() {
    _lineController.dispose();
    _textInController.dispose();
    _textOutController.dispose();
    _avatarMoveController.dispose();
    _nameFadeController.dispose();
    _vsScaleController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // final screenWidth = MediaQuery.of(context).size.width; 

    // Extract Data - MOVED TO STATE variables
    // final p1Name = widget.matchData['player1Name'] ?? 'Player 1';
    // ... logic handled in _setPlayerPerspective
    
    // Loading Check
    if (_myDisplayName == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, 
      body: Stack(
        children: [
          // --- Layer 1: Purple Lines ---
          AnimatedBuilder(
            animation: _lineController,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: (screenHeight / 2) * _lineController.value,
                color: _primaryColor,
              );
            },
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _lineController,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: (screenHeight / 2) * _lineController.value,
                  color: _primaryColor,
                );
              },
            ),
          ),

          // --- Layer 2: "MATCH FOUND" Text (Fades In, Then Out) ---
          Center(
            child: FadeTransition(
              opacity: _textOpacityOut, // Controls Exit
              child: FadeTransition(
                opacity: _textOpacityIn, // Controls Entry
                child: const Text(
                  "MATCH FOUND",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ),

          // --- Layer 3: VS Content (Avatars & Names) ---
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- TOP BLOCK: ME (Left) ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: SlideTransition(
                      position: _p1SlideAnimation,
                      child: FadeTransition(
                        opacity: _avatarFadeAnimation,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 64, 
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _getAvatarImage(_myAvatarBase64),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeTransition(
                              opacity: _nameOpacity,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  _myDisplayName!.startsWith('@') ? _myDisplayName! : "@$_myDisplayName",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- VS TEXT (The Divider) ---
                const SizedBox(height: 30),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: _vsScaleController, curve: Curves.elasticOut)
                  ),
                  child: Text(
                    "vs",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80, 
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -5.0, // Graphic Logo Look
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- BOTTOM BLOCK: OPPONENT (Right) ---
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: SlideTransition(
                      position: _p2SlideAnimation,
                      child: FadeTransition(
                        opacity: _avatarFadeAnimation,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 64, 
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _getAvatarImage(_opponentAvatarBase64),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeTransition(
                              opacity: _nameOpacity,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  _opponentDisplayName!.startsWith('@') ? _opponentDisplayName! : "@$_opponentDisplayName",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
