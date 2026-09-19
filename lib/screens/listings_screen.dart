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
    final displayName = state.user?.name.trim() ?? '';
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
                    InkWell(
                      onTap: _openAiSearch,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: _searchFill,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: _textMuted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _query.isEmpty ? '' : _query,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      _query.isEmpty ? _textMuted : _textDark,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (_query.isNotEmpty)
                              IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: _textMuted,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
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
            else if (listings.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No matching listings',
                  body: '',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList.builder(
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final property = listings[index];
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PropertyEditor(property: property),
      ),
    );
  }

  Future<void> _openAiSearch() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => AiSearchScreen(initialQuery: _query),
      ),
    );
    if (!mounted || query == null) return;
    setState(() => _query = query);
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          child,
        ],
      ),
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
  String _intent = 'Rent';
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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.property == null ? 'Add property' : 'Edit property'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, inset + 96),
          children: [
            _Section(
              title: 'Property for',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Sale', label: Text('Sale')),
                  ButtonSegment(value: 'Rent', label: Text('Rent')),
                ],
                selected: {_intent},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _intent = value.first),
              ),
            ),
            _Section(
              title: 'Property details',
              child: Column(
                children: [
                  _field(_title, 'Title'),
                  _field(_description, 'Details', maxLines: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: _inputDeco('Property type'),
                      items: const [
                        DropdownMenuItem(value: 'house', child: Text('House')),
                        DropdownMenuItem(value: 'flat', child: Text('Flat')),
                        DropdownMenuItem(
                            value: 'cottage', child: Text('Cottage')),
                        DropdownMenuItem(
                          value: 'student_accommodation',
                          child: Text('Student accommodation'),
                        ),
                        DropdownMenuItem(
                          value: 'commercial_property',
                          child: Text('Commercial property'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _type = value ?? 'house'),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Location',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _field(_city, 'City')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_suburb, 'Suburb')),
                    ],
                  ),
                  _field(_address, 'House address'),
                ],
              ),
            ),
            _Section(
              title: 'Pricing and rooms',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _rent,
                          _intent == 'Sale' ? 'Price' : 'Monthly rent',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          _deposit,
                          'Deposit',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _beds,
                          'Bedrooms',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          _baths,
                          'Bathrooms',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Features',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _field(_water, 'Water availability')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_parking, 'Parking')),
                    ],
                  ),
                  _switch('Furnished', _furnished,
                      (v) => setState(() => _furnished = v)),
                  _switch(
                      'Solar power', _solar, (v) => setState(() => _solar = v)),
                  _switch('Borehole', _borehole,
                      (v) => setState(() => _borehole = v)),
                  _switch(
                      'Pet friendly', _pets, (v) => setState(() => _pets = v)),
                  _switch('360 tour / video walkthrough ready', _tour,
                      (v) => setState(() => _tour = v)),
                ],
              ),
            ),
            _Section(
              title: 'Media',
              child: Column(
                children: [
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
                ],
              ),
            ),
            _Section(
              title: 'Readiness',
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(18),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(widget.property == null ? 'Continue' : 'Save changes'),
          ),
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
      if (!mounted) return;
      await _showSuccessDialog();
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.16),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.property == null
                      ? 'Your property listed successfully.'
                      : 'Your listing was updated successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
