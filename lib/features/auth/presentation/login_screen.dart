import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import '../../../core/utils/snackbar_utils.dart'; // Import Utils

import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  bool _isButtonEnabled = false;
  bool _isLoading = false; // Local loading state
  String? _emailErrorText;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
  }

  void _validateInputs() {
    // Relaxed Check: Button enabled as long as fields are not empty
    final isEnabled = _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;
    
    if (_isButtonEnabled != isEnabled) {
      setState(() {
        _isButtonEnabled = isEnabled;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateInputs);
    _passwordController.removeListener(_validateInputs);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 1. Validation on Submit
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final email = _emailController.text.trim();
    
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _emailErrorText = 'Invalid email address';
      });
      return; // Stop here
    } else {
      setState(() {
         _emailErrorText = null;
      });
    }

    if (_formKey.currentState!.validate()) {
       setState(() => _isLoading = true);
       try {
          // Show Loading Indicator -> Handled by state
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', _rememberMe);
          // Navigate to Home on success - AuthWrapper handles this via stream
       } on FirebaseAuthException catch (e) {
          setState(() => _isLoading = false);
          
          String message = 'An error occurred. Please try again.';
          if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
             // SECURITY: Combine both errors to prevent email enumeration
             message = 'Invalid email or password.';
          } else if (e.code == 'too-many-requests') {
             // SECURITY: Brute-force protection
             message = 'Too many attempts. Please try again later.';
          } else if (e.code == 'user-disabled') {
             message = 'This account has been disabled.';
          } else {
             // Fallback for network errors or unknown states
             // ignore: avoid_print
             print('Unknown Auth Error: ${e.code}'); 
          }
          if (mounted) {
             SnackBarUtils.showError(context, message);
          }

       } catch (e) {
          setState(() => _isLoading = false);
          // Generic crash catcher
          if (mounted) {
             SnackBarUtils.showError(context, 'An unexpected error occurred.');
          }
          // ignore: avoid_print
          print('Generic Error: $e');
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        if (next.hasError) {
          String errorMessage = 'An error occurred. Please try again.';
          
          if (next.error is FirebaseAuthException) {
            final e = next.error as FirebaseAuthException;
            // ignore: avoid_print
            print('DEBUG AUTH ERROR: ${e.code}');
            
            // Normalize the error code and message to lowercase for easy checking
            String errorStr = '${e.code} ${e.message}'.toLowerCase();

            if (errorStr.contains('user-not-found') || 
                errorStr.contains('wrong password') || 
                errorStr.contains('password provided') || 
                errorStr.contains('invalid-credential') || 
                errorStr.contains('invalid_login_credentials') ||
                errorStr.contains('invalid email')) {
              errorMessage = 'Invalid email or password.';
            } else if (errorStr.contains('too-many-requests') || errorStr.contains('blocked')) {
              errorMessage = 'Too many attempts. Please try again later.';
            } else if (errorStr.contains('user-disabled')) {
              errorMessage = 'Account disabled.';
            } else if (errorStr.contains('network-request-failed')) {
               errorMessage = 'Check your internet connection.';
            } else {
               // ignore: avoid_print
               print('UNKNOWN AUTH ERROR: ${e.code}');
               errorMessage = 'An error occurred. Please try again.';
            }
          } else {
             // ignore: avoid_print
             print('DEBUG AUTH ERROR: ${next.error}');
          }

           SnackBarUtils.showError(context, errorMessage);
        }
      },
    );

    if (!_isLogin) {
      return Scaffold(
        body: SignUpScreen(
          onLoginTap: () {
             setState(() {
               _isLogin = true;
             });
          },
        ),
      );
    }
    
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Subtle gradient from very light grey/blue to white
            colors: [Color(0xFFF9FAFB), Colors.white], 
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header ---
                  Text(
                    'SubnetRush',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // --- Email Input ---
                  _buildInputLabel('Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: _buildInputDecoration().copyWith(
                      errorText: _emailErrorText,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (_emailErrorText != null) {
                        setState(() => _emailErrorText = null);
                      }
                    },
                    validator: (value) {
                       // We handle regex validation manually in _submit
                       if (value == null || value.isEmpty) return 'Required';
                       return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- Password Input ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInputLabel('Password'),
                      TextButton(
                        onPressed: () {
                          _showForgotPasswordSheet(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    obscuringCharacter: '●',
                    style: const TextStyle(
                      fontSize: 16,
                      letterSpacing: 2.0,
                    ),
                    decoration: _buildInputDecoration().copyWith(
                      suffixIcon: _passwordController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: AppColors.textLight,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            )
                          : null,
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Must be 6+ characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Remember Me Row ---
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Remember Me',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32), // Increased breathing room

                  // --- Login Button ---
                  ElevatedButton(
                    onPressed: (_isButtonEnabled && !_isLoading) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isButtonEnabled 
                          ? AppColors.primary 
                          : AppColors.primary.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('Log In'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // --- Footer ---
                  Center(
                    child: GestureDetector(
                      onTap: authState.isLoading 
                        ? null 
                        : () {
                            setState(() {
                              _isLogin = false;
                            });
                          },
                      child: RichText(
                        text: const TextSpan(
                          text: 'No account? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Taller inputs
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

  void _showForgotPasswordSheet(BuildContext context) {
    final resetEmailController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 16, // Reduced top padding to accommodate drag handle
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Drag Handle ---
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Title ---
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email to receive reset instructions.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 30), // Increased spacing

                // --- Email Input (Matching Main Login Style) ---
                _buildInputLabel('Email'),
                const SizedBox(height: 8),
                TextField(
                  controller: resetEmailController,
                  decoration: _buildInputDecoration(), // Matched style
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                ),
                
                const SizedBox(height: 30), // Increased spacing

                ElevatedButton(
                  onPressed: isLoading 
                    ? null 
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid email address')),
                          );
                          return;
                        }

                        setSheetState(() => isLoading = true);

                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          
                          if (!context.mounted) return;
                          SnackBarUtils.showSuccess(context, 'Reset link sent! Check your email.');
                        } catch (e) {
                          setSheetState(() => isLoading = false);
                          if (!context.mounted) return;
                          SnackBarUtils.showError(context, e.toString());
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Send Instructions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                ),
                const SizedBox(height: 32),
              ],
            );
          }
        ),
      ),
    );
  }
}
