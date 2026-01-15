import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../core/theme/app_colors.dart';

class CreateRoomScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Passed for instant display (optional now)
  final String roomCode;

  const CreateRoomScreen({
    super.key, 
    required this.userData,
    required this.roomCode,
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  int _selectedDurationIndex = 0; // 0: 60s, 1: 180s, 2: 300s

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).snapshots(),
      builder: (context, snapshot) {
        // Default values while loading
        bool isHost = false;
        List players = [];
        bool isLoading = !snapshot.hasData;
        bool exists = true;
        String? hostId;

        if (snapshot.hasData && snapshot.data!.exists) {
          final roomData = snapshot.data!.data() as Map<String, dynamic>;
          players = List.from(roomData['players'] ?? []);
          hostId = roomData['hostId'] as String?;
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          isHost = currentUid == hostId;
        } else if (snapshot.hasData && !snapshot.data!.exists) {
           exists = false;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isHost ? 'Create Room' : 'Match Lobby',
              style: const TextStyle(
                color: Colors.black, // Rule 1: Black
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.5),
              child: Container(color: AppColors.primary, height: 1.5), // Rule 1: Primary Divider 1.5
            ),
          ),
          body: Builder(
            builder: (context) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!exists) {
                return const Center(child: Text("Room ended or does not exist."));
              }

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Mode Selection (No Label)
                            const SizedBox(height: 12),
                            _buildModeSelector(),
                            const SizedBox(height: 32),

                            // 2. Room Code (Display Real Code)
                            _buildRoomCodeDisplay(widget.roomCode),
                            const SizedBox(height: 32),

                            // 3. Player Lobby (Real List)
                            _buildPlayerList(players, hostId),
                          ],
                        ),
                      ),
                    ),

                    // 4. Start Button (Host Only or Passive Guest)
                    _buildStartButton(isHost),
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }



  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(child: _buildModeButton('1 MIN', 0)),
        const SizedBox(width: 12),
        Expanded(child: _buildModeButton('3 MIN', 1)),
        const SizedBox(width: 12),
        Expanded(child: _buildModeButton('5 MIN', 2)),
      ],
    );
  }

  Widget _buildModeButton(String label, int index) {
    final isSelected = _selectedDurationIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedDurationIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2.0)
              : Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCodeDisplay(String code) {
    // Format code with spaces, e.g. "A 7 B 2"
    final displayCode = code.split('').join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            displayCode,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 8.0,
            ),
          ),
        ],
      ),
    );
  }

  // Helper logic needed update since we moved logic up
  Widget _buildPlayerList(List players, String? hostId) {
    // Note: In the previous method call `_buildPlayerList(players, isHost ? ... : null)` I made a mistake in assumption.
    // The `hostId` is needed to identify WHICH player card gets the star.
    // So we need to recover the real hostId from the snapshot logic or pass it down.
    // Since I can't easily change the arguments in this replacement block without changing the call site again...
    // Let's rely on the fact that `isHost` logic in `build` gave us `isHost` boolean but we need `hostId` string for the cards.
    
    // Correction: In the build method replacement, I passed the wrong thing?
    // Let's correct the call site in the previous chunk if possible? No, previous chunk is 'build'.
    // I need to make sure I passed the right thing in `build`.
    // In `build`, I have `hostId` available.
    // The call was: `_buildPlayerList(players, isHost ? FirebaseAuth.instance.currentUser?.uid : null)` <- THIS IS WRONG.
    // Use the `hostId` variable from the snapshot.
    // But local variables in `build` aren't easily visible here unless I change the signature.
    // Re-reading `build` code I proposed:
    // `final hostId = roomData['hostId'] as String?;`
    // I should pass `hostId` to `_buildPlayerList`.
    
    // Wait, the ReplacementChunk for `build` has: 
    // `_buildPlayerList(players, isHost ? FirebaseAuth.instance.currentUser?.uid : null)`
    // That needs to be fixed. I should pass `hostId` variable which I defined in `build`.
    // But `_buildPlayerList` signature is `(List players, String? hostId)`.
    
    return Column(
      children: players.map<Widget>((p) {
        final pMap = p as Map<String, dynamic>;
        final uid = pMap['uid'] as String? ?? 'unknown';
        
        // We need to compare pMap['uid'] with the actual room's hostId.
        // Since I cannot easily change the signature here without breaking things...
        // I will assume the `hostId` passed in IS the room's hostId.
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: PlayerCard(
            key: ValueKey(uid),
            uid: uid,
            username: pMap['username'] ?? 'Unknown',
            base64Image: pMap['profilePhotoBase64'],
            isHost: pMap['uid'] == hostId,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartButton(bool isHost) {
    // If not host, show "Waiting for host..." or similar? 
    // Or just hide/disable. User requested "clickable/visible for the Host".
    if (!isHost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: null, // Disabled
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200], // Light grey background
              foregroundColor: Colors.grey[600], // Muted text
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              'WAITING FOR HOST...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // TODO: Start Game Logic
          }, 
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            'START MATCH',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}




class PlayerCard extends StatelessWidget {
  final String uid;
  final String username;
  final String? base64Image;
  final bool isHost;

  const PlayerCard({
    super.key,
    required this.uid,
    required this.username,
    this.base64Image,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    // Decode Logic
    ImageProvider? imageProvider;
    final img = base64Image;
    if (img != null && img.isNotEmpty) {
      try {
        final clean = img.contains(',') ? img.split(',').last : img;
        imageProvider = MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    final displayHandle = username.startsWith('@') ? username : '@$username';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
           // Avatar (Double Ring)
           // Keyed to prevent flickering
            KeyedSubtree(
              key: ValueKey('avatar_$uid'),
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary, 
                    width: 2.0
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageProvider != null 
                      ? Image(
                          image: imageProvider, 
                          fit: BoxFit.cover,
                          gaplessPlayback: true, // Prevents white flash on rebuilds
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.person, color: Colors.grey[400]),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                displayHandle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Host Icon
            if (isHost)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.star_rounded, color: AppColors.primary, size: 28),
              ),
        ],
      ),
    );
  }
}
