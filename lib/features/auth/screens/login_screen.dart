import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/services/salon_lookup_service.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.successRoute = AppRoutes.userHome,
    this.signupRoute = AppRoutes.signup,
    this.role = UserRole.customer,
    this.title = "Welcome Back 👋",
    this.subtitle = "Login to continue to CutLine",
    this.signupPrompt = "Don’t have an account?",
    this.signupActionLabel = "Sign Up",
  });

  final String successRoute;
  final String signupRoute;
  final UserRole role;
  final String title;
  final String subtitle;
  final String signupPrompt;
  final String signupActionLabel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _emailController,
                        label: "Email",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required.';
                          if (!email.contains('@')) {
                            return 'Enter a valid email.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: "Password",
                        icon: Icons.lock_outline,
                        obscureText: !_isPasswordVisible,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final email = _emailController.text.trim();
                            if (email.isEmpty) {
                              _showSnack('Enter your email to reset password.');
                              return;
                            }

                            final sent = await auth.sendPasswordReset(email);
                            if (!context.mounted) return;
                            if (sent) {
                              _showSnack(
                                'Reset link sent. Check your email inbox.',
                              );
                            } else if (auth.lastError != null) {
                              _showSnack(auth.lastError!);
                            }
                          },
                    child: Text(
                      "Forgot Password?",
                      style: GoogleFonts.poppins(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            final success = await auth.signIn(
                              email: _emailController.text,
                              password: _passwordController.text,
                            );

                            if (!context.mounted) return;
                            if (success) {
                              await _routeByRole(auth);
                            } else if (auth.lastError != null) {
                              _showSnack(auth.lastError!);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            "Login",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.signupPrompt,
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.role == UserRole.barber) {
                          _showBarberBlockedDialog();
                          return;
                        }
                        Navigator.pushNamed(
                          context,
                          widget.signupRoute,
                          arguments: widget.role,
                        );
                      },
                      child: Text(
                        widget.signupActionLabel,
                        style: GoogleFonts.poppins(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: keyboardType == TextInputType.emailAddress
          ? TextInputAction.next
          : TextInputAction.done,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: suffixIcon,
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _routeByRole(AuthProvider auth) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final profile = await auth.fetchUserProfile(uid);
    if (!mounted) return;

    final roleKey = profile?['role'] as String?;
    final resolvedRole =
        roleKey != null ? UserRoleKey.fromKey(roleKey) : widget.role;
    final profileComplete = profile?['profileComplete'] == true;

    String target;
    switch (resolvedRole) {
      case UserRole.owner:
        final hasSalon = await SalonLookupService().salonExists(uid);
        if (!hasSalon) {
          await auth.setProfileComplete(false);
        }
        target = profileComplete && hasSalon
            ? AppRoutes.ownerHome
            : AppRoutes.ownerSalonSetup;
        break;
      case UserRole.barber:
        target = AppRoutes.barberHome;
        break;
      default:
        target = AppRoutes.userHome;
        break;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, target, (_) => false);
  }

  void _showBarberBlockedDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign up unavailable'),
        content: const Text(
          'Barbers cannot create accounts directly. Please ask your salon owner to create an account for you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
