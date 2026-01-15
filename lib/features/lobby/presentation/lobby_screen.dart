import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Rule 3: For FilteringTextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert'; // Rule 3: For base64Decode
import 'dart:math'; // For random code generation
import 'package:cloud_firestore/cloud_firestore.dart'; // Rule 1: Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Rule 1: User type
import '../../auth/data/auth_repository.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/quick_match_section.dart'; // Rule: Import extracted widget
import '../../profile/presentation/profile_screen.dart';
import '../../friends/presentation/friends_screen.dart';
import 'create_room_screen.dart';


class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {


  final TextEditingController _joinCodeController = TextEditingController();
  bool _isCreatingRoom = false;
  bool _isJoiningRoom = false;
  
  // Cache the stream to prevent flickering on rebuilds
  Stream<DocumentSnapshot>? _userStream;
  String? _currentUid;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _createRoom(Map<String, dynamic> userData, String uid) async {
    if (_isCreatingRoom) return;
    
    // Step 1: Set loading state (triggers one rebuild, but stream is now cached)
    setState(() => _isCreatingRoom = true);

    try {
      // Step A: Generate Code Locally
      final code = _generateRoomCode();
      
      // Step B: Await Firestore Creation (No setStates here!)
      // We create the document and wait for the server to acknowledge
      await FirebaseFirestore.instance.collection('rooms').doc(code).set({
        'hostId': uid,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'players': [
          {
            'uid': uid,
            'username': userData['username'],
            'profilePhotoBase64': userData['profilePhotoBase64'],
            'isReady': true,
          }
        ]
      });

      // Step C: Navigate (only after await is done)
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CreateRoomScreen(userData: userData, roomCode: code)
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating room: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) setState(() => _isCreatingRoom = false);
    }
  }

  Future<void> _joinRoom(Map<String, dynamic> userData, String uid) async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 4-character code'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isJoiningRoom) return;
    setState(() => _isJoiningRoom = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(code);
      final doc = await docRef.get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] != 'waiting') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room is not accepting players'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      List players = List.from(data['players'] ?? []);
      final exists = players.any((p) => p['uid'] == uid);
      
      if (!exists) {
        if (players.length >= 4) {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Room is full'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        // Atomic update for safety
        await docRef.update({
          'players': FieldValue.arrayUnion([{
            'uid': uid,
            'username': userData['username'],
            'profilePhotoBase64': userData['profilePhotoBase64'],
            'isReady': false,
          }])
        });
      }

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CreateRoomScreen(userData: userData, roomCode: code)
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoiningRoom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch user data (kept active)
    final userAsync = ref.watch(authRepositoryProvider).currentUser;

    // Memoize the stream logic
    if (userAsync != null && userAsync.uid != _currentUid) {
      _currentUid = userAsync.uid;
      _userStream = FirebaseFirestore.instance.collection('users').doc(userAsync.uid).snapshots();
    }

    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Rule 3: Body Contrast
        appBar: AppBar(
          backgroundColor: Colors.white, // Rule 1: Fixed White
          scrolledUnderElevation: 0, // Rule 1: Disable Scroll Tint
          elevation: 0,
          shape: const Border(
            bottom: BorderSide(color: AppColors.primary, width: 0.5), // Rule: Primary Bottom Border
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark, // Rule 4: Dark Icons
          centerTitle: false, // Left Align
          title: const Text(
            'SubnetRush', // Rule 1: Text Only
            style: TextStyle(
              color: AppColors.primary, // Rule 1: Primary Color
              fontSize: 24, // Rule 1: Size 24
              fontWeight: FontWeight.w800, // Rule 1: Bold
              letterSpacing: -0.5,
            ),
          ),

        ),
        body: userAsync == null || _userStream == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<DocumentSnapshot>(
                stream: _userStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                     return Center(child: Text("Error loading profile: ${snapshot.error}"));
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0), // Rule 5: Padding 16
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Section 1: User Profile Header ---
                        FadeInSlide(
                          delay: 0.0,
                          child: _buildProfileCard(userAsync, userData),
                        ),
                        const SizedBox(height: 16), 

                        // --- Section 2: Stats & Social Hub ---
                        FadeInSlide(
                          delay: 0.1,
                          child: _buildStatsRow(userData),
                        ),
                        const SizedBox(height: 24), 

                        // Section 2: Game Modes
                        const FadeInSlide(
                          delay: 0.2,
                          child: QuickMatchSection(),
                        ), 
                        const SizedBox(height: 24), 
                        const SizedBox(height: 24), 
                        _buildLobbyActions(userData, userAsync.uid), // Children are animated internally
                        const SizedBox(height: 40), 
                    ],
                  ),
                );
              }
            ),
    );
  }




  Widget _buildProfileCard(User user, Map<String, dynamic> data) {
    // Rule 2: Username Logic
    final username = data['username'] as String? ?? user.email ?? 'NetRunner';
    
    // Rule 3: Base64 Image Logic (Cleaned)
    ImageProvider? profileImageProvider;
    final rawBase64 = data['profilePhotoBase64'] as String?; // Raw data
    
    if (rawBase64 != null && rawBase64.isNotEmpty) {
      try {
        // Rule: Split metadata (e.g. "data:image/jpeg;base64,") if present
        final cleanBase64 = rawBase64.contains(',') ? rawBase64.split(',').last : rawBase64;
        profileImageProvider = MemoryImage(base64Decode(cleanBase64));
      } catch (e) {
        // Fallback
        debugPrint('Error decoding profile image: $e');
        profileImageProvider = null;
      }
    }

    return _buildInnerProfileCard(username, profileImageProvider, data);
  }

  Widget _buildInnerProfileCard(String username, ImageProvider? imageProvider, Map<String, dynamic> userData) {
    // Format as handle if not already
    final handle = username.startsWith('@') ? username : '@$username'; // Simple check

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Rule 2: Rounded
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.0), // Rule: Subtle Border definition
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // Rule 3: Full Card Interactivity (InkWell)
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24), // Match container radius
        child: InkWell(
          onTap: () {
            if (userData.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userData: userData)));
            }
          }, // Navigate to Profile
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.transparent, // Rule 3: No Ripple
          highlightColor: Colors.grey.withOpacity(0.05), // Rule 3: Instant Highlight
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Rule 2: Robust Padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Rule 2: Center Alignment
              children: [
                // Rule 2: Avatar 'Double Ring' Effect
                Container(
                  padding: const EdgeInsets.all(3.0), // White Gap
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5), // Soft Primary Border
                      width: 2.0,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30, // Rule 2: Size ~60px total
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    foregroundColor: AppColors.primary,
                    backgroundImage: imageProvider, // Rule 3: MemoryImage if valid
                    child: imageProvider == null 
                        ? const Icon(Icons.person, size: 32) 
                        : null,
                  ),
                ),
                
                const SizedBox(width: 20), // Spacing

                // Text: Identity (No Badge, Clean)
                Expanded(
                  child: Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 20, // Rule 2: Size 20
                      fontWeight: FontWeight.w700, // Rule 2: Bold
                      color: Colors.black, // Rule 2: Black
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Action
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> userData) {
    final bestScores = userData['bestScores'] as Map<String, dynamic>? ?? {};

    return Row(
      children: [
        // --- Card A: Leaderboard (Polished & Clickable) ---
        Expanded(
          flex: 3, 
          child: _buildInfoCard(
            title: 'Leaderboard', // Rule: Renamed from Global Ranking to Leaderboard 
            // Rule: Clickability Cue (Header Row)
            headerIcon: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 20), // Rule: Primary Color
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22), // Rule: Chevron
              ],
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // Rule: Spread evenly
              children: [
                _RankStatItem(label: '1 MIN', modeKey: '60', currentScore: bestScores['60'] as int?),
                _RankStatItem(label: '3 MIN', modeKey: '180', currentScore: bestScores['180'] as int?),
                _RankStatItem(label: '5 MIN', modeKey: '300', currentScore: bestScores['300'] as int?),
              ],
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
            }, // Navigate
          ),
        ),
        const SizedBox(width: 16),
        // --- Card B: Community (Friends renamed) ---
        Expanded(
          flex: 2,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (context, snapshot) {
              List<String> followingIds = [];
              if (snapshot.hasData && snapshot.data!.exists) {
                 final data = snapshot.data!.data() as Map<String, dynamic>;
                 followingIds = List<String>.from(data['following'] ?? []);
              }

              // Logic: Get max 3 to display
              final displayIds = followingIds.take(3).toList();
              
              Widget content;
              if (displayIds.isEmpty) {
                 // Empty State
                 content = Center(
                   child: Text(
                     "No connections yet.",
                     style: TextStyle(
                       fontSize: 12,
                       fontWeight: FontWeight.w500,
                       color: Colors.grey[400],
                     ),
                   ),
                 );
              } else {
                  // Avatars State
                 content = StreamBuilder<QuerySnapshot>(
                   stream: FirebaseFirestore.instance
                       .collection('users')
                       .where(FieldPath.documentId, whereIn: displayIds)
                       .snapshots(),
                   builder: (context, userSnaps) {
                      if (!userSnaps.hasData) return const SizedBox();

                      final docs = userSnaps.data!.docs;
                      
                      // Dynamic Sizing Logic
                      double size = 40; // Default (Case 3)
                      if (docs.length == 1) size = 56; // Case 1: Large
                      else if (docs.length == 2) size = 46; // Case 2: Medium
                      
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: docs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final String? base64 = d['profilePhotoBase64'];
                          
                          ImageProvider? provider;
                          if (base64 != null && base64.isNotEmpty) {
                            try {
                              final clean = base64.contains(',') ? base64.split(',').last : base64;
                              provider = MemoryImage(base64Decode(clean));
                            } catch (_) {}
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Container(
                              width: size,
                              height: size,
                              padding: const EdgeInsets.all(2), // White Gap
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(size * 0.3), // Responsive Radius
                                border: Border.all(color: AppColors.primary, width: 2), 
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular((size * 0.3) - 2),
                                child: provider != null
                                  ? Image(image: provider, fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      child: Icon(Icons.person, size: size * 0.5, color: AppColors.primary),
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                   }
                 );
              }

              return _buildInfoCard(
                title: 'Community',
                headerIcon: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.primary, size: 22), 
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
                  ],
                ),
                centerContent: true, // Center alignment
                content: content,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLobbyActions(Map<String, dynamic> userData, String uid) {
    return Column(
      children: [
        FadeInSlide(
          delay: 0.3, 
          child: _buildCreateLobbyCard(userData, uid), // Rule: Upgraded Hero Card
        ),
        const SizedBox(height: 16), // Rule: Stack Spacing
        FadeInSlide(
          delay: 0.4,
          child: _buildJoinLobbyCard(userData, uid), // Rule: Redesigned Inline Input Card
        ),
      ],
    );
  }

  Widget _buildCreateLobbyCard(Map<String, dynamic> userData, String uid) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rule: Minimalist Icon (No Background)
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 34),
              const SizedBox(width: 16),
              
              // Rule: Stacked Text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Room',
                    style: TextStyle(
                      fontSize: 22, // Matched Hero Size
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Play with friends & team.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16), // Rule: Internal Spacing

          // Action Button (Outlined Style)
          SizedBox(
            height: 56, // Rule: Matched Height
            child: ElevatedButton(
              onPressed: _isCreatingRoom ? null : () => _createRoom(userData, uid),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shadowColor: Colors.transparent,
                side: const BorderSide(color: AppColors.primary, width: 2.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreatingRoom 
                  ? const SizedBox(
                      width: 24, height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                    )
                  : const Text(
                      'CREATE ROOM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinLobbyCard(Map<String, dynamic> userData, String uid) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Rule: Vertical Alignment
            children: [
              // Rule: Matched Icon Size (34)
              const Icon(Icons.login_rounded, color: AppColors.primary, size: 34),
              const SizedBox(width: 16),
              
              // Rule: Stacked Text (Matched Quick Match)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Join Room',
                    style: TextStyle(
                      fontSize: 22, // Rule: Matched Size
                      fontWeight: FontWeight.w800, // Rule: Matched Weight
                      color: Color(0xFF1E293B),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter invitation code to join.', // Rule: New Subtitle
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16), // Rule: Internal Spacing
          
          // Input & Action Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Rule: Full Width
            children: [
              SizedBox(
                 height: 56, // Rule: Generous Height
                 child: TextField(
                  controller: _joinCodeController,
                  textAlignVertical: TextAlignVertical.center,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'C 4 R 1',
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50], 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // Centered vertically by SizedBox
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                    color: Color(0xFF1E293B),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16), // Rule: Clean Gap
              
              SizedBox(
                height: 56, // Rule: Matched Height
                child: ElevatedButton(
                  onPressed: _isJoiningRoom ? null : () => _joinRoom(userData, uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // Rule: High-Contrast Background
                    foregroundColor: AppColors.primary, // Rule: Primary Text
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    side: const BorderSide(color: AppColors.primary, width: 2.0), // Rule: Solid Border
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isJoiningRoom 
                      ? const SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                        )
                      : const Text(
                        'JOIN ROOM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildInfoCard({
    required String title,
    required Widget headerIcon, // Changed to Widget for flexibility
    required Widget content,
    required VoidCallback onTap,
    bool centerContent = false, // Rule: Flexible Layout Strategy
  }) {
    return Container(
      height: 140, // Fixed height for alignment
      decoration: BoxDecoration(
        // Keep Shadow on Container
        boxShadow: [
           BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Subtle
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Rule 4: Premium Interaction (No Ripple)
      child: Material(
        color: Colors.white, // Moved color here
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Rule: Consistent Radius
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1.0), // Rule 4: Subtle Border
        ),
        clipBehavior: Clip.antiAlias, // Ensure InkWell is clipped
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent, 
          highlightColor: Colors.grey.withValues(alpha: 0.05), // Instant Highlight
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // Rule: Balanced Padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Rule: Always align to start so header stays at top
              mainAxisAlignment: MainAxisAlignment.start, 
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rule: Header Text Style (Dark Slate, Bold)
                    Text(
                      title, 
                      style: const TextStyle(
                        color: Color(0xFF1E293B), // Dark Slate
                        fontWeight: FontWeight.w700, // Bold
                        fontSize: 12
                      )
                    ),
                    headerIcon, // Render flexible icon
                  ],
                ),
                
                // Rule: Layout Fork
                if (centerContent) 
                  // Option A: Center Content (Friends)
                  // Header stays pinned top, content floats in the exact center of remaining space.
                  Expanded(
                    child: Center(
                      child: content,
                    ),
                  )
                else 
                  // Option B: Bottom Content (Leaderboard)
                  // Content pushed to the very bottom.
                  ...[
                    const Spacer(),
                    content,
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }






}

class _RankStatItem extends StatelessWidget {
  final String label;
  final String modeKey;
  final int? currentScore;

  const _RankStatItem({
    required this.label,
    required this.modeKey,
    required this.currentScore,
  });

  Future<int> _fetchRank() async {
    if (currentScore == null || currentScore == 0) return 0;
    
    // Count users with strictly higher score
    final countQuery = FirebaseFirestore.instance
        .collection('users')
        .where('bestScores.$modeKey', isGreaterThan: currentScore)
        .count();
        
    final snapshot = await countQuery.get();
    return (snapshot.count ?? 0) + 1; // Rank is count + 1
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          width: 50,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: (currentScore == null || currentScore == 0)
              ? const Text(
                  "-",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                )
              : FutureBuilder<int>(
                  future: _fetchRank(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        width: 14, 
                        height: 14, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: AppColors.primary.withOpacity(0.5)
                        )
                      );
                    }
                    
                    if (snapshot.hasError) {
                       return const Text(
                        "-",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final rank = snapshot.data ?? 0;
                    return Text(
                      "#$rank",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16, // Slightly smaller to fit #
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}





// --- Animation Utility ---
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final double delay;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
