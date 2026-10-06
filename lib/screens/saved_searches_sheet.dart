import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

Future<void> openSavedSearches(BuildContext context) {
  final state = context.read<Property24State>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.bgCard,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => _SavedSearchesContent(state: state),
        ),
      ),
    ),
  );
}

class _SavedSearchesContent extends StatelessWidget {
  const _SavedSearchesContent({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    final searches = state.savedSearches;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved searches',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _createSearch(context, state),
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: const Text('Create alert'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: searches.isEmpty
                ? Center(
                    child: Text(
                      'Save a search to get alerts when a matching home is listed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: searches.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: AppTheme.border),
                    itemBuilder: (context, index) {
                      final search = searches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          CupertinoIcons.bell,
                          color: search.isActive
                              ? AppTheme.accent
                              : AppTheme.textMuted,
                        ),
                        title: Text(
                          search.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${search.query}\n${search.matchCount} matching ${search.matchCount == 1 ? 'property' : 'properties'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch.adaptive(
                              value: search.isActive,
                              onChanged: (active) =>
                                  _setActive(context, state, search, active),
                            ),
                            IconButton(
                              tooltip: 'Delete saved search',
                              onPressed: () => _delete(context, state, search),
                              icon: const Icon(CupertinoIcons.trash),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSearch(
    BuildContext context,
    Property24State state,
  ) async {
    final criteria = await showDialog<_SavedSearchInput>(
      context: context,
      builder: (_) => const _SavedSearchDialog(),
    );
    if (criteria == null || !context.mounted) return;
    try {
      await state.saveSearch(
        criteria.query,
        name: criteria.name,
        criteria: criteria.criteria,
      );
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _setActive(
    BuildContext context,
    Property24State state,
    SavedSearchItem search,
    bool active,
  ) async {
    try {
      await state.setSavedSearchActive(search.id, isActive: active);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    Property24State state,
    SavedSearchItem search,
  ) async {
    try {
      await state.deleteSavedSearch(search.id);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }
}

class _SavedSearchInput {
  const _SavedSearchInput({
    required this.name,
    required this.query,
    required this.criteria,
  });

  final String name;
  final String query;
  final Map<String, dynamic> criteria;
}

class _SavedSearchDialog extends StatefulWidget {
  const _SavedSearchDialog();

  @override
  State<_SavedSearchDialog> createState() => _SavedSearchDialogState();
}

class _SavedSearchDialogState extends State<_SavedSearchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _bedrooms = TextEditingController();
  final _minimumRent = TextEditingController();
  final _maximumRent = TextEditingController();
  final _name = TextEditingController();
  String? _propertyType;

  @override
  void dispose() {
    _location.dispose();
    _bedrooms.dispose();
    _minimumRent.dispose();
    _maximumRent.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create property alert'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Alert name (optional)',
                ),
                maxLength: 80,
              ),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Suburb or city',
                  hintText: 'Hatfield',
                ),
                maxLength: 100,
              ),
              TextFormField(
                controller: _bedrooms,
                decoration: const InputDecoration(
                  labelText: 'Minimum bedrooms',
                ),
                keyboardType: TextInputType.number,
                validator: _integerValidator,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimumRent,
                      decoration: const InputDecoration(
                        labelText: 'Min rent',
                        prefixText: r'$ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _amountValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximumRent,
                      decoration: const InputDecoration(
                        labelText: 'Max rent',
                        prefixText: r'$ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _amountValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _propertyType,
                decoration: const InputDecoration(labelText: 'Property type'),
                items: const [
                  DropdownMenuItem(value: 'house', child: Text('House')),
                  DropdownMenuItem(value: 'flat', child: Text('Apartment')),
                  DropdownMenuItem(value: 'cottage', child: Text('Cottage')),
                  DropdownMenuItem(
                    value: 'student_accommodation',
                    child: Text('Student accommodation'),
                  ),
                  DropdownMenuItem(
                    value: 'commercial_property',
                    child: Text('Commercial property'),
                  ),
                ],
                onChanged: (value) => setState(() => _propertyType = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save alert'),
        ),
      ],
    );
  }

  String? _integerValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null || number < 0 || number > 20) {
      return 'Enter a whole number from 0 to 20';
    }
    return null;
  }

  String? _amountValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final amount = num.tryParse(text.replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount < 0) {
      return 'Enter a valid amount';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final location = _location.text.trim();
    final bedrooms = _bedrooms.text.trim();
    final minimumRent = _minimumRent.text.trim();
    final maximumRent = _maximumRent.text.trim();
    if (location.isEmpty &&
        bedrooms.isEmpty &&
        minimumRent.isEmpty &&
        maximumRent.isEmpty &&
        _propertyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one search filter.')),
      );
      return;
    }
    final minimum = num.tryParse(minimumRent.replaceAll(',', ''));
    final maximum = num.tryParse(maximumRent.replaceAll(',', ''));
    if (minimum != null && maximum != null && minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum rent must not exceed maximum.')),
      );
      return;
    }
    final clauses = <String>[
      if (bedrooms.isNotEmpty) '$bedrooms bedroom',
      if (location.isNotEmpty) location,
      if (minimumRent.isNotEmpty) 'from \$$minimumRent',
      if (maximumRent.isNotEmpty) 'to \$$maximumRent',
      if (_propertyType != null)
        _propertyType == 'flat' ? 'Apartment' : titleize(_propertyType),
    ];
    final label = _name.text.trim();
    Navigator.of(context).pop(
      _SavedSearchInput(
        name: label.isEmpty ? clauses.join(' · ') : label,
        query: clauses.join(' '),
        criteria: {
          'location': location,
          'bedrooms_min': bedrooms,
          'rent_min': minimumRent,
          'rent_max': maximumRent,
          'property_type': _propertyType ?? '',
          'intent': 'rent',
        },
      ),
    );
  }
}
