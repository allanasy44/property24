import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';

class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({required this.property, super.key});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filledTonal(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filledTonal(
              tooltip: 'Share listing',
              onPressed: () => _snack(
                  context, 'Share handoff ready for backend deep links.'),
              icon: const Icon(Icons.ios_share_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.signedIn
                      ? () => _run(
                          context,
                          () => state.requestViewing(property),
                          'Viewing requested.')
                      : () => _snack(context,
                          'Sign in from Profile to request a viewing.'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Request viewing'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Message supplier',
                onPressed: state.signedIn
                    ? () => _run(
                        context,
                        () => state.startConversation(property),
                        'Conversation opened.')
                    : () => _snack(context,
                        'Sign in from Profile to message this supplier.'),
                icon: const Icon(Icons.forum_outlined),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroMedia(property: property),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(property.title,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 6),
                          Text(
                            property.heroLocation,
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            avatar: const Icon(Icons.fingerprint, size: 16),
                            label: Text(property.passportId),
                          ),
                        ],
                      ),
                    ),
                    _TrustScore(score: property.trustScore),
                  ],
                ),
                const SizedBox(height: 16),
                _PriceCard(property: property),
                const SizedBox(height: 16),
                _SectionTitle('Property passport'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.62,
                  children: [
                    for (final fact in property.passportFacts)
                      _FactTile(
                          icon: _factIcon(fact.iconName),
                          label: fact.label,
                          value: fact.value),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionTitle('Verification'),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      for (final level in property.verificationLevels)
                        ListTile(
                          leading: Icon(
                            level.complete
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: level.complete
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          title: Text(level.label),
                          subtitle: Text(level.detail),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionTitle('Description'),
                const SizedBox(height: 8),
                Text(
                  property.description.isEmpty
                      ? 'No description supplied yet. Ask the supplier for a full property passport update.'
                      : property.description,
                ),
                const SizedBox(height: 18),
                _SectionTitle('Lifestyle fit'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LifestyleChip(
                      icon: Icons.wb_sunny_outlined,
                      label: property.solarPower
                          ? 'Backup power'
                          : 'Confirm power plan',
                    ),
                    _LifestyleChip(
                      icon: Icons.water_drop_outlined,
                      label: property.borehole
                          ? 'Reliable water'
                          : property.waterAvailability,
                    ),
                    _LifestyleChip(
                      icon: Icons.chair_outlined,
                      label: property.furnished
                          ? 'Move-in ready'
                          : 'Bring furniture',
                    ),
                    _LifestyleChip(
                      icon: Icons.pets_outlined,
                      label: property.petFriendly
                          ? 'Pets welcome'
                          : 'Pets by approval',
                    ),
                    if (property.has360Tour)
                      const _LifestyleChip(
                          icon: Icons.threesixty_outlined,
                          label: 'Virtual tour ready'),
                  ],
                ),
                const SizedBox(height: 18),
                _MapCard(property: property),
                const SizedBox(height: 18),
                _SupplierCard(property: property, state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _factIcon(String name) {
    return switch (name) {
      'bed' => Icons.bed_outlined,
      'bath' => Icons.bathtub_outlined,
      'type' => Icons.home_work_outlined,
      'water' => Icons.water_drop_outlined,
      'power' => Icons.bolt_outlined,
      'parking' => Icons.local_parking_outlined,
      _ => Icons.info_outline,
    };
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) _snack(context, success);
    } catch (exception) {
      if (context.mounted) _snack(context, '$exception');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeroMedia extends StatelessWidget {
  const _HeroMedia({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: property.photos.isEmpty
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xffd8ead9), Color(0xff8cc79f)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child:
                      Icon(Icons.apartment, size: 72, color: Color(0xff12324a)),
                )
              : PageView(
                  children: [
                    for (final photo in property.photos)
                      Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                  ],
                ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              _HeroBadge(
                  icon: Icons.event_available_outlined,
                  label: property.availabilityLabel),
              const SizedBox(width: 8),
              if (property.has360Tour)
                const _HeroBadge(
                    icon: Icons.threesixty_outlined, label: '360 tour'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(property.rentLabel,
                        style: Theme.of(context).textTheme.titleLarge)),
                const Icon(Icons.receipt_long_outlined),
              ],
            ),
            const Divider(height: 24),
            _CostLine(label: 'Deposit', value: property.depositLabel),
            _CostLine(
                label: 'Estimated fees', value: money(property.estimatedFees)),
            _CostLine(
                label: 'Move-in estimate',
                value: property.moveInTotalLabel,
                strong: true),
          ],
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.property, required this.state});

  final PropertyListing property;
  final Property24State state;

  @override
  Widget build(BuildContext context) {
    final supplier = property.supplier;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Listing contact',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                      (supplier?.name ?? 'P').characters.first.toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier?.name ?? 'Property24 supplier'),
                      Text(supplier?.role.label ?? 'Landlord / agent'),
                    ],
                  ),
                ),
                if (supplier?.verified == true) const Icon(Icons.verified),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.signedIn
                        ? () => _startCall(context, CallMode.voice)
                        : () => _snack(context, 'Sign in to start a call.'),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.signedIn
                        ? () => _startCall(context, CallMode.video)
                        : () =>
                            _snack(context, 'Sign in to start a video call.'),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startCall(BuildContext context, CallMode mode) {
    state.recordCall(property: property, mode: mode);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(mode == CallMode.video
            ? Icons.videocam_outlined
            : Icons.call_outlined),
        title: Text(
            mode == CallMode.video ? 'Video call started' : 'Call started'),
        content: Text(
            'Connecting to ${property.supplier?.name ?? 'the listing contact'} for ${property.title}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('End call')),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 170,
            width: double.infinity,
            color: const Color(0xffe8f2ea),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: _RoutePainter(
                          Theme.of(context).colorScheme.outlineVariant)),
                ),
                const Positioned(
                  left: 42,
                  top: 48,
                  child: Icon(Icons.my_location, color: Color(0xff12324a)),
                ),
                const Positioned(
                  right: 58,
                  bottom: 54,
                  child: Icon(Icons.location_on,
                      color: Color(0xff19b66a), size: 36),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.directions_outlined),
            title: const Text('Directions'),
            subtitle: Text(property.address.isEmpty
                ? property.heroLocation
                : property.address),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Directions handoff ready for Google Maps or Mapbox.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = color
      ..strokeWidth = 2;
    final route = Paint()
      ..color = const Color(0xff19b66a)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * .28),
        Offset(size.width, size.height * .55), road);
    canvas.drawLine(Offset(size.width * .2, 0),
        Offset(size.width * .64, size.height), road);
    final path = Path()
      ..moveTo(54, 60)
      ..quadraticBezierTo(
          size.width * .46, 40, size.width - 76, size.height - 64);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrustScore extends StatelessWidget {
  const _TrustScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff19b66a),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text('$score',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white)),
          Text('trust',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _LifestyleChip extends StatelessWidget {
  const _LifestyleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine(
      {required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}
