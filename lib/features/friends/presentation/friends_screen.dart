import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/user_profile.dart';
import '../../profile/presentation/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialUserData; // Optional, if we want to pass current user data

  const FriendsScreen({super.key, this.initialUserData});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Community",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Left Align
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  // Auto-prefix '@'
                  if (value.isNotEmpty && !value.startsWith('@')) {
                    final newText = '@$value';
                    _searchController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                    value = newText;
                  }
                  
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search by username", // No dots
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // --- User Data Stream (To get friendIds) ---
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  return const Center(child: Text("Error loading data"));
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Parse Current User Data
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                // Pivot to 'following' array
                final List<String> followingIds = List<String>.from(userData['following'] ?? []);

                // MODE A: Search Results
                if (_searchQuery.isNotEmpty) {
                  return _buildSearchResults(followingIds);
                }

                // MODE B: Following List logic
                if (followingIds.isEmpty) {
                  // New Empty State (Below Search Bar)
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          "You Aren't Following Anyone Yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return _buildFollowingList(followingIds);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Search Logic ---
  Widget _buildSearchResults(List<String> currentFollowingIds) {
    return StreamBuilder<QuerySnapshot>(
      // Simple prefix search
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: _searchQuery)
          .where('username', isLessThan: '$_searchQuery\uf8ff')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
         return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No users found.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final uid = users[index].id;

            // Hide self
            if (uid == _currentUserId) return const SizedBox.shrink();

            final isFollowing = currentFollowingIds.contains(uid);

            return _buildUserCard(
              data: data,
              uid: uid,
              isFollowing: isFollowing,
            );
          },
        );
      },
    );
  }

  // --- Following List Logic ---
  Widget _buildFollowingList(List<String> followingIds) {
    // Note: Firestore 'whereIn' supports max 10 items.
    // For MVP, we take top 10. Robust solution requires chunking.
    final limitedIds = followingIds.take(10).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: limitedIds)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           return const Center(child: Text("No one found."));
        }

        final follows = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: follows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = follows[index].data() as Map<String, dynamic>;
            final uid = follows[index].id;

            return _buildUserCard(
              data: data,
              uid: uid,
              isFollowing: true,
            );
          },
        );
      },
    );
  }

  // --- User Card UI ---
  Widget _buildUserCard({
    required Map<String, dynamic> data,
    required String uid,
    required bool isFollowing,
  }) {
    // Data Parsing
    final String rawUsername = data['username'] ?? 'Unknown';
    // STRICT Username Logic: Clean duplicate '@' then add one prefix
    final String displayHandle = "@${rawUsername.replaceAll('@', '')}";
    
    // Handle Names (Legacy 'name' vs New 'firstName')
    final String firstName = data['firstName'] ?? data['name'] ?? '';
    final String lastName = data['lastName'] ?? data['surname'] ?? '';
    final String fullName = "$firstName $lastName".trim();

    final String? base64Image = data['profilePhotoBase64'];

    ImageProvider? imageProvider;
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        final clean = base64Image.contains(',') ? base64Image.split(',').last : base64Image;
        imageProvider = MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12), // Compact padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Avatar (Double-Border Square)
          Container(
            width: 54, // Fixed size
            height: 54,
            padding: const EdgeInsets.all(2.0), // The White Gap
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15), 
              border: Border.all(color: AppColors.primary, width: 2.0), // Primary Outer Ring
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11), // Inner radius to fit
              child: imageProvider != null
                  ? Image(image: imageProvider, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayHandle, // Corrected Handle
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullName.isNotEmpty ? fullName : "NetRunner", // Real Name
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Action Button (Follow / Unfollow) - Minimalist
          IconButton(
            onPressed: () => _toggleFollow(uid, isFollowing),
            icon: Icon(
              isFollowing ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded,
              color: AppColors.primary, // Always Primary Color
              size: 24,
            ),
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(), // Tight fit
          ),
          const SizedBox(width: 8), // Right padding
        ],
      ),
    );
  }

  // --- Actions ---
  Future<void> _toggleFollow(String targetUid, bool isFollowing) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
      if (isFollowing) {
        // Unfollow
        await docRef.update({
          'following': FieldValue.arrayRemove([targetUid])
        });
      } else {
        // Follow
        await docRef.update({
          'following': FieldValue.arrayUnion([targetUid])
        });
      }
    } catch (e) {
      debugPrint("Error toggling follow: $e");
    }
  }
}
