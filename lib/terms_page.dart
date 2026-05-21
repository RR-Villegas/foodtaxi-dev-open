import 'package:flutter/material.dart';

import 'services/database_service.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _isLoading = true;
  bool _isComparing = false;

  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _comparison = [];

  int? _selectedVersion;
  int? _compareFromVersion;
  int? _compareToVersion;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms([int? version]) async {
    setState(() {
      _isLoading = true;
      _comparison = [];
      _isComparing = false;
    });

    final versions = await DatabaseService.getTermsVersions();

    final latestVersion = versions.isEmpty
        ? null
        : _asInt(versions.first['version_number']);

    final targetVersion = version ?? latestVersion;
    final sections = await DatabaseService.getTermsVersion(targetVersion);

    if (!mounted) return;

    setState(() {
      _versions = versions;
      _sections = sections;
      _selectedVersion = targetVersion;
      _isLoading = false;

      if (_compareFromVersion == null || _compareToVersion == null) {
        _setDefaultCompareVersions();
      }
    });
  }

  Future<void> _resetToLatest() async {
    await _loadTerms();
  }

  Future<void> _compareVersions() async {
    final from = _compareFromVersion;
    final to = _compareToVersion;

    if (from == null || to == null) {
      _showSnack('Pick two versions first.');
      return;
    }

    if ((from - to).abs() != 1) {
      _showSnack(
        'Only nearby versions can be compared. Example: t1 to t2, t2 to t3.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isComparing = true;
    });

    final comparison = await DatabaseService.compareAdjacentTermsVersions(
      fromVersion: from,
      toVersion: to,
    );

    if (!mounted) return;

    setState(() {
      _comparison = comparison;
      _isLoading = false;
      _isComparing = true;
    });
  }

  void _setDefaultCompareVersions() {
    final numbers = _versionNumbersNewestFirst();

    if (numbers.length >= 2) {
      _compareFromVersion = numbers[1];
      _compareToVersion = numbers[0];
    } else if (numbers.length == 1) {
      _compareFromVersion = numbers[0];
      _compareToVersion = null;
    }
  }

  List<int> _versionNumbersNewestFirst() {
    final numbers = _versions
        .map((version) => _asInt(version['version_number']))
        .whereType<int>()
        .toList();

    numbers.sort((a, b) => b.compareTo(a));
    return numbers;
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Unknown date';

    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${_monthName(local.month)} ${local.day}, ${local.year} • $hour:$minute';
  }

  String _monthName(int month) {
    const names = [
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

    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  IconData _iconFromName(String? name) {
    switch (name) {
      case 'storefront':
        return Icons.storefront_outlined;
      case 'account_circle':
        return Icons.account_circle_outlined;
      case 'people':
        return Icons.people_alt_outlined;
      case 'receipt':
        return Icons.receipt_long_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'local_offer':
        return Icons.local_offer_outlined;
      case 'flag':
        return Icons.flag_outlined;
      case 'star':
        return Icons.star_outline;
      case 'delivery':
        return Icons.delivery_dining_outlined;
      case 'block':
        return Icons.block_outlined;
      case 'gavel':
        return Icons.gavel_outlined;
      case 'verified_user':
        return Icons.verified_user_outlined;
      case 'build':
        return Icons.build_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'privacy':
        return Icons.privacy_tip_outlined;
      case 'logout':
        return Icons.logout_outlined;
      case 'update':
        return Icons.update_outlined;
      case 'support':
        return Icons.support_agent_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Map<String, dynamic>? _versionByNumber(int? number) {
    if (number == null) return null;

    for (final version in _versions) {
      if (_asInt(version['version_number']) == number) {
        return version;
      }
    }

    return null;
  }

  Widget _versionHistoryTile() {
    final selectedVersion = _versionByNumber(_selectedVersion);

    return Card(
      elevation: 0,
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: const Text(
          'Version History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _selectedVersion == null
              ? 'View older Terms versions'
              : 'Currently viewing t$_selectedVersion',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Users can view older Terms versions. Admin edits create a new saved version instead of overwriting the old one.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _selectedVersion,
            decoration: const InputDecoration(
              labelText: 'View Terms Version',
              border: OutlineInputBorder(),
            ),
            items: _versions.map((version) {
              final number = _asInt(version['version_number']) ?? 0;

              return DropdownMenuItem<int>(
                value: number,
                child: Text(
                  't$number • ${_formatDateTime(version['published_at'])}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              _loadTerms(value);
            },
          ),
          if (selectedVersion != null) ...[
            const SizedBox(height: 10),
            Text(
              selectedVersion['summary']?.toString().trim().isNotEmpty == true
                  ? selectedVersion['summary'].toString()
                  : 'No update summary.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetToLatest,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Back to Current Version'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareTile() {
    final numbers = _versionNumbersNewestFirst();

    return Card(
      elevation: 0,
      child: ExpansionTile(
        leading: const Icon(Icons.compare_arrows),
        title: const Text(
          'Compare Changes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _isComparing && _compareFromVersion != null && _compareToVersion != null
              ? 'Comparing t$_compareFromVersion → t$_compareToVersion'
              : 'Compare nearby versions only',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Only nearby versions are allowed. Example: t1 → t2 or t3 → t4. Not t1 → t3.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _compareFromVersion,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    border: OutlineInputBorder(),
                  ),
                  items: numbers
                      .map(
                        (number) => DropdownMenuItem<int>(
                          value: number,
                          child: Text('t$number'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _compareFromVersion = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _compareToVersion,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    border: OutlineInputBorder(),
                  ),
                  items: numbers
                      .map(
                        (number) => DropdownMenuItem<int>(
                          value: number,
                          child: Text('t$number'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _compareToVersion = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _compareVersions,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Compare'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetToLatest,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _termsList() {
    if (_sections.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No Terms and Conditions found.')),
        ),
      );
    }

    return Column(
      children: _sections.map((section) {
        final item = _TermsSection(
          icon: _iconFromName(section['icon_name']?.toString()),
          title: section['section_title']?.toString() ?? '',
          body: section['section_body']?.toString() ?? '',
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SectionCard(section: item),
        );
      }).toList(),
    );
  }

  Widget _comparisonList() {
    if (_comparison.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No comparison result.')),
        ),
      );
    }

    return Column(
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: const Icon(Icons.compare_arrows),
            title: Text(
              'Comparing t$_compareFromVersion → t$_compareToVersion',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Press reset to return to the latest Terms.'),
            trailing: TextButton.icon(
              onPressed: _resetToLatest,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._comparison.map((row) {
          final changeType = row['change_type']?.toString() ?? 'unchanged';
          final color = switch (changeType) {
            'added' => Colors.green,
            'removed' => Colors.red,
            'changed' => Colors.orange,
            _ => Colors.grey,
          };

          final fromTitle = row['from_title']?.toString();
          final toTitle = row['to_title']?.toString();
          final fromBody = row['from_body']?.toString();
          final toBody = row['to_body']?.toString();

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: color.withAlpha(30),
                child: Icon(Icons.change_circle_outlined, color: color),
              ),
              title: Text(
                toTitle ?? fromTitle ?? 'Section ${row['section_order']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(changeType.toUpperCase()),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (fromTitle != null || fromBody != null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Old',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${fromTitle ?? ''}\n\n${fromBody ?? ''}'),
                  ),
                  const Divider(height: 28),
                ],
                if (toTitle != null || toBody != null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${toTitle ?? ''}\n\n${toBody ?? ''}'),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final selectedVersion = _versionByNumber(_selectedVersion);
    final lastUpdated = selectedVersion == null
        ? 'Unknown date'
        : _formatDateTime(selectedVersion['published_at']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
      ),
      body: Container(
        color: scheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 980 : double.infinity,
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadTerms(_selectedVersion),
                    child: ListView(
                      padding: EdgeInsets.all(isWide ? 24 : 14),
                      children: [
                        _HeroCard(
                          lastUpdated: lastUpdated,
                          versionLabel: _selectedVersion == null
                              ? 'Unknown'
                              : 't$_selectedVersion',
                        ),
                        const SizedBox(height: 14),
                        const _QuickSummaryCard(),
                        const SizedBox(height: 14),
                        _RoleCards(isWide: isWide),
                        const SizedBox(height: 14),
                        _versionHistoryTile(),
                        const SizedBox(height: 12),
                        _compareTile(),
                        const SizedBox(height: 14),
                        if (_isComparing) _comparisonList() else _termsList(),
                        const SizedBox(height: 8),
                        _FooterCard(
                          lastUpdated: lastUpdated,
                          versionLabel: _selectedVersion == null
                              ? 'Unknown'
                              : 't$_selectedVersion',
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String lastUpdated;
  final String versionLabel;

  const _HeroCard({
    required this.lastUpdated,
    required this.versionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.description_outlined,
                color: scheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Taxi Terms',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rules for buyers, sellers, riders, and admin actions.',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withAlpha(210),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.history,
                        label: versionLabel,
                      ),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: 'Updated $lastUpdated',
                      ),
                      const _InfoChip(
                        icon: Icons.verified_user_outlined,
                        label: 'Marketplace Safety',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryCard extends StatelessWidget {
  const _QuickSummaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before you continue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            const _SummaryRow(
              icon: Icons.check_circle_outline,
              text: 'Use accurate account, address, product, and delivery information.',
            ),
            const _SummaryRow(
              icon: Icons.check_circle_outline,
              text: 'Do not use fake discounts, misleading prices, spam listings, or fake documents.',
            ),
            const _SummaryRow(
              icon: Icons.check_circle_outline,
              text: 'Admin may review reports, issue warnings, hide products, suspend stores, or ban accounts.',
            ),
            const SizedBox(height: 8),
            Text(
              'Earlier versions remain available for transparency.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCards extends StatelessWidget {
  final bool isWide;

  const _RoleCards({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _RoleCard(
        icon: Icons.shopping_bag_outlined,
        title: 'Buyers',
        text: 'Order honestly, review fairly, and report real issues.',
      ),
      const _RoleCard(
        icon: Icons.storefront_outlined,
        title: 'Sellers',
        text: 'Use accurate listings, prices, stock, variants, and discounts.',
      ),
      const _RoleCard(
        icon: Icons.delivery_dining_outlined,
        title: 'Riders',
        text: 'Handle deliveries safely, honestly, and on time.',
      ),
    ];

    if (!isWide) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary.withAlpha(24),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _TermsSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: section.title.startsWith('1.'),
          leading: CircleAvatar(
            backgroundColor: scheme.secondaryContainer,
            child: Icon(
              section.icon,
              color: scheme.onSecondaryContainer,
              size: 22,
            ),
          ),
          title: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                section.body,
                style: TextStyle(
                  height: 1.48,
                  color: scheme.onSurface.withAlpha(225),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterCard extends StatelessWidget {
  final String lastUpdated;
  final String versionLabel;

  const _FooterCard({
    required this.lastUpdated,
    required this.versionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'By continuing to use Food Taxi, you agree to these Terms and Conditions. Current viewed version: $versionLabel. Last updated $lastUpdated.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(icon, size: 16, color: scheme.primary),
      label: Text(label),
      backgroundColor: scheme.surface.withAlpha(210),
      side: BorderSide(color: scheme.primary.withAlpha(35)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TermsSection {
  final IconData icon;
  final String title;
  final String body;

  const _TermsSection({
    required this.icon,
    required this.title,
    required this.body,
  });
}