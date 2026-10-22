import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import '../utils/auth_errors.dart';
import 'registration_submitted_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _regNoController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _role; // 'doctor' or 'nurse' (Administrator is not available here)
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regNoController.dispose();
    _workplaceController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // label of the registration number field changes with the selected role
  String get _regNoLabel {
    if (_role == 'doctor') return 'MMC Registration Number';
    if (_role == 'nurse') return 'Nursing Registration Number';
    return 'Professional Registration Number';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    UserCredential? credential;
    bool profileSaved = false;

    try {
      // 1. create the login account in Firebase Authentication
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );
      final user = credential.user!;
      await user.updateDisplayName(_nameController.text.trim());

      // 2. save the professional details in Firestore with status "pending"
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'role': _role,
        'registrationNo': _regNoController.text.trim(),
        'registrationType': _role == 'doctor' ? 'MMC' : 'Nursing',
        'workplace': _workplaceController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      profileSaved = true;

      // 3. sign out: no access until an administrator approves the account
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RegistrationSubmittedScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      // if the login account was created but the details were not saved,
      // remove the account so the user can register again cleanly
      if (credential != null && !profileSaved) {
        try {
          await credential.user?.delete();
        } catch (_) {}
      }
      if (e is FirebaseAuthException) {
        _showMessage(authErrorMessage(e.code));
      } else {
        _showMessage('Could not submit your registration (${e.code}). '
            'Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // heading and explanation
                Text(
                  'Create your professional account',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your account will require administrator verification '
                  'before access is granted.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. full name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. professional role (Doctor or Nurse only)
                DropdownButtonFormField<String>(
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(
                    labelText: 'Professional Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                  ],
                  onChanged: (value) {
                    setState(() => _role = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your professional role';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. professional registration number
                TextFormField(
                  controller: _regNoController,
                  decoration: InputDecoration(
                    labelText: _regNoLabel,
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    border: const OutlineInputBorder(),
                    helperText: 'This information will be used for '
                        'professional account verification.',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your registration number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. workplace (optional)
                TextFormField(
                  controller: _workplaceController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Workplace / Institution (optional)',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 7. confirm password
                TextFormField(
                  controller: _confirmController,
                  obscureText: _hidePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // create account button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Account',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),

                // back to sign in
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Sign In'),
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
}
