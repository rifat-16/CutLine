import 'package:cutline/features/user/providers/waiting_list_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WaitingListScreen extends StatefulWidget {
  const WaitingListScreen({super.key});

  @override
  State<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends State<WaitingListScreen> {
  bool sortAscending = true;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WaitingListProvider()..load(),
      builder: (context, _) {
        final provider = context.watch<WaitingListProvider>();
        final waiting = [...provider.customers]
          ..sort((a, b) => sortAscending
              ? a.waitMinutes.compareTo(b.waitMinutes)
              : b.waitMinutes.compareTo(a.waitMinutes));

        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: CutlineAppBar(
            title: 'Waiting for Service',
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                tooltip: 'Sort by time',
                onPressed: () => setState(() => sortAscending = !sortAscending),
              ),
            ],
          ),
          body: provider.isLoading && waiting.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: waiting.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: CutlineSpacing.section,
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                provider.error ??
                                    'No customers are waiting right now.',
                                style: CutlineTextStyles.caption,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: CutlineSpacing.section
                              .copyWith(top: 16, bottom: 16),
                          itemCount: waiting.length,
                          itemBuilder: (context, index) {
                            final item = waiting[index];
                            return CutlineAnimations.staggeredList(
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: CutlineSpacing.sm),
                                padding: CutlineSpacing.card,
                                decoration: CutlineDecorations.card(
                                    solidColor: CutlineColors.background),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: item.avatar.isNotEmpty
                                          ? NetworkImage(item.avatar)
                                          : null,
                                      radius: 28,
                                      child: item.avatar.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    const SizedBox(width: CutlineSpacing.md),
                                    Expanded(
                                      child: _WaitingDetails(item: item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}

class _WaitingDetails extends StatelessWidget {
  final WaitingCustomer item;

  const _WaitingDetails({required this.item});

  Color _statusColor(WaitingStatus status) {
    switch (status) {
      case WaitingStatus.servingSoon:
        return Colors.green;
      case WaitingStatus.done:
        return Colors.red;
      case WaitingStatus.waiting:
        return CutlineColors.accent;
    }
  }

  String _statusLabel(WaitingStatus status) {
    switch (status) {
      case WaitingStatus.servingSoon:
        return 'Serving soon';
      case WaitingStatus.done:
        return 'Completed';
      case WaitingStatus.waiting:
        return 'In queue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.name,
                style:
                    CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_statusLabel(item.status),
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Barber: ${item.barber}',
            style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        Text('Service: ${item.service}',
            style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.access_time,
                size: 16, color: CutlineColors.primary),
            const SizedBox(width: 4),
            Text('${item.waitMinutes} min left',
                style: CutlineTextStyles.subtitleBold
                    .copyWith(color: CutlineColors.primary)),
          ],
        ),
      ],
    );
  }
}
