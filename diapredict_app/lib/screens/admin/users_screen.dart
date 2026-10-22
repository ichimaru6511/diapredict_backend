import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../widgets/user_card.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _roleFilter = 'all'; // 'all', 'doctor' or 'nurse'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // true if the user matches the role filter and the search text
  bool _matches(Map<String, dynamic> data) {
    if (data['role'] == 'admin') return false;
    if (_roleFilter != 'all' && data['role'] != _roleFilter) return false;

    if (_search.isEmpty) return true;
    final name = (data['name'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final regNo = (data['registrationNo'] ?? '').toString().toLowerCase();
    return name.contains(_search) ||
        email.contains(_search) ||
        regNo.contains(_search);
  }

  Widget _roleChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _roleFilter == value,
      onSelected: (_) => setState(() => _roleFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          // search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, email or registration no.',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
              onChanged: (value) {
                setState(() => _search = value.trim().toLowerCase());
              },
            ),
          ),

          // role filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _roleChip('all', 'All'),
                const SizedBox(width: 8),
                _roleChip('doctor', 'Doctors'),
                const SizedBox(width: 8),
                _roleChip('nurse', 'Nurses'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // list of users
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load users.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where((doc) => _matches(doc.data()))
                    .toList();

                // sort by name
                docs.sort((a, b) => (a.data()['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo(
                        (b.data()['name'] ?? '').toString().toLowerCase()));

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    return UserCard(
                      data: docs[i].data(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserDetailScreen(uid: docs[i].id),
                          ),
                        );
                      },
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
