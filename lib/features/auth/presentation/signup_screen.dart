import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../data/user_repository.dart';
import 'auth_controller.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginTap;
  
  const SignUpScreen({super.key, required this.onLoginTap});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  // Logic State
  int _currentStep = 0;
  File? _imageFile;
  
  // Validation State
  Timer? _debounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;
  bool _isCheckingEmail = false;
  bool _isSubmitting = false;

  // Password Visibility State
  bool _isPasswordVisible = false;
  bool _isPasswordNotEmpty = false;
  int _passwordStrengthScore = 0; // 0: Invalid, 1: Weak, 2: Good, 3: Strong

  
  // Form Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  
  // Keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _passwordController.removeListener(_updatePasswordState);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordState);
  }

  void _updatePasswordState() {
    setState(() {
      _isPasswordNotEmpty = _passwordController.text.isNotEmpty;
      _passwordStrengthScore = _calculatePasswordStrength(_passwordController.text);
    });
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1; // Tier 1: Weak (but has input)

    // Tier 2: Good (Length >= 6)
    int score = 2;
    
    // Tier 3: Strong (Length >= 6 AND (Digit OR Special Char))
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$&*]'));
    
    if (hasDigit || hasSpecial) {
      score = 3;
    }
    
    return score;
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
       _isUsernameUnique = null; // Reset status on type
       _isCheckingUsername = true; 
    });
    
    if (value.length < 3) {
      setState(() => _isCheckingUsername = false);
      return; 
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
       if (!mounted) return;
       // Normalize: lowercase and add prefix
       String usernameToCheck = value.trim().toLowerCase();
       if (!usernameToCheck.startsWith('@')) {
         usernameToCheck = '@$usernameToCheck';
       }

       // Check availability
       final isAvailable = await ref.read(userRepositoryProvider).isUsernameAvailable(usernameToCheck);
       if (!mounted) return;
       setState(() {
         _isCheckingUsername = false;
         _isUsernameUnique = isAvailable;
       });
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Compress image to ensure Firestore document size limit (1MB) is respected
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512, 
      maxHeight: 512,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (_step1Key.currentState!.validate()) {
        // Enforce Password Strength (Tier 2 or 3 required)
        if (_passwordStrengthScore < 2) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password is too short. Must be at least 6 characters.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        setState(() => _isCheckingEmail = true);
        try {
          // Check if email exists by attempting to sign in with a dummy password.
          // Requires "Email Enumeration Protection" to be DISABLED in Firebase Console.
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: 'dummy_checker_password_!@#',
          );
          // If login succeeds (highly unlikely), the email exists.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email is already in use. Please Log In.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isCheckingEmail = false);
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          if (e.code == 'wrong-password') {
            // Email exists, but password was wrong (as expected).
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This email is already in use. Please Log In.'),
                backgroundColor: AppColors.error,
              ),
            );
            setState(() => _isCheckingEmail = false);
          } else if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            // Email does not exist (or invalid creds with enum protection off means user not found).
            // Proceed to Step 2.
            setState(() {
              _isCheckingEmail = false;
              _currentStep = 1;
            });
          } else {
             // Other error (e.g. network)
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('Error: ${e.message}'),
                 backgroundColor: AppColors.error,
               ),
             );
             setState(() => _isCheckingEmail = false);
          }
        }
      }
    } else {
      if (_step2Key.currentState!.validate()) {
        _submit();
      }
    }
  }
  


  void _handleBackNavigation() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 0);
    } else {
      widget.onLoginTap();
    }
  }

  Future<void> _createAccount() async {
    setState(() => _isSubmitting = true);

    try {
      // 0. Final Username Availability Check (Blocking)
      String username = _usernameController.text.trim().toLowerCase();
      if (!username.startsWith('@')) {
        username = '@$username';
      }

      final isAvailable = await ref.read(userRepositoryProvider).isUsernameAvailable(username);
      if (!isAvailable) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This username was just taken. Please choose another.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Step A: Auth - Create User
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = userCredential.user!.uid;

      // Step B: Image Processing (Base64)
      String? profilePhotoBase64;
      if (_imageFile != null) {
        final bytes = _imageFile!.readAsBytesSync();
        final base64String = base64Encode(bytes);
        profilePhotoBase64 = 'data:image/jpeg;base64,$base64String';
      }

      // Step C: Database Write
      // Username is already normalized above

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'firstName': _nameController.text.trim(),
        'lastName': _surnameController.text.trim(),
        'username': username,
        'profilePhotoBase64': profilePhotoBase64, // Stored as Base64 string
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Navigation is handled by AuthWrapper (authState changes), 
      // but we can ensure state is cleared if needed.
       if (mounted) {
         setState(() => _isSubmitting = false);
         // Ensure we navigate if AuthWrapper doesn't pick it up immediately (redundant but safe)
         // Navigator.of(context).popUntil((route) => route.isFirst); 
       }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign Up Failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _submit() {
    _createAccount();
  }
  
  // --- UI Helpers ---
  
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isStep2 = _currentStep == 1;

    // Listen for errors
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary, size: 28),
          onPressed: _handleBackNavigation,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF9FAFB), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            child: Column(
              children: [
                // Title
                Text(
                  'Sign Up',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Segmented Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    children: [
                      // Step 1 Bar
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Step 2 Bar
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: isStep2 ? AppColors.primary : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Views
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isStep2 ? _buildStep2() : _buildStep1(),
                ),
                
                const SizedBox(height: 32),
                
                // Navigation Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (authState.isLoading || _isCheckingEmail || _isSubmitting || (_currentStep == 0 && _passwordStrengthScore < 2)) ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: (authState.isLoading || _isCheckingEmail || _isSubmitting)
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isStep2 ? 'Create Account' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputLabel('Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'Invalid email address' : null,
          ),
          const SizedBox(height: 24),
          
          // Static Password Label Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInputLabel('Password'),
              if (_isPasswordNotEmpty)
                Text(
                  _getStrengthText(),
                  style: TextStyle(
                    color: _getStrengthColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            decoration: _buildInputDecoration().copyWith(
              suffixIcon: _isPasswordNotEmpty
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textLight,
                      ),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    )
                  : null,
            ),
            obscuringCharacter: '●',
            obscureText: !_isPasswordVisible,
            style: const TextStyle(fontSize: 16, letterSpacing: 2.0),
            validator: (v) => v!.length < 6 ? 'Must be 6+ characters' : null,
          ),
          const SizedBox(height: 8),
          
          // Password Strength Bars (Bottom)
          if (_isPasswordNotEmpty) ...[
            Row(
              children: [
                Expanded(child: _buildStrengthBar(1)),
                const SizedBox(width: 6),
                Expanded(child: _buildStrengthBar(2)),
                const SizedBox(width: 6),
                Expanded(child: _buildStrengthBar(3)),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // Profile Picture Picker with Badge
           Center(
             child: GestureDetector(
               onTap: _pickImage,
               child: Stack(
                 children: [
                   CircleAvatar(
                     radius: 50,
                     backgroundColor: Colors.grey[200],
                     backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                     child: _imageFile == null 
                        ? const Icon(Icons.camera_alt, size: 32, color: AppColors.primary)
                        : null,
                   ),
                   Positioned(
                     bottom: 0,
                     right: 0,
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(
                         color: AppColors.primary,
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.white, width: 2),
                       ),
                       child: const Icon(Icons.add, size: 16, color: Colors.white),
                     ),
                   ),
                 ],
               ),
             ),
           ),
           const SizedBox(height: 32),

           // Name & Surname Row
           Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('First Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration(),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Last Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _surnameController,
                      decoration: _buildInputDecoration(),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildInputLabel('Username'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            onChanged: _onUsernameChanged,
            textCapitalization: TextCapitalization.none,
            decoration: _buildInputDecoration().copyWith(
              prefixText: '@ ',
              prefixStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
              suffixIcon: _isCheckingUsername 
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                  : (_isUsernameUnique == true 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : (_isUsernameUnique == false 
                          ? const Icon(Icons.error, color: AppColors.error) 
                          : null)),
            ),
            validator: (v) {
              if (v!.length < 3) return 'Min 3 chars';
              if (_isUsernameUnique == false) return 'Username taken';
              return null;
            },
          ),
        ],
      ),
    );
  }
  Widget _buildStrengthBar(int index) {
    Color color = Colors.grey[300]!;
    
    if (_passwordStrengthScore == 1) {
      if (index == 1) color = AppColors.error;
    } else if (_passwordStrengthScore == 2) {
      if (index <= 2) color = Colors.orange;
    } else if (_passwordStrengthScore == 3) {
      color = Colors.green; // All bars green
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _getStrengthText() {
    switch (_passwordStrengthScore) {
      case 1: return 'Too Weak';
      case 2: return 'Good';
      case 3: return 'Strong';
      default: return '';
    }
  }

  Color _getStrengthColor() {
    switch (_passwordStrengthScore) {
      case 1: return AppColors.error;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      default: return Colors.grey;
    }
  }
}
