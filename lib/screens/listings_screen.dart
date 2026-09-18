import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'property_detail_screen.dart';

class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Landlord studio',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Create trusted listings, confirm availability, and guide tenants into the right workflow.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: ErrorBanner()),
            if (state.snapshot.properties.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No listings yet',
                  body:
                      'Create a verified rental listing connected to the Django property API.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.builder(
                  itemCount: state.snapshot.properties.length,
                  itemBuilder: (context, index) {
                    final property = state.snapshot.properties[index];
                    return PropertyCard(
                      property: property,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PropertyDetailScreen(property: property),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openEditor(context, property);
                          if (value == 'delete') _delete(context, property);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, [PropertyListing? property]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PropertyEditor(property: property),
    );
  }

  Future<void> _delete(BuildContext context, PropertyListing property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text(property.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<Property24State>().deleteProperty(property.id);
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.verified_outlined,
          color: Theme.of(context).colorScheme.primary),
      title: Text(label),
    );
  }
}

class PropertyEditor extends StatefulWidget {
  const PropertyEditor({this.property, super.key});

  final PropertyListing? property;

  @override
  State<PropertyEditor> createState() => _PropertyEditorState();
}

class _PropertyEditorState extends State<PropertyEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _suburb;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _beds;
  late final TextEditingController _baths;
  late final TextEditingController _description;
  late final TextEditingController _water;
  late final TextEditingController _parking;
  late final TextEditingController _images;
  late final TextEditingController _videos;
  late final TextEditingController _audio;
  String _type = 'house';
  bool _furnished = false;
  bool _solar = false;
  bool _borehole = false;
  bool _pets = false;
  bool _tour = false;

  @override
  void initState() {
    super.initState();
    final property = widget.property;
    _title = TextEditingController(text: property?.title ?? '');
    _address = TextEditingController(text: property?.address ?? '');
    _city = TextEditingController(text: property?.city ?? 'Harare');
    _suburb = TextEditingController(text: property?.suburb ?? '');
    _rent = TextEditingController(text: property?.monthlyRent ?? '');
    _deposit = TextEditingController(text: property?.depositRequired ?? '');
    _beds = TextEditingController(text: '${property?.bedrooms ?? ''}');
    _baths = TextEditingController(text: '${property?.bathrooms ?? ''}');
    _description = TextEditingController(text: property?.description ?? '');
    _water =
        TextEditingController(text: property?.waterAvailability ?? 'Available');
    _parking =
        TextEditingController(text: property?.parking ?? 'Parking available');
    _images = TextEditingController(text: property?.photos.join('\n') ?? '');
    _videos = TextEditingController(text: property?.videos.join('\n') ?? '');
    _audio = TextEditingController();
    _type =
        (property?.propertyType.toLowerCase().replaceAll(' ', '_') ?? 'house');
    _furnished = property?.furnished ?? false;
    _solar = property?.solarPower ?? false;
    _borehole = property?.borehole ?? false;
    _pets = property?.petFriendly ?? false;
    _tour = property?.has360Tour ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _city.dispose();
    _suburb.dispose();
    _rent.dispose();
    _deposit.dispose();
    _beds.dispose();
    _baths.dispose();
    _description.dispose();
    _water.dispose();
    _parking.dispose();
    _images.dispose();
    _videos.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, inset + 18),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.property == null
                  ? 'Create verified listing'
                  : 'Edit listing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'The strongest listings include identity, authority, property facts, availability, and real move-in cost.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _field(_title, 'Title'),
            _field(_address, 'Address'),
            Row(
              children: [
                Expanded(child: _field(_city, 'City')),
                const SizedBox(width: 10),
                Expanded(child: _field(_suburb, 'Suburb')),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: _field(_rent, 'Monthly rent',
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_deposit, 'Deposit',
                        keyboardType: TextInputType.number)),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: _field(_beds, 'Bedrooms',
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_baths, 'Bathrooms',
                        keyboardType: TextInputType.number)),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Property type'),
              items: const [
                DropdownMenuItem(value: 'house', child: Text('House')),
                DropdownMenuItem(value: 'flat', child: Text('Flat')),
                DropdownMenuItem(value: 'cottage', child: Text('Cottage')),
                DropdownMenuItem(
                    value: 'student_accommodation',
                    child: Text('Student accommodation')),
                DropdownMenuItem(
                    value: 'commercial_property',
                    child: Text('Commercial property')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'house'),
            ),
            const SizedBox(height: 8),
            _field(_description, 'Description', maxLines: 4),
            _field(
              _images,
              'Image URLs, one per line',
              maxLines: 3,
              requiredField: false,
            ),
            _field(
              _videos,
              'Video URLs, one per line',
              maxLines: 3,
              requiredField: false,
            ),
            _field(
              _audio,
              'Audio walkthrough URLs, one per line',
              maxLines: 2,
              requiredField: false,
            ),
            Row(
              children: [
                Expanded(child: _field(_water, 'Water availability')),
                const SizedBox(width: 10),
                Expanded(child: _field(_parking, 'Parking')),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Furnished'),
              value: _furnished,
              onChanged: (value) => setState(() => _furnished = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solar power'),
              value: _solar,
              onChanged: (value) => setState(() => _solar = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Borehole'),
              value: _borehole,
              onChanged: (value) => setState(() => _borehole = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pet friendly'),
              value: _pets,
              onChanged: (value) => setState(() => _pets = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('360 tour / video walkthrough ready'),
              value: _tour,
              onChanged: (value) => setState(() => _tour = value),
            ),
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.45),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    _ChecklistTile(label: 'Identity document uploaded'),
                    _ChecklistTile(label: 'Phone number verified'),
                    _ChecklistTile(
                        label: 'Ownership or agent authority document ready'),
                    _ChecklistTile(
                        label: 'Property address and availability confirmed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: Text(
                  widget.property == null ? 'Create listing' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) =>
            requiredField && (value == null || value.trim().isEmpty)
                ? 'Required'
                : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = PropertyDraft(
      title: _title.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      suburb: _suburb.text.trim(),
      monthlyRent: _rent.text.trim(),
      depositRequired: _deposit.text.trim(),
      propertyType: _type,
      bedrooms: int.tryParse(_beds.text) ?? 0,
      bathrooms: num.tryParse(_baths.text) ?? 1,
      description: _description.text.trim(),
      waterAvailability: _water.text.trim(),
      parking: _parking.text.trim(),
      furnished: _furnished,
      solarPower: _solar,
      borehole: _borehole,
      petFriendly: _pets,
      has360Tour: _tour,
    );

    try {
      await context.read<Property24State>().saveProperty(
            draft,
            propertyId: widget.property?.id,
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }
}
