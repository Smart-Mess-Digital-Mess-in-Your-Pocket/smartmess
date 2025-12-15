import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
// import 'dart:math'; // not used here

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'firebase_options.dart';

// SimpleBadge: lightweight replacement for newer Material `Badge` widget
class SimpleBadge extends StatelessWidget {
  final Widget child;
  final String label;
  final Color backgroundColor;

  const SimpleBadge({
    super.key,
    required this.child,
    required this.label,
    this.backgroundColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Mess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, fontFamily: 'Inter'),
      home: const SplashScreen(),
    );
  }
}

// 1. Colorful Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      _checkAuthStateAndNavigate();
    });
  }

  void _checkAuthStateAndNavigate() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, fetch their data and navigate
      try {
        var userDoc = await DatabaseService(uid: user.uid).getUserData();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          userData['uid'] = user.uid; // Ensure UID is in the map

          // Fetch mess name if messId exists
          if (userData.containsKey('messId') && userData['messId'] != null) {
            var messDoc = await DatabaseService().getMessData(
              userData['messId'],
            );
            if (messDoc.exists) {
              userData['messName'] =
                  (messDoc.data() as Map<String, dynamic>)['messName'];
            }
          }

          if (!mounted) return;

          // Navigate based on role
          if (userData['role'] == 'manager') {
            if (userData.containsKey('messId') && userData['messId'] != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MessManagerScreen(
                    userData: userData,
                    messName: userData['messName'] ?? 'My Mess',
                  ),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateMessScreen(userData: userData),
                ),
              );
            }
          } else {
            // Member
            if (userData.containsKey('messId') && userData['messId'] != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MemberDashboardScreen(userData: userData),
                ),
              );
            } else {
              // Member is logged in but hasn't joined a mess
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => JoinMessScreen(userData: userData),
                ),
              );
            }
          }
        } else {
          // User exists in Auth but not in Firestore, go to front page
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FrontPage()),
          );
        }
      } catch (e) {
        // On error, default to front page
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FrontPage()),
        );
      }
    } else {
      // No user is logged in, go to the front page
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FrontPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFF4ECDC4),
              Color(0xCC45B7D1),
              Color(0xFF96CEB4),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.3 * 255).round()),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'Smart Mess',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Digital Mess in Your Pocket',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withAlpha(
                            (0.3 * 255).round(),
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Beautiful Front Page (Notification Panel Removed)
class FrontPage extends StatefulWidget {
  const FrontPage({super.key});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section (Notification Panel Removed)
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.2 * 255).round()),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(
                            top: 25,
                            left: 25,
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 15,
                            right: 15,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(
                                  (0.2 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 15,
                            left: 15,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(
                                  (0.2 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.people,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Smart Mess',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Digital Mess in Your Pocket',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Buttons Section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.3 * 255).round()),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthScreen(isManager: true),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch, color: Color(0xFFFF6B6B)),
                            SizedBox(width: 10),
                            Text(
                              'CREATE MESS AS MANAGER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthScreen(isManager: false),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'JOIN AS MEMBER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Start your mess journey today',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Authentication Screen
class AuthScreen extends StatefulWidget {
  final bool isManager;

  const AuthScreen({super.key, required this.isManager});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Get AuthService instance
  final AuthService _authService = AuthService();

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        UserCredential userCredential = await _authService
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // Save user data to Firestore
        String role = widget.isManager ? 'manager' : 'member';
        await DatabaseService(uid: userCredential.user!.uid).saveUserData(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _phoneController.text.trim(),
          role,
        );

        final userData = {
          'uid': userCredential.user!.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': role,
        };

        if (!mounted) return;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful!'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isManager) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreateMessScreen(userData: userData),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => JoinMessScreen(userData: userData),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred. Please try again.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        UserCredential userCredential = await _authService
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // Fetch user data from Firestore
        var userDoc = await DatabaseService(
          uid: userCredential.user!.uid,
        ).getUserData();
        var userData = userDoc.data() as Map<String, dynamic>;

        // Add uid to the map for later use
        userData['uid'] = userCredential.user!.uid;

        // *** START: ROLE VERIFICATION LOGIC ***
        String actualRole = userData['role'];
        String expectedRole = widget.isManager ? 'manager' : 'member';

        if (actualRole != expectedRole) {
          String errorMessage = widget.isManager
              ? 'You are not a manager. Please use the "Join as Member" option.'
              : 'You are a manager. Please use the "Create Mess as Manager" option.';

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
            ),
          );
          return; // Stop the login process
        }
        // *** END: ROLE VERIFICATION LOGIC ***

        // Check if user has a messId and fetch messName
        if (userData.containsKey('messId') && userData['messId'] != null) {
          var messDoc = await DatabaseService().getMessData(userData['messId']);
          if (messDoc.exists) {
            userData['messName'] =
                (messDoc.data() as Map<String, dynamic>)['messName'];
          }
        }

        if (!mounted) return; // Check if the widget is still in the tree

        if (userData['role'] == 'manager') {
          if (userData.containsKey('messId') && userData['messId'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MessManagerScreen(
                  userData: userData,
                  messName: userData['messName'] ?? 'My Mess',
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CreateMessScreen(userData: userData),
              ),
            );
          }
        } else {
          // If member has joined a mess, go to dashboard. Otherwise, go to JoinMessScreen.
          if (userData.containsKey('messId') && userData['messId'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MemberDashboardScreen(userData: userData),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => JoinMessScreen(userData: userData),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Login failed. Please check your credentials.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'Invalid email or password.';
        }
        // This part is important to avoid showing a generic error after our custom role error
        if (!mounted) return;
        if (ScaffoldMessenger.of(context).mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 24,
                right: 24,
                bottom: 20,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin
                        ? 'Welcome Back!'
                        : widget.isManager
                        ? 'Create Manager Account'
                        : 'Create Member Account',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _isLogin
                        ? 'Sign in to continue'
                        : 'Join ${widget.isManager ? 'as Manager' : 'as Member'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin)
                          _buildTextField(
                            _nameController,
                            'Full Name',
                            Icons.person_outline,
                            false,
                          ),
                        if (!_isLogin) const SizedBox(height: 15),
                        if (!_isLogin)
                          _buildTextField(
                            _phoneController,
                            'Phone Number',
                            Icons.phone_android,
                            false,
                          ),
                        if (!_isLogin) const SizedBox(height: 15),

                        _buildTextField(
                          _emailController,
                          'Email Address',
                          Icons.email_outlined,
                          false,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          _passwordController,
                          'Password',
                          Icons.lock_outline,
                          true,
                        ),

                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLogin ? _login : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFF6B6B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _formKey.currentState?.reset();
                              _emailController.clear();
                              _passwordController.clear();
                              _nameController.clear();
                              _phoneController.clear();
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isLogin
                                  ? "Don't have an account? "
                                  : "Already have an account? ",
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontFamily: 'Inter',
                              ),
                              children: [
                                TextSpan(
                                  text: _isLogin ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isPassword,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        if (hint == 'Email Address' && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        if (hint == 'Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (hint == 'Phone Number' && value.length != 11) {
          return 'Phone number must be 11 digits';
        }
        return null;
      },
    );
  }
}

// 4. Join Mess Screen for Members
class JoinMessScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const JoinMessScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.group_add,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join a Mess',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ask your mess manager for the invite code\nto join their mess',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _showJoinDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ENTER INVITE CODE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const FrontPage()),
                  );
                },
                child: const Text(
                  'Back to Home',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) async {
    TextEditingController inviteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('Join Mess'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invite code provided by your mess manager'),
            const SizedBox(height: 20),
            TextField(
              controller: inviteController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter invite code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (inviteController.text.isNotEmpty) {
                // Call database service to join mess
                Map<String, dynamic>? messData = await DatabaseService(
                  uid: userData['uid'],
                ).joinMessWithCode(inviteController.text.trim());

                if (!context.mounted) return;

                Navigator.pop(context); // Close the dialog

                if (messData != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Successfully joined "${messData['messName']}"!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Update local userData and navigate to dashboard
                  userData['messId'] = messData['id'];
                  userData['messName'] = messData['messName'];

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MemberDashboardScreen(userData: userData),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid invite code. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an invite code.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

// 5. Create Mess Screen - Only for Managers
class CreateMessScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CreateMessScreen({super.key, required this.userData});

  @override
  State<CreateMessScreen> createState() => _CreateMessScreenState();
}

class _CreateMessScreenState extends State<CreateMessScreen> {
  final _messNameController = TextEditingController();
  String? _selectedMonth;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<void> _createMess() async {
    if (_messNameController.text.isNotEmpty && _selectedMonth != null) {
      // Create mess in Firestore
      String messId = await DatabaseService(uid: widget.userData['uid'])
          .createMess(
            _messNameController.text.trim(),
            _selectedMonth!,
            widget.userData['name'],
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mess "${_messNameController.text}" created successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.userData['messId'] = messId;
      widget.userData['messName'] = _messNameController.text;
      widget.userData['createdMonth'] = _selectedMonth;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MessManagerScreen(
            userData: widget.userData,
            messName: _messNameController.text,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Your Mess',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You are creating a mess as Manager',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                'Mess Name',
                'Enter mess name',
                _messNameController,
              ),
              const SizedBox(height: 20),
              _buildMonthDropdown(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _createMess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CREATE MESS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Month',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonth,
              hint: const Text(
                'Choose a month',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
              isExpanded: true,
              items: _months.map((String month) {
                return DropdownMenuItem<String>(
                  value: month,
                  child: Text(
                    month,
                    style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMonth = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

// 6. Enhanced Mess Manager Screen with Advanced UI - Quick Actions with Different Colors
class MessManagerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String messName;

  const MessManagerScreen({
    super.key,
    required this.userData,
    required this.messName,
  });

  @override
  State<MessManagerScreen> createState() => _MessManagerScreenState();
}

class _MessManagerScreenState extends State<MessManagerScreen> {
  int _memberCount = 0;
  int _totalMeals = 0;
  double _totalDeposit = 0.0;
  double _totalCost = 0.0;
  late DateTime _selectedDate;
  // Add other state variables for balance, meals etc. here

  @override
  void initState() {
    super.initState();
    _initializeDate();
    _fetchMessOverview();
  }

  void _initializeDate() {
    String? createdMonthName = widget.userData['createdMonth'];
    int monthIndex = _months.indexOf(createdMonthName ?? '');
    int monthNumber = (monthIndex != -1)
        ? monthIndex + 1
        : DateTime.now().month;
    int currentYear = DateTime.now().year;

    _selectedDate = DateTime(currentYear, monthNumber, 1);
  }

  Future<void> _fetchMessOverview() async {
    if (!mounted) return;
    if (widget.userData['messId'] != null) {
      List<DocumentSnapshot> members = await DatabaseService().getMessMembers(
        widget.userData['messId'],
      );
      int totalMeals = await DatabaseService().getTotalMessMealsForMonth(
        widget.userData['messId'],
        _selectedDate,
      );
      double totalDeposit = await DatabaseService().getTotalMessDeposit(
        widget.userData['messId'],
      );
      double totalCost = await DatabaseService().getTotalMessCostForMonth(
        widget.userData['messId'],
        _selectedDate,
      );

      if (mounted) {
        // Check again after async operations
        setState(() {
          _memberCount = members.length;
          _totalMeals = totalMeals;
          _totalDeposit = totalDeposit;
          _totalCost = totalCost;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null &&
        (picked.year != _selectedDate.year ||
            picked.month != _selectedDate.month)) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchMessOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    double balance = _totalDeposit - _totalCost;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFF6B6B).withAlpha((0.1 * 255).round()),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFFFF6B6B),
            ),
            onPressed: () {
              _showExitConfirmationDialog(context);
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.messName,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Manager (${widget.userData['name'] ?? ''})',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4ECDC4).withAlpha((0.1 * 255).round()),
            ),
            child: IconButton(
              icon: StreamBuilder<int>(
                stream: DatabaseService().unreadNotificationCountStream(
                  widget.userData['messId'] ?? '',
                  FirebaseAuth.instance.currentUser?.uid ?? '',
                ),
                builder: (context, snapshot) {
                  int count = snapshot.data ?? 0;
                  if (count > 0) {
                    return SimpleBadge(
                      label: count.toString(),
                      backgroundColor: Colors.red,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF4ECDC4),
                      ),
                    );
                  }
                  return const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF4ECDC4),
                  );
                },
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationScreen(
                      messId: widget.userData['messId'] ?? '',
                      currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Log Out',
            onPressed: () {
              _showLogoutConfirmationDialog(
                context,
                () => Navigator.of(context).pop(),
                () => _logout(context),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMessOverview,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.15 * 255).round()),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mess Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.userData['createdMonth'] ?? _months[_selectedDate.month - 1]} ${_selectedDate.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildEnhancedSummaryItem(
                          _memberCount.toString(),
                          'Members',
                          Icons.people_alt_outlined,
                          const Color(0xFFFF6B6B),
                        ),
                        _buildEnhancedSummaryItem(
                          '৳${balance.toStringAsFixed(2)}',
                          'Balance',
                          Icons.account_balance_wallet,
                          const Color(0xFF4ECDC4),
                        ),
                        _buildEnhancedSummaryItem(
                          _totalMeals.toString(),
                          'Total Meals',
                          Icons.restaurant_menu_outlined,
                          const Color(0xFF45B7D1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Quick Actions Grid with Different Colors
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildActionCard(
                    'Add Member',
                    Icons.person_add_alt_1,
                    const Color(0xFFFF6B6B),
                    const Color(0xFFFFF5F5),
                    () {
                      // Show invite code dialog
                      _showInviteCodeDialog(context, widget.userData['messId']);
                    },
                  ),
                  _buildActionCard(
                    'Add Deposit',
                    Icons.account_balance_wallet,
                    const Color(0xFF4ECDC4),
                    const Color(0xFFF0FDFA),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddDepositScreen(
                            messId: widget.userData['messId'],
                            managerName: widget.userData['name'],
                          ),
                        ), // Refresh data on return
                      ).then((_) => _fetchMessOverview());
                    },
                  ),
                  _buildActionCard(
                    'Add Meal',
                    Icons.restaurant_menu,
                    const Color(0xFF45B7D1),
                    const Color(0xFFF0F9FF),
                    () {
                      Navigator.push(
                        // Navigate and wait for a result
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddMealScreen(messId: widget.userData['messId']),
                        ),
                      ).then(
                        (_) => _fetchMessOverview(),
                      ); // Refresh data on return
                    },
                  ),
                  _buildActionCard(
                    'Add Cost',
                    Icons.attach_money,
                    const Color(0xFF96CEB4),
                    const Color(0xFFF0FDF4),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCostScreen(
                            messId: widget.userData['messId'],
                            managerUid: widget.userData['uid'],
                            managerName: widget.userData['name'],
                          ),
                        ), // Refresh data on return
                      ).then((_) => _fetchMessOverview());
                    },
                  ),
                  _buildActionCard(
                    // This was a duplicate, keeping it as is.
                    'Meal Rate',
                    Icons.monetization_on,
                    const Color(0xFFFFD166),
                    const Color(0xFFFFFBEB),
                    () {
                      _showMealRateDialog(context);
                    },
                  ),
                  _buildActionCard(
                    'Meal Requests',
                    Icons.touch_app,
                    const Color(0xFF6A0572),
                    const Color(0xFFFAF5FF),
                    () {
                      final nextDay = DateTime.now().add(
                        const Duration(days: 1),
                      );
                      final formattedDate =
                          "${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManagerMealRequestScreen(
                            messId: widget.userData['messId'],
                            date: formattedDate,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Management Sections
              _buildManagementSection('Mess Management', [
                _buildEnhancedMenuItem(
                  'Member Management',
                  Icons.people_outline,
                  Icons.group,
                  const Color(0xFFFF6B6B),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemberManagementScreen(
                          messId: widget.userData['messId'],
                          managerUid:
                              widget.userData['uid'], // Pass manager's UID
                        ),
                      ),
                    );
                  },
                ),
                _buildEnhancedMenuItem(
                  'Financial Overview',
                  Icons.pie_chart_outline,
                  Icons.bar_chart,
                  const Color(0xFF4ECDC4),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FinancialOverviewScreen(
                          selectedDate: _selectedDate,
                          messId: widget.userData['messId'],
                        ),
                      ),
                    );
                  },
                ),
                _buildEnhancedMenuItem(
                  'Meal Management',
                  Icons.restaurant_outlined,
                  Icons.fastfood,
                  const Color(0xFF45B7D1),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MealManagementScreen(
                          messId: widget.userData['messId'],
                          initialDate: _selectedDate,
                        ),
                      ),
                    ).then((_) => _fetchMessOverview());
                  },
                ), // onTap will be added later
                _buildEnhancedMenuItem(
                  'Cost Tracking',
                  Icons.receipt_long,
                  Icons.trending_up,
                  const Color(0xFF96CEB4),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CostTrackingScreen(
                          messId: widget.userData['messId'],
                          selectedDate: _selectedDate,
                        ),
                      ),
                    );
                  },
                ), // onTap will be added later
              ]),
              const SizedBox(height: 20),

              _buildManagementSection('Settings & Configuration', [
                _buildEnhancedMenuItem(
                  'Mess Settings',
                  Icons.settings_outlined,
                  Icons.tune,
                  const Color(0xFFFF6B6B),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessSettingsScreen(
                          messId: widget.userData['messId'],
                          messName: widget.messName,
                        ),
                      ),
                    ).then((value) {
                      // The 'value' returned from MessSettingsScreen is the new mess name.
                      // If it's a non-null String, it means the name was changed successfully.
                      if (value is String && value.isNotEmpty) {
                        if (!context.mounted) return;
                        // Update the local userData map with the new name.
                        widget.userData['messName'] = value;
                        // Rebuild the screen with the updated data.
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessManagerScreen(
                              userData: widget.userData,
                              messName: value, // Use the new name directly
                            ),
                          ),
                        );
                      }
                    });
                  },
                ),
                _buildEnhancedMenuItem(
                  'Change Manager',
                  Icons.manage_accounts,
                  Icons.swap_horiz,
                  const Color(0xFF4ECDC4),
                  () => _showChangeManagerWarning(context),
                ),
              ]),
              const SizedBox(height: 20),

              // Monthly Operations
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.05 * 255).round()),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(
                              0xFF4ECDC4,
                            ).withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF4ECDC4),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Monthly Operations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMonthOperation(
                            'Start New Month',
                            Icons.play_circle_fill,
                            const Color(0xFF4ECDC4),
                            () => _showStartNewMonthDialog(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMonthOperation(
                            'Monthly Records',
                            Icons.history,
                            const Color(0xFF6A0572),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportsScreen(
                                    messId: widget.userData['messId'],
                                    selectedDate: _selectedDate,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Danger Zone
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // This was the previous Monthly Operations, now it's Danger Zone
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withAlpha((0.2 * 255).round()),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha((0.05 * 255).round()),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Once you delete a mess, there is no going back. Please be certain.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton(
                        onPressed: () {
                          _showDeleteConfirmation(context);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Mess',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSummaryItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.2 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color iconColor,
    Color backgroundColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            // Reduced padding to prevent overflow
            padding: const EdgeInsets.all(10), // Changed from 16 to 10
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementSection(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Column(children: items),
        ],
      ),
    );
  }

  Widget _buildEnhancedMenuItem(
    String title,
    IconData icon,
    IconData trailingIcon,
    Color color, [
    VoidCallback? onTap,
  ]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(trailingIcon, size: 16, color: color),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildMonthOperation(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.2 * 255).round())),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeManagerWarning(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Change Manager?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to transfer ownership? You will become a regular member and lose manager access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showSelectNewManagerDialog(screenContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _showSelectNewManagerDialog(BuildContext screenContext) async {
    // Fetch members
    List<DocumentSnapshot> members = await DatabaseService().getMessMembers(
      widget.userData['messId'],
    );

    // Filter out current manager
    List<DocumentSnapshot> eligibleMembers = members
        .where((doc) => doc.id != widget.userData['uid'])
        .toList();

    if (!mounted) return;

    if (eligibleMembers.isEmpty) {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(
          content: Text('No other members to transfer ownership to.'),
        ),
      );
      return;
    }

    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select New Manager'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: eligibleMembers.length,
            itemBuilder: (context, index) {
              var memberData =
                  eligibleMembers[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4ECDC4),
                  child: Text(
                    memberData['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(memberData['name']),
                subtitle: Text(memberData['email'] ?? ''),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _confirmChangeManager(
                    screenContext,
                    eligibleMembers[index].id,
                    memberData['name'],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmChangeManager(
    BuildContext screenContext,
    String newManagerUid,
    String newManagerName,
  ) async {
    bool success = await DatabaseService().changeManager(
      messId: widget.userData['messId'],
      currentManagerUid: widget.userData['uid'],
      newManagerUid: newManagerUid,
      newManagerName: newManagerName,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(
          content: Text(
            'Ownership transferred to $newManagerName. Logging out...',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Logout and go to front page
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        screenContext,
        MaterialPageRoute(builder: (context) => const FrontPage()),
        (Route<dynamic> route) => false,
      );
    } else {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(
          content: Text('Failed to change manager. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStartNewMonthDialog(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calendar_today, color: Color(0xFF4ECDC4)),
            SizedBox(width: 8),
            Text('Start New Month?'),
          ],
        ),
        content: const Text(
          'This will archive the current month\'s data and reset calculations for the new month. Balances will be carried over.\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _selectNewMonthDate(screenContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Yes, Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectNewMonthDate(BuildContext context) async {
    // Calculate the required next month
    DateTime nextMonthDate = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      1,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: nextMonthDate,
      firstDate: nextMonthDate, // Restrict to next month onwards
      lastDate: DateTime(nextMonthDate.year + 1),
      helpText: 'SELECT THE NEW MONTH',
    );

    if (!mounted) return;

    if (picked != null) {
      // Validate that it is indeed the next month (ignoring day)
      if (picked.year == nextMonthDate.year &&
          picked.month == nextMonthDate.month) {
        await _processStartNewMonth(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid selection. You must select the immediate next month.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processStartNewMonth(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool success = await DatabaseService().startNewMonth(
      widget.userData['messId'],
      _selectedDate,
    );

    if (!mounted) return;
    Navigator.pop(context); // Pop loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New month started successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Update selected date to the new month and refresh
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          1,
        );
      });
      _fetchMessOverview();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start new month.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processDeleteMess(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool success = await DatabaseService().deleteMess(
      widget.userData['messId'],
    );

    if (!mounted) return;
    Navigator.pop(context); // Pop loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mess deleted successfully.'),
          backgroundColor: Colors.red,
        ),
      );

      // Update local user data
      widget.userData.remove('messId');
      widget.userData.remove('messName');

      // Sign out the user and take them to the login panel
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isManager: true),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete mess. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Mess?'),
          ],
        ),
        content: const Text(
          'This action cannot be undone. All data including members, meals, and financial records will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _processDeleteMess(screenContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(BuildContext context, String? messId) async {
    if (messId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Mess ID not found!')),
      );
      return;
    }
    // Fetch the invite code
    String? inviteCode = await DatabaseService().getInviteCode(messId);

    if (inviteCode == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch invite code!')),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('Mess Invite Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with new members to let them join:'),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite code copied to clipboard!'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inviteCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMealRateDialog(BuildContext context) {
    double mealRate = 0.0;
    if (_totalMeals > 0) {
      mealRate = _totalCost / _totalMeals;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Color(0xFFFFD166)),
            SizedBox(width: 8),
            Text('Current Meal Rate'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is the calculated meal rate for the current month based on total costs and meals.',
            ),
            const SizedBox(height: 20),
            Text('Total Cost: ৳${_totalCost.toStringAsFixed(2)}'),
            Text('Total Meals: $_totalMeals'),
            const Divider(height: 20, thickness: 1),
            Text(
              'Meal Rate: ৳${mealRate.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const FrontPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    VoidCallback onCancel,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out?'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName is coming soon!'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

Future<void> _showExitConfirmationDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red),
            SizedBox(width: 8),
            Text('Exit App?'),
          ],
        ),
        content: const Text('Are you sure you want to exit the app?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
            onPressed: () {
              SystemNavigator.pop();
            },
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      );
    },
  );
}

// 15. Meal Management Screen
class MealManagementScreen extends StatefulWidget {
  final String messId;
  final DateTime initialDate;

  const MealManagementScreen({
    super.key,
    required this.messId,
    required this.initialDate,
  });

  @override
  State<MealManagementScreen> createState() => _MealManagementScreenState();
}

class _MealManagementScreenState extends State<MealManagementScreen> {
  late DateTime _selectedDate;
  Map<String, int> _mealCounts = {};
  List<DocumentSnapshot> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _fetchDataForSelectedDate();
  }

  String _getFormattedDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDataForSelectedDate() async {
    setState(() {
      _isLoading = true;
    });

    // Fetch members if not already fetched
    if (_members.isEmpty) {
      _members = await DatabaseService().getMessMembers(widget.messId);
    }

    // Fetch meals for the selected date
    String formattedDate = _getFormattedDate(_selectedDate);
    DocumentSnapshot mealDoc = await DatabaseService().getDailyMeals(
      widget.messId,
      formattedDate,
    );

    Map<String, int> mealCounts = {};
    if (mealDoc.exists) {
      var mealData = mealDoc.data() as Map<String, dynamic>;
      if (mealData.containsKey('memberMeals')) {
        (mealData['memberMeals'] as Map<String, dynamic>).forEach((key, value) {
          mealCounts[key] = value as int;
        });
      }
    }

    if (mounted) {
      setState(() {
        _mealCounts = mealCounts;
        _isLoading = false;
      });
    }
  }

  void _showEditMealDialog(String memberUid, String memberName) {
    final TextEditingController mealController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    mealController.text = (_mealCounts[memberUid] ?? 0).toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Meal for $memberName'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: mealController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Number of Meals',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a meal count';
              }
              if (int.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              if (int.parse(value) < 0) {
                return 'Meal count cannot be negative';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                int newMealCount = int.parse(mealController.text);

                await DatabaseService().updateMealCount(
                  widget.messId,
                  _getFormattedDate(_selectedDate),
                  memberUid,
                  newMealCount,
                );

                if (!context.mounted) return;

                setState(() {
                  _mealCounts[memberUid] = newMealCount;
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Meal count for $memberName updated to $newMealCount.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF45B7D1),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime firstDayOfMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    DateTime lastDayOfMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month + 1,
      0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Management'),
        backgroundColor: const Color(0xFF45B7D1),
      ),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: firstDayOfMonth,
            lastDate: lastDayOfMonth,
            onDateChanged: (newDate) {
              setState(() {
                _selectedDate = newDate;
              });
              _fetchDataForSelectedDate();
            },
          ),
          const Divider(thickness: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      var memberData =
                          _members[index].data() as Map<String, dynamic>;
                      String memberUid = _members[index].id;
                      String memberName = memberData['name'] ?? 'N/A';
                      String displayName =
                          memberName +
                          ((memberData['role'] ?? '') == 'manager'
                              ? ' (Manager)'
                              : '');
                      int mealCount = _mealCounts[memberUid] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              memberName.isNotEmpty ? memberName[0] : '?',
                            ),
                          ),
                          title: Text(displayName),
                          trailing: Text(
                            mealCount.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF45B7D1),
                            ),
                          ),
                          onTap: () =>
                              _showEditMealDialog(memberUid, memberName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 16. Mess Settings Screen
class MessSettingsScreen extends StatefulWidget {
  final String messId;
  final String messName;

  const MessSettingsScreen({
    super.key,
    required this.messId,
    required this.messName,
  });

  @override
  State<MessSettingsScreen> createState() => _MessSettingsScreenState();
}

class _MessSettingsScreenState extends State<MessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _messNameController;
  String? _inviteCode;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _messNameController = TextEditingController(text: widget.messName);
    _fetchInviteCode();
  }

  Future<void> _fetchInviteCode() async {
    setState(() {
      _isLoading = true;
    });
    final code = await DatabaseService().getInviteCode(widget.messId);
    if (mounted) {
      setState(() {
        _inviteCode = code;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final newName = _messNameController.text.trim();
      bool success = await DatabaseService().updateMessName(
        widget.messId,
        newName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mess name updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
            newName,
          ); // Pass true to indicate changes were made
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update mess name.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Settings'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _messNameController,
                      decoration: const InputDecoration(
                        labelText: 'Mess Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mess name cannot be empty.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Invite Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _inviteCode ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.grey),
                            onPressed: () {
                              if (_inviteCode != null) {
                                Clipboard.setData(
                                  ClipboardData(text: _inviteCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invite code copied!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SAVE CHANGES',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 14. Cost Tracking Screen with Graph
class CostTrackingScreen extends StatefulWidget {
  final String messId;
  final DateTime selectedDate;

  const CostTrackingScreen({
    super.key,
    required this.messId,
    required this.selectedDate,
  });

  @override
  State<CostTrackingScreen> createState() => _CostTrackingScreenState();
}

class _CostTrackingScreenState extends State<CostTrackingScreen> {
  bool _isLoading = true;
  List<DocumentSnapshot> _costs = [];
  Map<int, double> _dailyCosts = {};

  @override
  void initState() {
    super.initState();
    _fetchCosts();
  }

  Future<void> _fetchCosts() async {
    setState(() {
      _isLoading = true;
    });

    final costs = await DatabaseService().getMessCostsForMonth(
      widget.messId,
      widget.selectedDate,
    );

    Map<int, double> dailyCosts = {};
    for (var costDoc in costs) {
      final data = costDoc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final amount = (data['amount'] as num).toDouble();
      dailyCosts.update(
        date.day,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    if (mounted) {
      setState(() {
        _costs = costs;
        _dailyCosts = dailyCosts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthName = _months[widget.selectedDate.month - 1];
    String year = widget.selectedDate.year.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Cost Tracking for $monthName $year'),
        backgroundColor: const Color(0xFF96CEB4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _costs.isEmpty
          ? const Center(child: Text('No costs recorded for this month.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Daily Cost Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildSimpleBarChartWidget(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'All Expenses',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ..._costs.map((cost) => _buildCostListItem(cost)),
              ],
            ),
    );
  }

  Widget _buildSimpleBarChartWidget() {
    // A simple horizontal-scrollable bar chart replacement using Container widgets.
    final entries = _dailyCosts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    double maxVal = entries
        .map((e) => e.value)
        .fold(0.0, (double prev, double elem) => elem > prev ? elem : prev);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.map((entry) {
          final day = entry.key;
          final value = entry.value;
          final height = maxVal == 0 ? 0.0 : (value / maxVal) * 150.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '৳${value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 20,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF96CEB4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(day.toString(), style: const TextStyle(fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCostListItem(DocumentSnapshot costDoc) {
    final data = costDoc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final formattedDate = "${date.day}/${date.month}/${date.year}";

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.shopping_cart, color: Color(0xFF96CEB4)),
        title: Text(data['details'] ?? 'No details'),
        subtitle: Text('By: ${data['memberName']} on $formattedDate'),
        trailing: Text(
          '৳${(data['amount'] as num).toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// 13. Reports Screen
class ReportsScreen extends StatefulWidget {
  final String messId;
  final DateTime selectedDate;

  const ReportsScreen({
    super.key,
    required this.messId,
    required this.selectedDate,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _memberReports = [];
  double _totalCost = 0.0;
  int _totalMeals = 0;
  double _mealRate = 0.0;
  late DateTime _currentSelectedDate;

  @override
  void initState() {
    super.initState();
    _currentSelectedDate = widget.selectedDate;
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
    });

    final dbService = DatabaseService();

    // 0. Check for Archived Report
    final archivedDoc = await dbService.getArchivedReport(
      widget.messId,
      _currentSelectedDate,
    );

    if (archivedDoc.exists) {
      final data = archivedDoc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _totalCost = (data['totalCost'] as num).toDouble();
          _totalMeals = (data['totalMeals'] as num).toInt();
          _mealRate = (data['mealRate'] as num).toDouble();
          _memberReports = List<Map<String, dynamic>>.from(
            data['memberReports'],
          );
          _isLoading = false;
        });
      }
      return;
    }

    // Fetch all necessary data
    final totalCost = await dbService.getTotalMessCostForMonth(
      widget.messId,
      _currentSelectedDate,
    );
    final totalMeals = await dbService.getTotalMessMealsForMonth(
      widget.messId,
      _currentSelectedDate,
    );
    final members = await dbService.getMessMembers(widget.messId);

    final mealRate = (totalMeals > 0) ? totalCost / totalMeals : 0.0;

    List<Map<String, dynamic>> memberReports = [];

    for (var memberDoc in members) {
      final memberData = memberDoc.data() as Map<String, dynamic>;
      final memberUid = memberDoc.id;

      final memberMeals = await dbService.getMemberTotalMealsForMonth(
        widget.messId,
        memberUid,
        _currentSelectedDate,
      );

      final memberCost = memberMeals * mealRate;
      final totalDeposit = (memberData['totalDeposit'] ?? 0.0).toDouble();
      final balance = totalDeposit - memberCost;

      memberReports.add({
        'name': memberData['name'] ?? 'N/A',
        'meals': memberMeals,
        'cost': memberCost,
        'deposit': totalDeposit,
        'balance': balance,
      });
    }

    if (mounted) {
      setState(() {
        _totalCost = totalCost;
        _totalMeals = totalMeals;
        _mealRate = mealRate;
        _memberReports = memberReports;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT MONTH TO VIEW',
    );
    if (picked != null &&
        (picked.year != _currentSelectedDate.year ||
            picked.month != _currentSelectedDate.month)) {
      setState(() {
        _currentSelectedDate = DateTime(picked.year, picked.month, 1);
      });
      _generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthName = _months[_currentSelectedDate.month - 1];
    String year = _currentSelectedDate.year.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Report for $monthName $year'),
        backgroundColor: const Color(0xFF6A0572),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Change Month',
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _generateReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'Member Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._memberReports.map(
                    (report) => _buildMemberReportCard(report),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A0572), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            _buildSummaryRow(
              'Total Cost:',
              '৳${_totalCost.toStringAsFixed(2)}',
            ),
            const Divider(color: Colors.white54),
            _buildSummaryRow('Total Meals:', _totalMeals.toString()),
            const Divider(color: Colors.white54),
            _buildSummaryRow('Meal Rate:', '৳${_mealRate.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberReportCard(Map<String, dynamic> report) {
    Color balanceColor = (report['balance'] as double) >= 0
        ? Colors.green
        : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report['name'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildDetailRow('Total Meals:', report['meals'].toString()),
            _buildDetailRow(
              'Total Cost:',
              '৳${(report['cost'] as double).toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              'Total Deposit:',
              '৳${(report['deposit'] as double).toStringAsFixed(2)}',
            ),
            const Divider(height: 20),
            _buildDetailRow(
              'Balance:',
              '৳${(report['balance'] as double).toStringAsFixed(2)}',
              valueColor: balanceColor,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String title,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF111827),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

// 6.5 Month List (used in MessManagerScreen)
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// 10. Add Meal Screen
class AddMealScreen extends StatefulWidget {
  final String messId;

  const AddMealScreen({super.key, required this.messId});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mealCountController = TextEditingController();

  List<DocumentSnapshot> _members = [];
  String? _selectedMemberUid;
  String? _selectedMemberName;
  bool _isLoading = true;
  bool _isSubmitting = false;
  late String _todayDate;

  @override
  void initState() {
    super.initState();
    _todayDate = _getFormattedDate(DateTime.now());
    _fetchMembers();
  }

  String _getFormattedDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
    });

    // Fetch members
    _members = await DatabaseService().getMessMembers(widget.messId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitMeal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      int mealsToAdd = int.parse(_mealCountController.text);

      // Update in Firestore
      await DatabaseService().addMeal(
        messId: widget.messId,
        date: _todayDate,
        memberUid: _selectedMemberUid!,
        mealsToAdd: mealsToAdd,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $mealsToAdd meals for $_selectedMemberName.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal'),
        backgroundColor: const Color(0xFF45B7D1),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: $_todayDate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Member Selection Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMemberUid,
                      hint: const Text('Select a member'),
                      decoration: const InputDecoration(
                        labelText: 'Member',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _members.map((memberDoc) {
                        final memberData =
                            memberDoc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: memberDoc.id,
                          child: Text(
                            '${memberData['name'] ?? 'N/A'}${(memberData['role'] == 'manager') ? ' (Manager)' : ''}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selectedMember = _members.firstWhere(
                          (doc) => doc.id == value,
                        );
                        final memberData =
                            selectedMember.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedMemberUid = value;
                          _selectedMemberName = memberData['name'];
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a member' : null,
                    ),
                    const SizedBox(height: 20),

                    // Meal Count
                    TextFormField(
                      controller: _mealCountController,
                      decoration: const InputDecoration(
                        labelText: 'Number of Meals',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant_menu),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter number of meals';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Please enter a valid number greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitMeal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF45B7D1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'ADD MEAL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 11. Add Cost Screen
class AddCostScreen extends StatefulWidget {
  final String messId;
  final String managerUid;
  final String managerName;

  const AddCostScreen({
    super.key,
    required this.messId,
    required this.managerUid,
    required this.managerName,
  });

  @override
  State<AddCostScreen> createState() => _AddCostScreenState();
}

class _AddCostScreenState extends State<AddCostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();

  List<DocumentSnapshot> _members = [];
  String? _selectedMemberUid;
  String? _selectedMemberName;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    List<DocumentSnapshot> members = await DatabaseService().getMessMembers(
      widget.messId,
    );
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCost() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      await DatabaseService().addMessCost(
        messId: widget.messId,
        memberUid: _selectedMemberUid!,
        memberName: _selectedMemberName!,
        details: _detailsController.text.trim(),
        amount: double.parse(_amountController.text),
        managerUid: widget.managerUid,
        managerName: widget.managerName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cost added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Mess Cost'),
        backgroundColor: const Color(0xFF96CEB4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Selection Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMemberUid,
                      hint: const Text('Select Member'),
                      decoration: const InputDecoration(
                        labelText: 'Who did the shopping?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _members.map((memberDoc) {
                        final memberData =
                            memberDoc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: memberDoc.id,
                          child: Text(
                            '${memberData['name'] ?? 'N/A'}${(memberData['role'] == 'manager') ? ' (Manager)' : ''}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selectedMember = _members.firstWhere(
                          (doc) => doc.id == value,
                        );
                        final memberData =
                            selectedMember.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedMemberUid = value;
                          _selectedMemberName = memberData['name'];
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a member' : null,
                    ),
                    const SizedBox(height: 20),

                    // Cost Details
                    TextFormField(
                      controller: _detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Shopping Details',
                        hintText: 'e.g., Vegetables, Fish, Oil...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.list_alt),
                      ),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter the shopping details'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF96CEB4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SUBMIT COST',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 12. Financial Overview Screen
class FinancialOverviewScreen extends StatefulWidget {
  final String messId;
  final DateTime selectedDate;

  const FinancialOverviewScreen({
    super.key,
    required this.messId,
    required this.selectedDate,
  });

  @override
  State<FinancialOverviewScreen> createState() =>
      _FinancialOverviewScreenState();
}

class _FinancialOverviewScreenState extends State<FinancialOverviewScreen> {
  late Future<List<DocumentSnapshot>> _costsFuture;

  @override
  void initState() {
    super.initState();
    _costsFuture = DatabaseService().getMessCostsForMonth(
      widget.messId,
      widget.selectedDate,
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Overview'),
        backgroundColor: const Color(0xFF4ECDC4),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _costsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No costs have been added for this month.'),
            );
          }

          List<DocumentSnapshot> costs = snapshot.data!;
          double totalCost = costs.fold(
            0.0,
            (total, doc) => total + (doc['amount'] as num).toDouble(),
          );

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20.0),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Cost This Month',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '৳${totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: costs.length,
                  itemBuilder: (context, index) {
                    var costData = costs[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.shopping_cart,
                          color: Color(0xFF96CEB4),
                        ),
                        title: Text(costData['details']),
                        subtitle: Text(
                          'By: ${costData['memberName']} on ${_formatDate(costData['date'])}',
                        ),
                        trailing: Text(
                          '৳${(costData['amount'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 8. Add Deposit Screen for Manager
class AddDepositScreen extends StatefulWidget {
  final String messId;
  final String managerName;

  const AddDepositScreen({
    super.key,
    required this.messId,
    required this.managerName,
  });

  @override
  State<AddDepositScreen> createState() => _AddDepositScreenState();
}

class _AddDepositScreenState extends State<AddDepositScreen> {
  late Future<List<DocumentSnapshot>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = DatabaseService().getMessMembers(widget.messId);
  }

  void _showAddDepositDialog(
    String memberUid,
    String memberName,
    double currentDeposit,
  ) {
    final TextEditingController amountController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Deposit for $memberName'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Deposit: ৳$currentDeposit'),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double amount = double.parse(amountController.text);
                await DatabaseService().addDeposit(
                  widget.messId,
                  memberUid,
                  memberName,
                  amount,
                  widget.managerName,
                );

                if (!context.mounted) return;
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ৳$amount to $memberName\'s deposit.'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh the list
                setState(() {
                  _membersFuture = DatabaseService().getMessMembers(
                    widget.messId,
                  );
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Member Deposit'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No members found in this mess.'));
          }

          List<DocumentSnapshot> members = snapshot.data!;
          // Calculate total mess deposit
          double totalMessDeposit = 0.0;
          for (var memberDoc in members) {
            var memberData = memberDoc.data() as Map<String, dynamic>;
            totalMessDeposit += (memberData['totalDeposit'] ?? 0.0).toDouble();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20.0),
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Mess Deposit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '৳${totalMessDeposit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 6),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    var memberData =
                        members[index].data() as Map<String, dynamic>;
                    String memberName = memberData['name'] ?? 'No Name';
                    double totalDeposit = (memberData['totalDeposit'] ?? 0.0)
                        .toDouble();
                    String memberUid = members[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4ECDC4),
                          child: Text(
                            memberName.isNotEmpty
                                ? memberName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          memberName +
                              ((memberData['role'] ?? '') == 'manager'
                                  ? ' (Manager)'
                                  : ''),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Deposit: ৳${totalDeposit.toStringAsFixed(2)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Color(0xFFFF6B6B),
                          ),
                          onPressed: () {
                            _showAddDepositDialog(
                              memberUid,
                              memberName,
                              totalDeposit,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 9. Member Management Screen
class MemberManagementScreen extends StatefulWidget {
  final String messId;
  final String managerUid;

  const MemberManagementScreen({
    super.key,
    required this.messId,
    required this.managerUid,
  });

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  Future<List<DocumentSnapshot>>? _membersFuture;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _membersFuture = DatabaseService().getMessMembers(widget.messId);
  }

  void _refreshMemberList() {
    setState(() {
      _membersFuture = _databaseService.getMessMembers(widget.messId);
    });
  }

  Future<void> _removeMember(String memberUid, String memberName) async {
    bool success = await _databaseService.removeMemberFromMess(
      widget.messId,
      memberUid,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$memberName has been removed from the mess.'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshMemberList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove member. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveConfirmationDialog(String memberUid, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Member?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$memberName" from the mess? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _removeMember(memberUid, memberName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Management'),
        backgroundColor: const Color(0xFF4ECDC4),
        elevation: 0,
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No members found.'));
          }

          // Filter out manager from removable members list
          List<DocumentSnapshot> members = snapshot.data!
              .where((doc) => doc.id != widget.managerUid)
              .toList();

          if (members.isEmpty) {
            return const Center(child: Text('No removable members found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: members.length,
            itemBuilder: (context, index) {
              var memberData = members[index].data() as Map<String, dynamic>;
              String memberUid = members[index].id;
              String memberName = memberData['name'] ?? 'N/A';
              String memberPhone = memberData['phone'] ?? 'N/A';
              double totalDeposit = (memberData['totalDeposit'] ?? 0.0)
                  .toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xCCFF6B6B),
                        child: Text(
                          memberName.isNotEmpty ? memberName[0] : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memberName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: $memberPhone',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '৳${totalDeposit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showRemoveConfirmationDialog(
                          memberUid,
                          memberName,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Remove member',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 7. Enhanced Member Dashboard Screen with Advanced UI - Quick Actions with Different Colors
class MemberDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MemberDashboardScreen({super.key, required this.userData});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  double _totalMessDeposit = 0.0;
  int _myTotalMeals = 0;
  int _totalMessMeals = 0;
  double _totalMessCost = 0.0;
  double _mealRate = 0.0;
  double _messBalance = 0.0;
  double _myCost = 0.0;
  double _myBalance = 0.0;
  DateTime _currentDate = DateTime.now();
  // Add other state variables for balance, meals etc. here

  @override
  void initState() {
    super.initState();
    _fetchMessStats();
  }

  Future<void> _fetchMessStats() async {
    if (widget.userData['messId'] != null) {
      final dbService = DatabaseService();

      // 1. Get Mess Data to find current session date
      DocumentSnapshot messDoc = await dbService.getMessData(
        widget.userData['messId'],
      );
      if (messDoc.exists) {
        final data = messDoc.data() as Map<String, dynamic>;
        if (data.containsKey('currentSessionDate')) {
          _currentDate = (data['currentSessionDate'] as Timestamp).toDate();
        }
      }

      List<DocumentSnapshot> members = await DatabaseService().getMessMembers(
        widget.userData['messId'],
      );
      double totalDeposit = 0.0;
      for (var memberDoc in members) {
        var memberData = memberDoc.data() as Map<String, dynamic>;
        totalDeposit += (memberData['totalDeposit'] ?? 0.0).toDouble();
      }

      // Fetch member's total meals for the current month
      int myMeals = await dbService.getMemberTotalMealsForMonth(
        widget.userData['messId'],
        widget.userData['uid'],
        _currentDate,
      );

      // Fetch mess's total meals for the current month
      int messMeals = await dbService.getTotalMessMealsForMonth(
        widget.userData['messId'],
        _currentDate,
      );

      // Fetch total mess cost to calculate meal rate
      double totalMessCost = await dbService.getTotalMessCostForMonth(
        widget.userData['messId'],
        _currentDate,
      );

      // --- Calculations ---
      final mealRate = (messMeals > 0) ? totalMessCost / messMeals : 0.0;
      final myCost = myMeals * mealRate;
      final messBalance = totalDeposit - totalMessCost;
      final myDeposit = (widget.userData['totalDeposit'] ?? 0.0).toDouble();
      final myBalance = myDeposit - myCost;
      // --- End Calculations ---

      if (mounted) {
        setState(() {
          // Update mess stats
          _totalMessCost = totalMessCost;
          _mealRate = mealRate;
          _messBalance = messBalance;
          // Update personal stats
          _totalMessDeposit = totalDeposit;
          _myTotalMeals = myMeals;
          _totalMessMeals = messMeals;
          // Update state with new values
          _myCost = myCost;
          _myBalance = myBalance;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4ECDC4).withAlpha((0.1 * 255).round()),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF4ECDC4),
            ),
            onPressed: () {
              _showExitConfirmationDialog(context);
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userData['messName'] ?? 'My Mess',
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Member (${widget.userData['name'] ?? ''})',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF6B6B).withAlpha((0.1 * 255).round()),
            ),
            child: IconButton(
              icon: StreamBuilder<int>(
                stream: DatabaseService().unreadNotificationCountStream(
                  widget.userData['messId'] ?? '',
                  FirebaseAuth.instance.currentUser?.uid ?? '',
                ),
                builder: (context, snapshot) {
                  int count = snapshot.data ?? 0;
                  if (count > 0) {
                    return SimpleBadge(
                      label: count.toString(),
                      backgroundColor: Colors.red,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFFFF6B6B),
                      ),
                    );
                  }
                  return const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFFFF6B6B),
                  );
                },
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationScreen(
                      messId: widget.userData['messId'] ?? '',
                      currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Log Out',
            onPressed: () {
              _showLogoutConfirmationDialog(
                context,
                () => Navigator.of(context).pop(),
                () => _logout(context),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        // Using LayoutBuilder for responsive UI
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: _fetchMessStats,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Personal Stats Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.15 * 255).round()),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'My Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(
                                  (0.2 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.userData['createdMonth'] ?? _months[_currentDate.month - 1]} ${_currentDate.year}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildResponsiveStatsRow(constraints.maxWidth),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Actions Grid - FIXED OVERFLOW ISSUE
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResponsiveQuickActions(constraints.maxWidth),
                  const SizedBox(height: 20),

                  // Mess Statistics Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.05 * 255).round()),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(
                                  0xFFFF6B6B,
                                ).withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics_outlined,
                                color: Color(0xFFFF6B6B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Mess Statistics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildEnhancedStatItem(
                          'Mess Balance: ৳${_messBalance.toStringAsFixed(2)}',
                          Icons.account_balance_wallet,
                          (_messBalance >= 0) ? Colors.green : Colors.red,
                        ),
                        _buildEnhancedStatItem(
                          'Total Deposit: ৳${_totalMessDeposit.toStringAsFixed(2)}',
                          Icons.savings,
                          const Color(0xFF4ECDC4),
                        ),
                        _buildEnhancedStatItem(
                          'Total Meals: $_totalMessMeals',
                          Icons.restaurant_menu,
                          Colors.grey,
                        ),
                        _buildEnhancedStatItem(
                          'Meal Rate: ৳${_mealRate.toStringAsFixed(2)}',
                          Icons.monetization_on,
                          const Color(0xFFFFD166),
                        ),
                        _buildEnhancedStatItem(
                          'Total Cost: ৳${_totalMessCost.toStringAsFixed(2)}',
                          Icons.attach_money,
                          const Color(0xFFFF6B6B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.05 * 255).round()),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(
                                  0xFF45B7D1,
                                ).withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: Color(0xFF45B7D1),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsItem(
                          'Profile Settings',
                          Icons.person_outline,
                          Color(0xFFFF6B6B),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userData: widget.userData,
                                  canEdit: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Full Details Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.1 * 255).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportsScreen(
                                messId: widget.userData['messId'],
                                selectedDate: _currentDate,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'View Full Month Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveStatsRow(double screenWidth) {
    double myDeposit = (widget.userData['totalDeposit'] ?? 0.0).toDouble();
    String myDepositString = '৳${myDeposit.toStringAsFixed(2)}';

    if (screenWidth < 400) {
      // Mobile - 2 columns
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPersonalStatItem(
                _myTotalMeals.toString(),
                'Meals',
                Icons.restaurant_menu_rounded,
                const Color(0xFFFFD166),
              ),
              _buildPersonalStatItem(
                myDepositString,
                'Deposit',
                Icons.account_balance_wallet_rounded,
                const Color(0xFF4ECDC4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPersonalStatItem(
                '৳${_myCost.toStringAsFixed(2)}',
                'Cost',
                Icons.attach_money_rounded,
                const Color(0xFFFF6B6B),
              ),
              _buildPersonalStatItem(
                '৳${_myBalance.toStringAsFixed(2)}',
                'Balance',
                Icons.account_balance_rounded,
                const Color(0xFF96CEB4),
              ),
            ],
          ),
        ],
      );
    } else {
      // Desktop/Tablet - 4 columns
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPersonalStatItem(
            _myTotalMeals.toString(),
            'Meals',
            Icons.restaurant_menu_rounded,
            const Color(0xFFFFD166),
          ),
          _buildPersonalStatItem(
            myDepositString,
            'Deposit',
            Icons.account_balance_wallet_rounded,
            const Color(0xFF4ECDC4),
          ),
          _buildPersonalStatItem(
            '৳${_myCost.toStringAsFixed(2)}',
            'Cost',
            Icons.attach_money_rounded,
            const Color(0xFFFF6B6B),
          ),
          _buildPersonalStatItem(
            '৳${_myBalance.toStringAsFixed(2)}',
            'Balance',
            Icons.account_balance_rounded,
            const Color(0xFF96CEB4),
          ),
        ],
      );
    }
  }

  Widget _buildResponsiveQuickActions(double screenWidth) {
    // Use 3 columns for quick actions on all widths
    int crossAxisCount = 3;
    double childAspectRatio = screenWidth < 400 ? 0.95 : 1.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildMemberAction(
          'My Profile',
          Icons.person,
          const Color(0xFFFF6B6B),
          const Color(0xFFFFF5F5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfileScreen(userData: widget.userData, canEdit: false),
              ),
            );
          },
        ),
        _buildMemberAction(
          'Make Payment',
          Icons.payment,
          const Color(0xFF4ECDC4),
          const Color(0xFFF0FDFA),
        ),
        _buildMemberAction(
          'Meal History',
          Icons.history,
          const Color(0xFF96CEB4),
          const Color(0xFFF0FDF4),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MealHistoryScreen(
                  messId: widget.userData['messId'],
                  memberUid: widget.userData['uid'],
                ),
              ),
            );
          },
        ),
        _buildMemberAction(
          'Payment History',
          Icons.receipt,
          const Color(0xFFFFD166),
          const Color(0xFFFFFBEB),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PaymentHistoryScreen(userData: widget.userData),
              ),
            );
          },
        ),
        // 'Settings' action removed per request
        _buildMemberAction(
          'Monthly Report',
          Icons.analytics,
          const Color(0xFF4ECDC4),
          const Color(0xFFF0FDFA),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemberMonthlyReportScreen(
                  messId: widget.userData['messId'],
                  memberUid: widget.userData['uid'],
                  memberName: widget.userData['name'],
                ),
              ),
            );
          },
        ),
        _buildMemberAction(
          'Meal Request',
          Icons.touch_app_outlined,
          const Color(0xFFFF6B6B),
          const Color(0xFFFFF5F5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemberMealRequestScreen(
                  messId: widget.userData['messId'],
                  memberUid: widget.userData['uid'],
                  memberName: widget.userData['name'],
                ),
              ),
            ).then((_) => _fetchMessStats());
          },
        ),
      ],
    );
  }

  Widget _buildPersonalStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.2 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildMemberAction(
    String title,
    IconData icon,
    Color iconColor,
    Color backgroundColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatItem(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const Icon(Icons.info_outline, color: Color(0xFF9CA3AF), size: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF9CA3AF),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const FrontPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    VoidCallback onCancel,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out?'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

// 23. Member Monthly Report Screen
class MemberMonthlyReportScreen extends StatefulWidget {
  final String messId;
  final String memberUid;
  final String memberName;

  const MemberMonthlyReportScreen({
    super.key,
    required this.messId,
    required this.memberUid,
    required this.memberName,
  });

  @override
  State<MemberMonthlyReportScreen> createState() =>
      _MemberMonthlyReportScreenState();
}

class _MemberMonthlyReportScreenState extends State<MemberMonthlyReportScreen> {
  bool _isLoading = true;
  double _mealRate = 0.0;
  int _myMeals = 0;
  double _myDeposit = 0.0;
  double _myCost = 0.0;
  double _myBalance = 0.0;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    final db = DatabaseService();

    // 0. Check for Archived Report first
    final archivedDoc = await db.getArchivedReport(
      widget.messId,
      _selectedDate,
    );

    if (archivedDoc.exists) {
      final data = archivedDoc.data() as Map<String, dynamic>;
      final memberReports = List<Map<String, dynamic>>.from(
        data['memberReports'],
      );
      // Find my report
      final myReport = memberReports.firstWhere(
        (r) => r['uid'] == widget.memberUid,
        orElse: () => {},
      );

      if (mounted && myReport.isNotEmpty) {
        setState(() {
          _mealRate = (data['mealRate'] as num).toDouble();
          _myMeals = (myReport['meals'] as num).toInt();
          _myDeposit = (myReport['deposit'] as num).toDouble();
          _myCost = (myReport['cost'] as num).toDouble();
          _myBalance = (myReport['balance'] as num).toDouble();
          _isLoading = false;
        });
        return;
      }
    }

    // 1. Get Mess Totals for Rate
    final messCost = await db.getTotalMessCostForMonth(
      widget.messId,
      _selectedDate,
    );
    final messMeals = await db.getTotalMessMealsForMonth(
      widget.messId,
      _selectedDate,
    );

    // 2. Get Member Details
    final myMeals = await db.getMemberTotalMealsForMonth(
      widget.messId,
      widget.memberUid,
      _selectedDate,
    );

    // Get fresh user data for deposit
    final userDoc = await db.userCollection.doc(widget.memberUid).get();
    double myDeposit = 0.0;
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      myDeposit = (userData['totalDeposit'] ?? 0.0).toDouble();
    }

    // 3. Calculations
    double rate = 0.0;
    if (messMeals > 0) {
      rate = messCost / messMeals;
    }

    final myCost = myMeals * rate;
    final balance = myDeposit - myCost;

    if (mounted) {
      setState(() {
        _mealRate = rate;
        _myMeals = myMeals;
        _myDeposit = myDeposit;
        _myCost = myCost;
        _myBalance = balance;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthName = _months[_selectedDate.month - 1];
    String year = _selectedDate.year.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('My Report - $monthName $year'),
        backgroundColor: const Color(0xFF4ECDC4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _generateReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 20),
                    _buildDetailsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Current Balance',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            '৳${_myBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _myBalance >= 0 ? 'You are in safe zone' : 'Please deposit money',
            style: TextStyle(
              color: Colors.white.withAlpha((0.8 * 255).round()),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDetailRow(
              'Total Deposit',
              '৳${_myDeposit.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              const Color(0xFF4ECDC4),
            ),
            const Divider(height: 30),
            _buildDetailRow(
              'Total Meals',
              '$_myMeals',
              Icons.restaurant_menu,
              const Color(0xFFFFD166),
            ),
            const Divider(height: 30),
            _buildDetailRow(
              'Meal Rate',
              '৳${_mealRate.toStringAsFixed(2)}',
              Icons.analytics,
              const Color(0xFF96CEB4),
            ),
            const Divider(height: 30),
            _buildDetailRow(
              'Total Cost',
              '৳${_myCost.toStringAsFixed(2)}',
              Icons.shopping_cart,
              const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// 21. Member Meal Request Screen
class MemberMealRequestScreen extends StatefulWidget {
  final String messId;
  final String memberUid;
  final String memberName;

  const MemberMealRequestScreen({
    super.key,
    required this.messId,
    required this.memberUid,
    required this.memberName,
  });

  @override
  State<MemberMealRequestScreen> createState() =>
      _MemberMealRequestScreenState();
}

class _MemberMealRequestScreenState extends State<MemberMealRequestScreen> {
  bool _isSubmitting = false;

  // State for meals
  bool _morningOn = true;
  int _morningExtra = 0;
  bool _lunchOn = true;
  int _lunchExtra = 0;
  bool _dinnerOn = true;
  int _dinnerExtra = 0;

  late String _requestForDate;

  @override
  void initState() {
    super.initState();
    final nextDay = DateTime.now().add(const Duration(days: 1));
    _requestForDate =
        "${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isSubmitting = true;
    });

    final mealData = {
      'morning': {'on': _morningOn, 'extra': _morningExtra},
      'lunch': {'on': _lunchOn, 'extra': _lunchExtra},
      'dinner': {'on': _dinnerOn, 'extra': _dinnerExtra},
    };

    await DatabaseService().submitMealRequest(
      messId: widget.messId,
      memberUid: widget.memberUid,
      memberName: widget.memberName,
      requestForDate: _requestForDate,
      meals: mealData,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your meal request has been submitted!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Meal Request'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Date Picker Section
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8C8C)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date for Meal Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.parse(_requestForDate),
                          firstDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _requestForDate =
                                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Request for date:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _requestForDate,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Meals Selection Section
            const Text(
              'Select Meals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            _buildMealCard(
              'Morning',
              Icons.wb_sunny_outlined,
              const Color(0xFFFFD166),
              _morningOn,
              _morningExtra,
              (isOn) => setState(() => _morningOn = isOn),
              () => setState(() => _morningExtra++),
              () => setState(
                () => _morningExtra = _morningExtra > 0 ? _morningExtra - 1 : 0,
              ),
            ),
            const SizedBox(height: 16),
            _buildMealCard(
              'Lunch',
              Icons.fastfood_outlined,
              const Color(0xFF4ECDC4),
              _lunchOn,
              _lunchExtra,
              (isOn) => setState(() => _lunchOn = isOn),
              () => setState(() => _lunchExtra++),
              () => setState(
                () => _lunchExtra = _lunchExtra > 0 ? _lunchExtra - 1 : 0,
              ),
            ),
            const SizedBox(height: 16),
            _buildMealCard(
              'Dinner',
              Icons.nightlight_outlined,
              const Color(0xFF45B7D1),
              _dinnerOn,
              _dinnerExtra,
              (isOn) => setState(() => _dinnerOn = isOn),
              () => setState(() => _dinnerExtra++),
              () => setState(
                () => _dinnerExtra = _dinnerExtra > 0 ? _dinnerExtra - 1 : 0,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SUBMIT REQUEST',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(
    String title,
    IconData icon,
    Color color,
    bool isOn,
    int extraCount,
    ValueChanged<bool> onToggle,
    VoidCallback onAdd,
    VoidCallback onRemove,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isOn,
                  onChanged: onToggle,
                  activeThumbColor: color,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Extra Meals (for guests)',
                  style: TextStyle(fontSize: 16),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: onRemove,
                    ),
                    Text(
                      '$extraCount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: onAdd,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 22. Manager Meal Request Screen
class ManagerMealRequestScreen extends StatefulWidget {
  final String messId;
  final String date; // YYYY-MM-DD

  const ManagerMealRequestScreen({
    super.key,
    required this.messId,
    required this.date,
  });

  @override
  State<ManagerMealRequestScreen> createState() =>
      _ManagerMealRequestScreenState();
}

class _ManagerMealRequestScreenState extends State<ManagerMealRequestScreen> {
  late Future<List<DocumentSnapshot>> _requestsFuture;
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date;
    _refreshRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = DatabaseService().getMealRequestsForDate(
        widget.messId,
        _selectedDate,
      );
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      final formattedDate =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _selectedDate = formattedDate;
      });
      _refreshRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meal Requests'),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Text(
                _selectedDate,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6A0572),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading requests.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No meal requests for $_selectedDate yet.'),
            );
          }

          final requests = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestData =
                  requests[index].data() as Map<String, dynamic>;
              final meals = requestData['meals'] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(requestData['memberName'][0]),
                  ),
                  title: Text(
                    requestData['memberName'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMealStatusRow(
                        'Morning:',
                        meals['morning']['on'],
                        meals['morning']['extra'],
                      ),
                      _buildMealStatusRow(
                        'Lunch:',
                        meals['lunch']['on'],
                        meals['lunch']['extra'],
                      ),
                      _buildMealStatusRow(
                        'Dinner:',
                        meals['dinner']['on'],
                        meals['dinner']['extra'],
                      ),
                    ],
                  ),
                  isThreeLine: true, // Allows more space for the subtitle
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Widget _buildMealStatusRow(String mealType, bool isOn, int extra) {
  return Padding(
    padding: const EdgeInsets.only(top: 2.0),
    child: Row(
      children: [
        Text(
          mealType,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Text(
          isOn ? 'ON' : 'OFF',
          style: TextStyle(
            fontSize: 12,
            color: isOn ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (extra > 0)
          Text(
            ' (+${extra.toString()})',
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
      ],
    ),
  );
}

// 19. Payment History Screen
class PaymentHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PaymentHistoryScreen({super.key, required this.userData});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late Future<List<DocumentSnapshot>> _depositHistoryFuture;

  @override
  void initState() {
    super.initState();
    _depositHistoryFuture = DatabaseService().getMemberDepositHistory(
      widget.userData['uid'],
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final double totalDeposit = (widget.userData['totalDeposit'] ?? 0.0)
        .toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: const Color(0xFFFFD166),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD166), Color(0xFFFCA5A5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Deposit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${totalDeposit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _depositHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading history.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('You have no deposit history yet.'),
                  );
                }

                List<DocumentSnapshot> history = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    var depositData =
                        history[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4ECDC4,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Color(0xFF4ECDC4),
                          ),
                        ),
                        title: Text(
                          'Deposit: ৳${(depositData['amount'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        subtitle: Text(
                          'Added by ${depositData['addedBy']} on ${_formatDate(depositData['date'])}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 18. Meal History Screen
class MealHistoryScreen extends StatefulWidget {
  // Updated to be similar to MealManagementScreen
  final String messId;
  final String memberUid;

  const MealHistoryScreen({
    super.key,
    required this.messId,
    required this.memberUid,
  });

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  late DateTime _selectedDate;
  Map<String, int> _mealHistory = {};
  bool _isLoading = true;
  int _totalMealsForMonth = 0;

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchMealHistoryForMonth();
  }

  Future<void> _fetchMealHistoryForMonth() async {
    setState(() {
      _isLoading = true;
    });

    final history = await DatabaseService().getMemberMealHistoryForMonth(
      widget.messId,
      widget.memberUid,
      _selectedDate,
    );

    int total = 0;
    history.forEach((date, mealCount) {
      total += mealCount;
    });

    if (mounted) {
      setState(() {
        _mealHistory = history;
        _totalMealsForMonth = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null &&
        (picked.year != _selectedDate.year ||
            picked.month != _selectedDate.month)) {
      _selectedDate = DateTime(picked.year, picked.month, 1);
      _fetchMealHistoryForMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthName = _months[_selectedDate.month - 1];
    String year = _selectedDate.year.toString();

    DateTime firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    DateTime lastDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    );

    final selectedDayMealCount =
        _mealHistory["${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}"] ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Meal History for $monthName $year'),
        backgroundColor: const Color(0xFF96CEB4),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Change Month',
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: firstDayOfMonth,
                  lastDate: lastDayOfMonth,
                  onDateChanged: (newDate) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                    // No need to fetch data again, as it's already loaded for the month
                  },
                ),
                const Divider(thickness: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Meals on Selected Day:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                selectedDayMealCount.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF96CEB4),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Meals This Month:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                _totalMealsForMonth.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
    );
  }
}

// 17. Profile Screen
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool canEdit;

  const ProfileScreen({
    super.key,
    required this.userData,
    this.canEdit = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _emailController = TextEditingController(text: widget.userData['email']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    String newName = _nameController.text.trim();
    String newEmail = _emailController.text.trim();
    String newPhone = _phoneController.text.trim();

    if (newName.isEmpty || newEmail.isEmpty || newPhone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      setState(() => _isSaving = false);
      return;
    }

    bool success = await DatabaseService().updateUserProfile(
      widget.userData['uid'],
      newName,
      newEmail,
      newPhone,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        widget.userData['name'] = newName;
        widget.userData['email'] = newEmail;
        widget.userData['phone'] = newPhone;
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatJoiningDate() {
    // The joining date is not stored in the database.
    // This is a placeholder. For a real implementation,
    // the joining date should be saved when a member joins a mess.
    // For now, we can show the mess creation month as an approximation.
    if (widget.userData.containsKey('createdMonth')) {
      return 'Since ${widget.userData['createdMonth']}';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.userData['name'] ?? 'N/A';
    final String joiningDate = _formatJoiningDate();
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF4ECDC4),
        elevation: 0,
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  if (_isEditing) {
                    // Cancel editing, reset values
                    _nameController.text = widget.userData['name'];
                    _emailController.text = widget.userData['email'];
                    _phoneController.text = widget.userData['phone'];
                  }
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Color(0xFF4ECDC4),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4ECDC4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Member | $joiningDate',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildEditableField(
                    'Full Name',
                    _nameController,
                    Icons.person_outline,
                    const Color(0xFF96CEB4),
                  ),
                  const SizedBox(height: 16),
                  _buildEditableField(
                    'Email Address',
                    _emailController,
                    Icons.email_outlined,
                    const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 16),
                  _buildEditableField(
                    'Phone Number',
                    _phoneController,
                    Icons.phone_android_outlined,
                    const Color(0xFF45B7D1),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Mess Name',
                    widget.userData['messName'] ?? 'N/A',
                    Icons.home_work_outlined,
                    Colors.grey,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SAVE CHANGES',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: TextFormField(
          controller: controller,
          enabled: _isEditing && widget.canEdit,
          decoration: InputDecoration(
            icon: Icon(icon, color: color),
            labelText: label,
            border: InputBorder.none,
            labelStyle: const TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// Notification Screen
class NotificationScreen extends StatefulWidget {
  final String messId;
  final String currentUid;

  const NotificationScreen({
    super.key,
    required this.messId,
    required this.currentUid,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF4ECDC4),
        actions: [
          StreamBuilder<int>(
            stream: DatabaseService().unreadNotificationCountStream(
              widget.messId,
              widget.currentUid,
            ),
            builder: (context, snap) {
              int count = snap.data ?? 0;
              return IconButton(
                icon: Icon(
                  Icons.done_all,
                  color: count > 0 ? Colors.white : Colors.white54,
                ),
                tooltip: 'Mark all read',
                onPressed: count > 0
                    ? () async {
                        await DatabaseService().markAllNotificationsRead(
                          widget.messId,
                          widget.currentUid,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Marked $count notifications as read',
                            ),
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService().notificationsStream(widget.messId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final body = data['body'] ?? '';
              final unreadFor = List<String>.from(data['unreadFor'] ?? []);
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final isUnread = unreadFor.contains(widget.currentUid);

              return ListTile(
                tileColor: isUnread ? const Color(0xFFFFF0F0) : null,
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body),
                    if (createdAt != null)
                      Text(
                        '${createdAt.toLocal()}'.split('.').first,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: isUnread
                    ? const Icon(Icons.circle, color: Colors.red, size: 12)
                    : null,
                onTap: () async {
                  if (isUnread) {
                    await DatabaseService().markNotificationRead(
                      widget.messId,
                      doc.id,
                      widget.currentUid,
                    );
                  }
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(title),
                      content: Text(body),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
