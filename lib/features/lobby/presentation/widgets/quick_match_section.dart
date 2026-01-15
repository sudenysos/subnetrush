import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../game/data/match_service.dart';

import '../../../game/presentation/match_found_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuickMatchSection extends StatefulWidget {
  const QuickMatchSection({super.key});

  @override
  State<QuickMatchSection> createState() => _QuickMatchSectionState();
}

class _QuickMatchSectionState extends State<QuickMatchSection> with SingleTickerProviderStateMixin {
  int _selectedDuration = 3;
  bool _isSearching = false;
  StreamSubscription? _matchSubscription;
  String? _currentMatchId;
  
  // Animation Controller for "Scanner"
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    // 2-second loop for the scan (left to right and back)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _scanController.dispose();
    if (_isSearching && _currentMatchId != null) {
       MatchService().deleteMatch(_currentMatchId!); 
    }
    super.dispose();
  }

  Future<void> _handleMatchButton() async {
    // SCENARIO B: Cancel Search
    if (_isSearching) {
      if (_currentMatchId != null) {
        await MatchService().deleteMatch(_currentMatchId!);
      }
      _matchSubscription?.cancel();
      _stopScanning();
      
      setState(() {
        _isSearching = false;
        _currentMatchId = null;
      });
      return;
    }

    // SCENARIO A: Start Search
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSearching = true;
    });
    
    _startScanning();

    try {
      final matchService = MatchService();
      final durationSeconds = _selectedDuration * 60;
      
      final match = await matchService.findOrCreateMatch(durationSeconds);
      _currentMatchId = match.id;

      if (match.status == 'in_progress') {
        _navigateToGame(match.id, match.seed, user.uid, match.toMap());
        return;
      }

      _matchSubscription = FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots()
          .listen((snapshot) {
            if (!snapshot.exists) return;
            
            final data = snapshot.data();
            if (data != null && data['status'] == 'in_progress') {
               _navigateToGame(match.id, match.seed, user.uid, data);
            }
          });

    } catch (e) {
      debugPrint('Match Error: $e');
      _stopScanning();
      setState(() => _isSearching = false);
    }
  }

  void _startScanning() {
    _scanController.repeat(reverse: true);
  }

  void _stopScanning() {
    _scanController.stop();
    _scanController.reset();
  }

  void _navigateToGame(String matchId, int seed, String userId, Map<String, dynamic> matchData) {
    if (mounted) {
      setState(() => _isSearching = false);
      _stopScanning();
    }
    
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchFoundScreen(
          matchId: matchId,
          matchSeed: seed,
          currentUserId: userId,
          matchData: matchData,
        ),
      ),
    );

    _matchSubscription?.cancel();
    _currentMatchId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Clip needed for the scanner line to stay inside borders
      clipBehavior: Clip.hardEdge, 
      child: Stack(
        children: [
          // --- LAYER 1: Content ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 34),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          const Text(
                          'Quick Match',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compete against a random opponent.', // Rule: Static Text
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600], // Rule: Static Color
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Duration Selector Logic Remains Same...
                IgnorePointer(
                  ignoring: _isSearching,
                  child: Opacity(
                    opacity: _isSearching ? 0.3 : 1.0,
                    child: Row(
                      children: [
                        _buildDurationOption(1),
                        const SizedBox(width: 8),
                        _buildDurationOption(3),
                        const SizedBox(width: 8),
                        _buildDurationOption(5),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Button Logic Remains Same...
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSearching ? Colors.redAccent : AppColors.primary).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleMatchButton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSearching ? Colors.redAccent : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isSearching ? 'CANCEL' : 'FIND MATCH',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // --- LAYER 2: Scanner Animation ---
          if (_isSearching)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4, // Top edge beam
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  const beamWidth = 80.0; // Rule: Fixed Width

                  return AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {


                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            // Move from 0 to (maxWidth - beamWidth)
                            // Kept strictly inside the bounds
                            left: _scanAnimation.value * (maxWidth - beamWidth),

                            top: 0,
                            bottom: 0,
                            width: beamWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor, // Rule: Match Brand
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildDurationOption(int duration) {
    bool isSelected = _selectedDuration == duration;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDuration = duration;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // Rule: Softer Animation
          curve: Curves.fastOutSlowIn, // Rule: Organic Feel
          height: 45, // Rule: Lock Height
          decoration: BoxDecoration(
            // Rule: Cleaner Hierarchy (Grey[100] vs White)
            color: isSelected ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            // Rule: Lock Border Width (Always 2.0)
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent, 
              width: 2.0
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$duration MIN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800, // Rule: Lock Font Weight
              // Rule: Cleaner Text Colors (Grey[600] vs Primary)
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
