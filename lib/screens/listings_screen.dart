import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unicons/unicons.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'ai_search_screen.dart';
import 'property_detail_screen.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String _query = '';

  static const _primary = AppTheme.accent;
  static const _primarySoft = Color(0xfff1f1ff);
  static const _searchFill = AppTheme.bgSurface;
  static const _textDark = AppTheme.textPrimary;
  static const _textMuted = AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final listings = state.snapshot.properties.where((property) {
      final haystack = [
        property.title,
        property.description,
        property.address,
        property.city,
        property.suburb,
        property.propertyType,
        property.rentLabel,
        property.parking,
        property.waterAvailability,
      ].join(' ').toLowerCase();
      return _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
    }).toList();

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primarySoft,
                          ),
                          child: const Icon(UniconsLine.estate,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, landlord',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Landlord Studio',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _openEditor(context),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: _searchFill,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: _textMuted, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search your listings',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Manage listings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create trusted listings, confirm availability, and guide tenants into the right workflow.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textMuted,
                        height: 1.4,
                      ),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
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
                        icon: const Icon(Icons.more_horiz, color: _textMuted),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PropertyEditor(property: property),
    );
  }

  Future<void> _delete(BuildContext context, PropertyListing property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
      leading: const Icon(Icons.verified_outlined, color: AppTheme.accent),
      title: Text(label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          )),
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
  static const _primary = AppTheme.accent;
  static const _primarySoft = Color(0xfff1f1ff);
  static const _searchFill = AppTheme.bgSurface;
  static const _textDark = AppTheme.textPrimary;
  static const _textMuted = AppTheme.textMuted;

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
      padding: EdgeInsets.fromLTRB(20, 8, 20, inset + 20),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Create verified listing',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The strongest listings include identity, authority, property facts, availability, and real move-in cost.',
              style: TextStyle(
                fontSize: 13,
                color: _textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                value: _type,
                decoration: _inputDeco('Property type'),
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
            ),
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
            _switch(
                'Furnished', _furnished, (v) => setState(() => _furnished = v)),
            _switch('Solar power', _solar, (v) => setState(() => _solar = v)),
            _switch(
                'Borehole', _borehole, (v) => setState(() => _borehole = v)),
            _switch('Pet friendly', _pets, (v) => setState(() => _pets = v)),
            _switch('360 tour / video walkthrough ready', _tour,
                (v) => setState(() => _tour = v)),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
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
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  widget.property == null ? 'Create listing' : 'Save changes',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───
  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _searchFill,
        labelStyle: const TextStyle(
          color: _textMuted,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

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
        decoration: _inputDeco(label),
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: _textDark),
        validator: (value) =>
            requiredField && (value == null || value.trim().isEmpty)
                ? 'Required'
                : null,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: _primary,
      title: Text(label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: _textDark,
          )),
      value: value,
      onChanged: onChanged,
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
