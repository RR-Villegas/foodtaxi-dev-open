import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;
  String? _accountId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      _accountId = await DatabaseService.getCurrentAccountId();
      if (_accountId == null) {
        setState(() => _error = 'No account found. Please login again.');
        return;
      }

      // Fetch profile
      final profileResponse = await _supabase
          .from('account')
          .select('firstname, surname, email, phone_number, account_type')
          .eq('account_id', _accountId!)
          .single();
      _userProfile = profileResponse;
    } catch (e) {
      setState(() => _error = 'Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color.fromARGB(255, 30, 83, 32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Profile Image
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.green,
                              child: Text(
                                _userProfile?['firstname']?[0].toUpperCase() ??
                                    'U',
                                style: const TextStyle(
                                  fontSize: 50,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green,
                                child: Icon(Icons.edit, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Full Name
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Color.fromARGB(255, 30, 83, 32)),
                          title: const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${_userProfile?['firstname'] ?? ''} ${_userProfile?['surname'] ?? ''}'),
                        ),
                      ),

                      // Email
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.email, color: Color.fromARGB(255, 30, 83, 32)),
                          title: const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_userProfile?['email'] ?? ''),
                        ),
                      ),

                      // Phone
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.phone, color: Color.fromARGB(255, 30, 83, 32)),
                          title: const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_userProfile?['phone_number'] ?? 'Not set'),
                        ),
                      ),

                    ],
                  ),
                ),
    );
  }
}
