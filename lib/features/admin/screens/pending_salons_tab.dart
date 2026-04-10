import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_service.dart';
import 'package:cutline/features/admin/widgets/admin_ui.dart';
import 'package:cutline/routes/admin_router.dart';
import 'package:cutline/shared/widgets/web_safe_image.dart';

class PendingSalonsTab extends StatelessWidget {
  const PendingSalonsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return StreamBuilder<List<AdminSalonSummary>>(
      stream: service.watchPendingSalons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              const AdminEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Pending list could not load',
                message:
                    'Admin query failed. Pull to refresh after signing in again.',
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
        final salons = snapshot.data ?? const <AdminSalonSummary>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _PendingHero(count: salons.length),
            const SizedBox(height: 24),
            const AdminSectionHeading(
              eyebrow: 'Verification Queue',
              title: 'New salon submissions',
              subtitle:
                  'Open each salon to verify business details, photos, services, and owner information.',
            ),
            const SizedBox(height: 14),
            if (salons.isEmpty)
              const AdminEmptyState(
                icon: Icons.verified_outlined,
                title: 'No pending submissions',
                message:
                    'As soon as a salon owner registers a new salon, it will appear here.',
              )
            else
              ...salons.map(
                (salon) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PendingSalonCard(salon: salon),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PendingHero extends StatelessWidget {
  const _PendingHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      backgroundColor: const Color(0xFFEAF5F1),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD6EBE4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count salon${count == 1 ? '' : 's'} waiting',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review these first so approved salons can go live without delay.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D6F68),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSalonCard extends StatelessWidget {
  const _PendingSalonCard({required this.salon});

  final AdminSalonSummary salon;

  @override
  Widget build(BuildContext context) {
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
                _SalonThumb(url: salon.coverImageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            salon.name.isEmpty ? salon.id : salon.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const AdminStatusBadge(
                            label: 'Pending',
                            icon: Icons.hourglass_top_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        salon.address.isEmpty
                            ? 'No address submitted'
                            : salon.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5D6F68),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: 'Owner',
                            value: salon.ownerId,
                          ),
                          _InfoChip(
                            label: 'Submitted',
                            value: formatAdminDateTime(salon.submittedAt),
                          ),
                          if (salon.contact.isNotEmpty)
                            _InfoChip(
                              label: 'Contact',
                              value: salon.contact,
                            ),
                        ],
                      ),
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
  }
}

class _SalonThumb extends StatelessWidget {
  const _SalonThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2EE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.storefront_outlined,
          color: Color(0xFF0F766E),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: WebSafeImage(
        imageUrl: url,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF425A53),
            ),
      ),
    );
  }
}
