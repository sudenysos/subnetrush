import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:subnet_rush/core/theme/app_colors.dart';
import 'package:subnet_rush/features/lobby/presentation/lobby_screen.dart';

class ResultScreen extends StatefulWidget {
  final bool isVictory;
  final int myScore;
  final int opponentScore;
  final int earnedXp;
  final String? myAvatarBase64;
  final String? opponentAvatarBase64;
  final String myUserName;
  final String opponentUserName;

  const ResultScreen({
    super.key,
    required this.isVictory,
    required this.myScore,
    required this.opponentScore,
    required this.earnedXp,
    this.myAvatarBase64,
    this.opponentAvatarBase64,
    required this.myUserName,
    required this.opponentUserName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  // State variables for staged reveal
  bool _showCard = false;
  // bool _showContent = false; // Merged with _showCard
  bool _showButton = false;

  // Wave Animation
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize Wave Controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    // --- TIMELINE ---
    // 1.0s: Show Card & Content TOGETHER
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showCard = true);
    });

    // 2.5s: Trigger Wave Animation (1.5s suspense)
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) _waveController.forward();
    });

    // 3.0s: Show Button
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  ImageProvider _getAvatarImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png'); 
    }
    try {
      // Remove data URI prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      return MemoryImage(base64Decode(cleanBase64));
    } catch (e) {
      debugPrint("Error decoding avatar: $e");
      return const AssetImage('assets/images/default_avatar.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDraw = widget.myScore == widget.opponentScore;
    
    final myWaveColor = isDraw 
        ? Colors.grey[700]! 
        : (widget.isVictory ? Colors.greenAccent[700]! : Colors.redAccent[700]!);
        
    final opponentWaveColor = isDraw 
        ? Colors.grey[700]! 
        : (widget.isVictory ? Colors.redAccent[700]! : Colors.greenAccent[700]!);

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // --- HEADER ---
              const Text(
                'MATCH FINISHED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // --- SPLIT SCORE CARD (STAGED REVEAL) ---
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _showCard ? 1.0 : 0.0,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Row(
                      children: [
                        // --- ME (Left) ---
                        Expanded(
                          child: Stack(
                            children: [
                              // Layer 1: Base White Background
                              Container(color: Colors.white),

                              // Layer 2: Wave Animation (Align Right -> Moves Left visual fill)
                              // Actually, to make it fill from center to left, we align Right and grow width.
                              AnimatedBuilder(
                                animation: _waveAnimation,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: FractionallySizedBox(
                                      widthFactor: _waveAnimation.value,
                                      heightFactor: 1.0,
                                      child: Container(color: myWaveColor),
                                    ),
                                  );
                                },
                              ),

                              // Layer 3: Content
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: _showCard ? 1.0 : 0.0,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 43,
                                        backgroundColor: Colors.white,
                                        child: CircleAvatar(
                                          radius: 40,
                                          backgroundImage: _getAvatarImage(widget.myAvatarBase64),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: _buildAnimatedTextColor(
                                          widget.myUserName.isEmpty 
                                              ? "YOU" 
                                              : (widget.myUserName.startsWith('@') ? widget.myUserName : "@${widget.myUserName}"),
                                          fontWeight: FontWeight.w600,
                                          baseColor: Colors.grey[600]!, // Animated handler will transition this to white
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildAnimatedTextColor(
                                        '${widget.myScore}',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 48,
                                        baseColor: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Vertical Divider (Optional, only visible on white)
                        // If we want it to be covered by wave, put it behind wave or handle z-index.
                        // For simplicity, omitting or keeping minimal. 
                        // Let's omit to avoid z-index complexity with the wave filling over it.

                        Container(
                          width: 2.0, 
                          color: Colors.white, 
                          height: double.infinity,
                        ),

                        // --- OPPONENT (Right) ---
                        Expanded(
                          child: Stack(
                            children: [
                              // Layer 1: Base White Background
                              Container(color: Colors.white),

                              // Layer 2: Wave Animation (Align Left -> Moves Right visual fill)
                              AnimatedBuilder(
                                animation: _waveAnimation,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _waveAnimation.value,
                                      heightFactor: 1.0,
                                      child: Container(color: opponentWaveColor),
                                    ),
                                  );
                                },
                              ),

                              // Layer 3: Content
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: _showCard ? 1.0 : 0.0,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 43,
                                        backgroundColor: Colors.white,
                                        child: CircleAvatar(
                                          radius: 40,
                                          backgroundImage: _getAvatarImage(widget.opponentAvatarBase64),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: _buildAnimatedTextColor(
                                          widget.opponentUserName.isEmpty 
                                            ? "OPPONENT" 
                                            : (widget.opponentUserName.startsWith('@') ? widget.opponentUserName : "@${widget.opponentUserName}"),
                                          fontWeight: FontWeight.w600,
                                          baseColor: Colors.grey[600]!,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                       _buildAnimatedTextColor(
                                        '${widget.opponentScore}',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 48,
                                        baseColor: Colors.grey[500]!,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- ANIMATED BUTTON ---
              AnimatedOpacity(
                opacity: _showButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: IgnorePointer(
                  ignoring: !_showButton,
                  child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LobbyScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 0, 
                      ),
                      child: const Text(
                        'RETURN TO MAIN MENU',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextColor(String text, {
    Color baseColor = Colors.black, 
    double fontSize = 16, 
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 1.2,
  }) {
    // When wave starts (controller > 0), target color is White.
    // We can use AnimatedBuilder to interp color, or just AnimatedDefaultTextStyle triggered by start.
    // Since wave takes 500ms, let's use AnimatedDefaultTextStyle with same duration sync.
    // Trigger: _waveController.isAnimating || _waveController.isCompleted
    
    // Better yet, just use AnimatedBuilder to drive color value if we want perfection,
    // or bind it to a bool that we flip at 3.0s.
    // Let's bind to _waveController status for simplicity in this helper.
    
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        // Simple interpolation: 0.0 -> baseColor, 0.5 -> White (to be visible on mid-transition)
        // Actually, just switching to white as wave covers it.
        // Let's use Color.lerp
        final color = Color.lerp(baseColor, Colors.white, _waveAnimation.value) ?? baseColor;
        
        return Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing,
            overflow: TextOverflow.ellipsis,
          ),
          maxLines: 1,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
