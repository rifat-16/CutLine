import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_service.dart';
import 'package:cutline/features/admin/widgets/admin_ui.dart';
import 'package:cutline/routes/admin_router.dart';

class DirectoryTab extends StatefulWidget {
  const DirectoryTab({super.key});

  @override
  State<DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<DirectoryTab> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  String _verificationFilter = 'all';
  String _restrictionFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionHeading(
                  eyebrow: 'Salon Directory',
                  title: 'Search and monitor salons',
                  subtitle:
                      'Open a salon to view its finance summary, outstanding due, and restriction controls.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search salon by name or id',
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 460;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: wide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: DropdownButtonFormField<String>(
                            initialValue: _verificationFilter,
                            decoration: const InputDecoration(
                                labelText: 'Verification'),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'verified',
                                child: Text('Verified'),
                              ),
                              DropdownMenuItem(
                                value: 'rejected',
                                child: Text('Rejected'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _verificationFilter = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: wide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: DropdownButtonFormField<String>(
                            initialValue: _restrictionFilter,
                            decoration:
                                const InputDecoration(labelText: 'Restriction'),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All salons'),
                              ),
                              DropdownMenuItem(
                                value: 'restricted',
                                child: Text('Restricted'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Not restricted'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _restrictionFilter = value;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminDirectorySalon>>(
            stream: _service.watchSalons(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    const AdminEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Salon list could not load',
                      message:
                          'Check your connection and try opening the page again.',
                    ),
                    const SizedBox(height: 12),
                    AdminPanel(
                      child: Text(
                        '${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF9A3412),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                );
              }
              final salons = (snapshot.data ?? const <AdminDirectorySalon>[])
                  .where((salon) {
                    final verificationMatches = _verificationFilter == 'all' ||
                        salon.verificationStatus == _verificationFilter;
                    final restrictionMatches = switch (_restrictionFilter) {
                      'restricted' => salon.isRestricted,
                      'active' => !salon.isRestricted,
                      _ => true,
                    };
                    return verificationMatches && restrictionMatches;
                  })
                  .where(
                    (item) =>
                        query.isEmpty ||
                        item.name.toLowerCase().contains(query) ||
                        item.id.toLowerCase().contains(query),
                  )
                  .toList();
              if (salons.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: const [
                    AdminEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No salons found',
                      message:
                          'Try another filter or search term to find a salon.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                itemCount: salons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final salon = salons[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AdminRoutes.salonReview,
                          arguments: salon.id,
                        );
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDDE6E0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120B1F19),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: salon.isRestricted
                                      ? const Color(0xFFFFEDD5)
                                      : const Color(0xFFE6F2EE),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  salon.isRestricted
                                      ? Icons.lock_outline_rounded
                                      : Icons.storefront_outlined,
                                  color: salon.isRestricted
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      salon.name.isEmpty
                                          ? salon.id
                                          : salon.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      salon.address.isEmpty
                                          ? 'No address submitted'
                                          : salon.address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF5D6F68),
                                            height: 1.35,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        AdminStatusBadge(
                                          label: adminTitleCase(
                                            salon.verificationStatus,
                                          ),
                                          icon: Icons.verified_user_outlined,
                                          backgroundColor: _statusColor(
                                            salon.verificationStatus,
                                          ).background,
                                          foregroundColor: _statusColor(
                                            salon.verificationStatus,
                                          ).foreground,
                                        ),
                                        AdminStatusBadge(
                                          label: salon.isOpen ? 'Open' : 'Off',
                                          icon: salon.isOpen
                                              ? Icons.toggle_on_rounded
                                              : Icons.toggle_off_rounded,
                                          backgroundColor: salon.isOpen
                                              ? const Color(0xFFE8F7ED)
                                              : const Color(0xFFF1F5F9),
                                          foregroundColor: salon.isOpen
                                              ? const Color(0xFF166534)
                                              : const Color(0xFF475569),
                                        ),
                                        if (salon.isRestricted)
                                          const AdminStatusBadge(
                                            label: 'Restricted',
                                            icon: Icons.lock_outline_rounded,
                                            backgroundColor: Color(0xFFFFEDD5),
                                            foregroundColor: Color(0xFF9A3412),
                                          ),
                                        AdminStatusBadge(
                                          label: formatAdminDateTime(
                                            salon.updatedAt ?? salon.createdAt,
                                          ),
                                          icon: Icons.schedule_rounded,
                                          backgroundColor:
                                              const Color(0xFFF1F6F3),
                                          foregroundColor:
                                              const Color(0xFF425A53),
                                        ),
                                      ],
                                    ),
                                    if (salon.restrictionReason.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        salon.restrictionReason,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF9A3412),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF6B7D76),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

({Color background, Color foreground}) _statusColor(String status) {
  switch (status) {
    case 'pending':
      return (
        background: const Color(0xFFE6F2EE),
        foreground: const Color(0xFF0C5C51),
      );
    case 'rejected':
      return (
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
      );
    default:
      return (
        background: const Color(0xFFE8F7ED),
        foreground: const Color(0xFF166534),
      );
  }
}
