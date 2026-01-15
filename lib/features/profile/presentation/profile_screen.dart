import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../auth/presentation/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // --- MOCK DATA ---

    // Title removed in simplified design


    // --- DATA PARSING ---
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    // Helper: Mode Label
    String getModeLabel(int duration) {
      return "${(duration / 60).round()} MIN";
    }

    // Helper: Parse Base64 Image
    ImageProvider getProfileImage(String? base64String) {
      if (base64String == null || base64String.isEmpty) {
        return const NetworkImage('https://i.pravatar.cc/150?img=12'); // Fallback
      }
      try {
        String clean = base64String;
        if (clean.contains(',')) clean = clean.split(',').last;
        clean = clean.trim().replaceAll(RegExp(r'[\n\r]'), '');
        return MemoryImage(base64Decode(clean));
      } catch (e) {
        return const NetworkImage('https://i.pravatar.cc/150?img=12');
      }
    }

    // Date Parsing
    DateTime joinedDate;
    try {
      joinedDate = DateTime.parse(userData['createdAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      joinedDate = DateTime.now();
    }
    final String formattedDate = DateFormat('d MMMM yyyy').format(joinedDate);

    // --- THEME ---
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = const Color(0xFFF8F9FA);
    final textColor = Colors.black87;


    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: primaryColor, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: primaryColor, size: 26),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // Force Hard Reset: Clear entire stack and push LoginScreen
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: primaryColor.withValues(alpha: 0.5), // Subtle purple divider
            height: 1.0,
          ),
        ),
      ),
      body: Column(
          children: [
            const SizedBox(height: 20),

            // --- 1. IDENTITY SECTION ---
            // --- 1. IDENTITY SECTION ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically Center
                children: [
                  // Avatar with Double Ring Effect
                  // Avatar with Double Ring Effect (Rounded Square)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: primaryColor,
                        width: 3.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(3.0), // White Gap (1:1 Ratio)
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.0), // Slightly less than outer
                      child: Builder(
                        builder: (context) {
                          // 1. Get Raw Data
                          String rawBase64 = userData['profilePhotoBase64'] ?? "";
                          
                          if (rawBase64.isEmpty) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.person, size: 50, color: Colors.grey),
                            );
                          }

                          // 2. Remove Prefix (data:image...)
                          String base64Data = rawBase64.contains(',') ? rawBase64.split(',').last : rawBase64;

                          // 3. CRITICAL FIX: Clean hidden formatting (newlines, CR)
                          String finalBase64 = base64Data.trim().replaceAll(RegExp(r'[\n\r]'), '');
                          
                          // Debug Print (Temporary)
                          if (finalBase64.isNotEmpty) {
                            debugPrint("Base64 Substring (First 30): ${finalBase64.substring(0, finalBase64.length > 30 ? 30 : finalBase64.length)}...");
                          }

                          try {
                            if (finalBase64.isEmpty) throw Exception("Empty Base64 String");

                            return Image.memory(
                              base64Decode(finalBase64),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint("Image Widget Error: $error");
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.person, size: 50, color: Colors.grey),
                                );
                              },
                            );
                          } catch (e) {
                            debugPrint("Decoding Error: $e");
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.person, size: 50, color: Colors.grey),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text Column (Right of Avatar)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username Logic
                        // Rule: Check if username already has '@'
                        Builder(
                          builder: (context) {
                            final rawUsername = userData['username'] ?? 'User';
                            final displayUsername = rawUsername.startsWith('@') 
                                ? rawUsername 
                                : '@$rawUsername';
                            
                            return Text(
                                displayUsername,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          );
                      },
                    ),
                        const SizedBox(height: 4),

                        // Real Name (Grey, Medium)
                        Text(
                          "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),



            // Joined Date (Below Header, Vertically Aligned with Avatar Spacing)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 6, bottom: 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Joined $formattedDate",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // --- 2. XP & PROGRESS ---
            




            // --- 3. PERSONAL BESTS ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Personal Records",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Builder(
                builder: (context) {
                  final bestScores = userData['bestScores'] as Map<String, dynamic>? ?? {};
                  
                  return Row(
                    children: [
                      _buildScoreCard(context, "1 MIN", (bestScores['60'] ?? 0).toString()),
                      const SizedBox(width: 12),
                      _buildScoreCard(context, "3 MIN", (bestScores['180'] ?? 0).toString()),
                      const SizedBox(width: 12),
                      _buildScoreCard(context, "5 MIN", (bestScores['300'] ?? 0).toString()),
                    ],
                  );
                }
              ),
            ),



            // --- 4. RECENT HISTORY ---
            // --- 4. RECENT HISTORY ---
            // --- 4. RECENT HISTORY ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: GestureDetector(
                onTap: () {}, // Placeholder for future navigation
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Recent Matches",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),


            
            // Gap matching Personal Records section
            const SizedBox(height: 10),

            // Use Expanded for the remaining space but manage list inside
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('matches')
                      .where('players', arrayContains: currentUserId)
                      .where('status', isEqualTo: 'finished')
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final myMatches = snapshot.data!.docs;

                    if (myMatches.isEmpty) {
                      return const Center(child: Text("No finished matches yet"));
                    }

                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: myMatches.length,
                      itemBuilder: (context, index) {
                         final doc = myMatches[index];
                         final data = doc.data() as Map<String, dynamic>;
                         
                         // 1. Identify Role & Data
                         final List<dynamic> players = data['players'] ?? [];
                         
                         // Identify Opponent ID
                         String opponentId = "";
                         if (players.length > 1) {
                           opponentId = players.firstWhere((id) => id != currentUserId, orElse: () => "");
                         }

                         // Extract Scores (Match Doc Source of Truth)
                         final Map<String, dynamic> scores = data['scores'] ?? {};
                         final int myScore = scores[currentUserId] ?? 0;
                         final int opScore = (opponentId.isNotEmpty) ? (scores[opponentId] ?? 0) : 0;
                         
                         final duration = data['duration'] ?? 60;

                         // Determine Status
                         String statusText;
                         Color statusColor;
                         if (myScore > opScore) {
                           statusText = "Won";
                           statusColor = Colors.green[600]!;
                         } else if (myScore < opScore) {
                           statusText = "Lost";
                           statusColor = Colors.red[600]!;
                         } else {
                           statusText = "Draw";
                           statusColor = Colors.grey[500]!;
                         }

                         // 2. Fetch Opponent Data (FutureBuilder)
                         return FutureBuilder<DocumentSnapshot>(
                           future: opponentId.isNotEmpty 
                               ? FirebaseFirestore.instance.collection('users').doc(opponentId).get()
                               : null,
                           builder: (context, userSnapshot) {
                             String opName = "Opponent";
                             String? opPhotoBase64; // Nullable

                             if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                               final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                               opName = userData['username'] ?? "Opponent";
                               opPhotoBase64 = userData['profilePhotoBase64'];
                             } else if (opponentId.isEmpty) {
                                opName = "Unknown";
                             }

                             return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Mode Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        getModeLabel(duration),
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Opponent Info
                                    Expanded(
                                      child: Row(
                                        children: [
                                           Container(
                                            width: 52,
                                            height: 52,
                                            padding: const EdgeInsets.all(2.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Theme.of(context).primaryColor,
                                                width: 2.0,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image(
                                                image: getProfileImage(opPhotoBase64),
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          
                                          // Username
                                          Expanded(
                                            child: Text(
                                              opName.startsWith('@') ? opName : '@$opName',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 12),

                                    // Status Text
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                           }
                         );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ), // Closes Column
      );
  }

  Widget _buildScoreCard(BuildContext context, String label, String score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                score,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // End of ProfileScreen
