
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../friends/presentation/friends_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Mode Keys for Query
  final List<String> _modeKeys = ['60', '180', '300'];
  final List<String> _modeLabels = ['1 MIN', '3 MIN', '5 MIN'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1); // Default to 3 MIN
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Leaderboard",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w800, 
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.2,
            color: AppColors.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // --- Tab Bar ---
          // --- Mode Selector (Refactored) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(0, '1 MIN'),
                const SizedBox(width: 12),
                _buildModeButton(1, '3 MIN'),
                const SizedBox(width: 12),
                _buildModeButton(2, '5 MIN'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Leaderboard List ---
          Expanded(
            child: _buildLeaderboardList(_modeKeys[_tabController.index]),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(int index, String label) {
    final bool isSelected = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isSelected) return;
          setState(() {
            _tabController.index = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(String modeKey) {
    // Firestore Query: Users sorted by bestScores.<modeKey>
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('bestScores.$modeKey', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading ranks"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
           return const Center(
             child: Text(
               "No records yet!\nBe the first to compete.",
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
             ),
           );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final int score = (data['bestScores'] ?? {})[modeKey] ?? 0;
            if (score == 0) return const SizedBox(); // Skip 0 scores if query didn't filter

            // Pass index + 1 as rank
            return _buildRankCard(index + 1, data, score);
          },
        );
      },
    );
  }

  Widget _buildRankCard(int rank, Map<String, dynamic> userData, int score) {
    final isMe = userData['uid'] == _currentUserId;

    // Avatar Logic
    final String? base64 = userData['profilePhotoBase64'];
    ImageProvider? imageProvider;
    if (base64 != null && base64.isNotEmpty) {
      try {
        final clean = base64.contains(',') ? base64.split(',').last : base64;
        imageProvider = MemoryImage(base64Decode(clean.trim().replaceAll(RegExp(r'[\n\r]'), '')));
      } catch (_) {}
    }

    // Name Logic
    final String username = userData['username'] ?? 'Runner';
    final String displayHandle = username.startsWith('@') ? username : '@$username';

    return Transform.scale(
      scale: isMe ? 1.02 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? Border.all(color: AppColors.primary.withOpacity(0.3)) : Border.all(color: Colors.transparent),
          boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Rank Number (Dynamic #1, #2, #3...)
            SizedBox(
              width: 40, // Slightly wider for readability
              child: Text(
                "#$rank",
                style: const TextStyle(
                  fontSize: 18, // Use 18 as requested
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // Avatar (Double Border)
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary, 
                  width: 2.0
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageProvider != null 
                    ? Image(image: imageProvider, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: Icon(Icons.person, color: Colors.grey[400]),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Identity (Handle Only)
            Expanded(
              child: Text(
                displayHandle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Score Bubble (Right)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$score",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
