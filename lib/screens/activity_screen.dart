import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';
import '../widgets/metric_tile.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final isLandlord = state.user?.role == AccountRole.landlord;
    final firstName = (state.user?.name.trim().split(' ').first ?? '').trim();
    final properties = state.snapshot.properties;
    final theme = Theme.of(context);

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isLandlord ? 'Dashboard' : 'Activity',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 4),
                      Text(
                          isLandlord
                              ? 'Good morning${firstName.isEmpty ? '' : ', $firstName'}'
                              : 'Your rental activity',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                          isLandlord
                              ? 'A live view of your portfolio and enquiries.'
                              : 'Stay up to date with your applications and home care.',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                _LandlordNotificationButton(state: state),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                MetricTile(
                    icon: CupertinoIcons.house,
                    label: 'Total listings',
                    value: '${properties.length}'),
                MetricTile(
                    icon: CupertinoIcons.checkmark_seal,
                    label: 'Verified',
                    value: '${state.verifiedProperties}'),
                MetricTile(
                    icon: CupertinoIcons.person_2,
                    label: 'Applications',
                    value: '${state.snapshot.applications.length}'),
                MetricTile(
                    icon: CupertinoIcons.wrench,
                    label: 'Open maintenance',
                    value: '${state.openMaintenance}'),
              ],
            ),
            const SizedBox(height: 18),
            const ErrorBanner(),
            if (isLandlord && state.user?.accountOnboardingComplete != true)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(CupertinoIcons.lock_open,
                      color: theme.colorScheme.primary),
                  title: const Text('Finish account verification'),
                  subtitle: const Text(
                      'Verify your phone and identity before publishing a listing.'),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: () => GoRouter.of(context).go(AppRoutes.profileScreen),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isLandlord ? 'Portfolio' : 'Recent activity',
                    style: theme.textTheme.titleLarge),
                if (isLandlord)
                  TextButton.icon(
                      onPressed: () =>
                          GoRouter.of(context).go(AppRoutes.listingsScreen),
                      icon: const Icon(CupertinoIcons.arrow_right, size: 16),
                      label: const Text('View all')),
              ],
            ),
            if (properties.isEmpty)
              const Card(
                  child: ListTile(
                      leading: Icon(CupertinoIcons.house),
                      title: Text('No listings yet'),
                      subtitle: Text(
                          'Add your first sale or rental property to start receiving enquiries.')))
            else
              for (final property in properties.take(3))
                _PortfolioRow(property: property),
            if (isLandlord)
              _Section(
                title: 'Client reservations',
                empty: 'No pending or reserved reservations.',
                children: [
                  for (final booking in state.snapshot.viewings
                      .where((item) => item.isAvailableBooking)
                      .take(5))
                    _BookingRow(booking: booking),
                ],
              ),
            _Section(
                title: 'Applications',
                empty: 'No applications yet.',
                children: [
                  for (final item in state.snapshot.applications.take(5))
                    ListTile(
                        leading: const Icon(CupertinoIcons.doc_text),
                        title: Text(item.property),
                        subtitle: Text(
                            '${item.applicant} / score ${item.score} / ${item.createdAt}'),
                        trailing: Text(item.status)),
                ]),
            _Section(
                title: 'Maintenance',
                empty: 'No maintenance requests.',
                children: [
                  for (final item in state.snapshot.maintenance.take(5))
                    ListTile(
                        leading: const Icon(CupertinoIcons.wrench),
                        title: Text(item.issue),
                        subtitle: Text(
                            '${item.property} / ${item.category} / ${item.updatedAt}'),
                        trailing: Text(item.priority)),
                ]),
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});

  final ViewingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(CupertinoIcons.person, color: theme.colorScheme.primary),
      ),
      title:
          Text(booking.tenant.isEmpty ? 'Client reservation' : booking.tenant),
      subtitle: Text('${booking.property} / ${booking.scheduledFor}'),
      trailing: Text(
        booking.status,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LandlordNotificationButton extends StatelessWidget {
  const _LandlordNotificationButton({required this.state});

  final Property24State state;

  List<String> get _notifications => [
        for (final item in state.snapshot.conversations)
          '${item.title}: ${item.preview}',
        for (final item in state.snapshot.applications)
          '${item.property}: application ${item.status.toLowerCase()}',
        for (final item in state.snapshot.viewings)
          '${item.property}: booking ${item.status.toLowerCase()}',
        for (final item in state.snapshot.verifications)
          'Verification ${item.status.toLowerCase()}: ${item.role}',
        ...state.notifications,
      ].where((item) => item.trim().isNotEmpty).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final items = _notifications;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: IconButton(
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        onPressed: () => _openLandlordNotifications(context, items),
        icon: Badge(
          isLabelVisible: items.isNotEmpty,
          backgroundColor: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
          label: Text('${items.length}', style: const TextStyle(fontSize: 10)),
          child: Icon(CupertinoIcons.bell,
              color: Theme.of(context).colorScheme.onSurface, size: 24),
        ),
      ),
    );
  }
}

void _openLandlordNotifications(
    BuildContext context, List<String> notifications) {
  final width = MediaQuery.sizeOf(context).width;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withAlpha(71),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        left: false,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          child: SizedBox(
            width: width < 560 ? width * 0.92 : 440,
            height: double.infinity,
            child: _LandlordNotificationPanel(notifications: notifications),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic);
      return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(curved),
          child: child);
    },
  );
}

class _LandlordNotificationPanel extends StatelessWidget {
  const _LandlordNotificationPanel({required this.notifications});

  final List<String> notifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Notifications',
                        style: theme.textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Close notifications',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Text('No new notifications',
                          style: theme.textTheme.bodyMedium))
                  : ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: theme.colorScheme.outlineVariant),
                      itemBuilder: (_, index) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(CupertinoIcons.bell,
                            color: theme.colorScheme.primary),
                        title: Text(notifications[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioRow extends StatelessWidget {
  const _PortfolioRow({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: SizedBox(
          width: 58,
          height: 58,
          child: property.photos.isEmpty
              ? DecoratedBox(
                  decoration:
                      BoxDecoration(color: theme.colorScheme.primaryContainer),
                  child: Icon(CupertinoIcons.house,
                      color: theme.colorScheme.primary))
              : Image.network(property.photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer),
                      child: Icon(CupertinoIcons.house,
                          color: theme.colorScheme.primary))),
        ),
        title:
            Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${property.listingIntent == 'sale' ? 'For sale' : 'For rent'} / ${property.availabilityStatus} / ${property.listingViews} views',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Text(property.rentLabel,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.empty, required this.children});

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            if (children.isEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(empty,
                      style: Theme.of(context).textTheme.bodyMedium))
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
