import 'package:flutter/material.dart';

import 'services/database_service.dart';

class RiderProfilePage extends StatefulWidget {
  final String riderAccountId;

  const RiderProfilePage({
    super.key,
    required this.riderAccountId,
  });

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService.getRiderProfile(widget.riderAccountId);

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  String _name(Map<String, dynamic> profile) {
    final first = profile['firstname']?.toString() ?? '';
    final last = profile['surname']?.toString() ?? '';
    final name = '$first $last'.trim();

    return name.isEmpty ? 'Rider' : name;
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;

        return Icon(
          value <= rating.round() ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Rider profile not found'))
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundImage:
                                    (_profile!['profile_image_url']
                                                    ?.toString() ??
                                                '')
                                            .isNotEmpty
                                        ? NetworkImage(
                                            DatabaseService.getProfileImageUrl(
                                              _profile!['profile_image_url']
                                                  .toString(),
                                            ),
                                          )
                                        : null,
                                child: (_profile!['profile_image_url']
                                                    ?.toString() ??
                                                '')
                                            .isEmpty
                                    ? const Icon(Icons.delivery_dining, size: 42)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _name(_profile!),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if ((_profile!['phone_number']?.toString() ?? '')
                                  .isNotEmpty)
                                Text(
                                  _profile!['phone_number'].toString(),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _stars(
                                (_profile!['average_rating'] as num?)
                                        ?.toDouble() ??
                                    0,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${((_profile!['average_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} rating • ${_profile!['review_count']} review(s)',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              context,
                              title: 'Deliveries',
                              value:
                                  '${_profile!['successful_deliveries'] ?? 0}',
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              context,
                              title: 'Rating',
                              value:
                                  '${((_profile!['average_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}/5',
                              icon: Icons.star_border,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Rider Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if ((_profile!['reviews'] as List).isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('No rider reviews yet')),
                        )
                      else
                        ...(_profile!['reviews'] as List).map((review) {
                          final data = review as Map;
                          final account = data['account'];

                          final reviewer = account is Map
                              ? '${account['firstname'] ?? ''} ${account['surname'] ?? ''}'
                                  .trim()
                              : 'Buyer';

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                reviewer.isEmpty ? 'Buyer' : reviewer,
                              ),
                              subtitle: Text(
                                data['comment']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? data['comment'].toString()
                                    : 'No comment',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 2),
                                  Text('${data['rating'] ?? 0}'),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}