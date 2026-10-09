import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    required this.market,
    this.initialView = 'browse',
    this.createOnOpen = false,
    this.onSelectMarket,
    super.key,
  });

  final String market;
  final String initialView;
  final bool createOnOpen;
  final ValueChanged<String>? onSelectMarket;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _serviceCategory = '';
  String _jobType = '';
  late String _view;
  bool _didHandleCreate = false;

  bool get _isServices => widget.market == 'services';

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    if (widget.createOnOpen) _scheduleCreate();
  }

  @override
  void didUpdateWidget(covariant MarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialView != widget.initialView) {
      _view = widget.initialView;
    }
    if (widget.createOnOpen &&
        (!oldWidget.createOnOpen || oldWidget.market != widget.market)) {
      _scheduleCreate();
    }
  }

  void _scheduleCreate() {
    if (_didHandleCreate) return;
    _didHandleCreate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCreateForm();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final signedIn = state.signedIn;
    final userId = state.user?.id;
    final services = state.snapshot.services
        .where((service) {
          if (service.status != 'active') return false;
          if (_view == 'mine' && service.owner.id != userId) return false;
          if (_serviceCategory.isNotEmpty &&
              service.category.toLowerCase() !=
                  _serviceCategory.toLowerCase()) {
            return false;
          }
          final searchText = [
            service.title,
            service.category,
            service.description,
            service.location,
            service.owner.name,
          ].join(' ').toLowerCase();
          return _query.trim().isEmpty ||
              searchText.contains(_query.trim().toLowerCase());
        })
        .toList(growable: false);
    final jobs = state.snapshot.jobs
        .where((job) {
          if (job.status != 'active') return false;
          if (_view == 'mine' && job.owner.id != userId) return false;
          if (_jobType.isNotEmpty && job.employmentType != _jobType) {
            return false;
          }
          final searchText = [
            job.title,
            job.category,
            job.description,
            job.location,
            job.employmentType,
            job.owner.name,
          ].join(' ').toLowerCase();
          return _query.trim().isEmpty ||
              searchText.contains(_query.trim().toLowerCase());
        })
        .toList(growable: false);
    final applications = state.snapshot.jobApplications
        .where((application) {
          if (_view == 'applications') return application.applicantId == userId;
          if (_view == 'candidates') return application.ownerId == userId;
          return true;
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isServices ? 'Services' : 'Jobs',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isServices
                                    ? 'Find trusted help for everyday tasks.'
                                    : 'Discover opportunities that fit your skills.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (signedIn) ...[
                          const SizedBox(width: 12),
                          IconButton.filled(
                            tooltip: _isServices
                                ? 'Offer a service'
                                : 'Post a job',
                            onPressed: _openCreateForm,
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              fixedSize: const Size(44, 44),
                            ),
                            icon: const Icon(CupertinoIcons.add),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MarketTabs(
                      selected: widget.market,
                      onSelected: widget.onSelectMarket,
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      controller: _searchController,
                      hintText: _isServices
                          ? 'What service do you need?'
                          : 'Search jobs or locations',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    if (_view == 'browse' && _isServices) ...[
                      const SizedBox(height: 12),
                      _ContextFilterRow(
                        selected: _serviceCategory,
                        items: const [
                          ('All', ''),
                          ('Cleaning', 'Cleaning'),
                          ('Plumbing', 'Plumbing'),
                          ('Electrical', 'Electrical'),
                          ('Gardening', 'Gardening'),
                          ('Solar', 'Solar'),
                          ('Moving', 'Moving'),
                        ],
                        onSelected: (value) =>
                            setState(() => _serviceCategory = value),
                      ),
                    ],
                    if (_view == 'browse' && !_isServices) ...[
                      const SizedBox(height: 12),
                      _ContextFilterRow(
                        selected: _jobType,
                        items: const [
                          ('All', ''),
                          ('Full-time', 'full_time'),
                          ('Part-time', 'part_time'),
                          ('Contract', 'contract'),
                          ('Temporary', 'temporary'),
                        ],
                        onSelected: (value) => setState(() => _jobType = value),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ViewTabs(
                      market: widget.market,
                      selected: _view,
                      showCandidates: state.snapshot.jobApplications.any(
                        (application) => application.ownerId == userId,
                      ),
                      onSelected: (value) => setState(() => _view = value),
                    ),
                    const SizedBox(height: 18),
                    if (_view == 'requests')
                      _ServiceRequests(
                        requests: state.snapshot.serviceRequests,
                        services: state.snapshot.services,
                        userId: userId,
                        onStatusChange: _updateServiceRequest,
                      )
                    else if (_view == 'applications')
                      _JobApplications(
                        applications: applications,
                        jobs: state.snapshot.jobs,
                        userId: userId,
                        onStatusChange: _updateJobApplication,
                      )
                    else if (_isServices)
                      if (services.isEmpty)
                        _MarketplaceEmpty(
                          icon: CupertinoIcons.wrench,
                          title: _view == 'mine'
                              ? 'No services listed yet'
                              : 'No services found',
                          body: _view == 'mine'
                              ? 'Offer a service and manage it here.'
                              : 'Try another search or be the first to offer a service.',
                          actionLabel: signedIn ? 'Offer a service' : null,
                          onAction: signedIn ? _openCreateForm : null,
                        )
                      else
                        for (final service in services)
                          _ServiceCard(
                            service: service,
                            isOwner: service.owner.id == userId,
                            hasRequested: state.snapshot.serviceRequests.any(
                              (request) =>
                                  request.serviceId == service.id &&
                                  request.requesterId == userId,
                            ),
                            onRequest: () => _requestService(service),
                            onEdit: () => _openCreateForm(service: service),
                            onDelete: () => _deleteService(service),
                          )
                    else if (jobs.isEmpty)
                      _MarketplaceEmpty(
                        icon: CupertinoIcons.briefcase,
                        title: _view == 'mine'
                            ? 'No job posts yet'
                            : 'No jobs found',
                        body: _view == 'mine'
                            ? 'Post a job and manage it here.'
                            : 'Try another search or check back soon.',
                        actionLabel: signedIn ? 'Post a job' : null,
                        onAction: signedIn ? _openCreateForm : null,
                      )
                    else
                      for (final job in jobs)
                        _JobCard(
                          job: job,
                          isOwner: job.owner.id == userId,
                          hasApplied: state.snapshot.jobApplications.any(
                            (application) => application.jobId == job.id,
                          ),
                          onApply: () => _applyToJob(job),
                          onEdit: () => _openCreateForm(job: job),
                          onDelete: () => _deleteJob(job),
                        ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm({
    ServiceListing? service,
    JobPosting? job,
  }) async {
    if (!context.read<Property24State>().signedIn) {
      _openSignIn();
      return;
    }
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(105),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MarketplaceListingForm(
        isServices: _isServices,
        service: service,
        job: job,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      final state = context.read<Property24State>();
      if (_isServices) {
        if (service == null) {
          await state.createService(payload);
        } else {
          await state.updateService(service, payload);
        }
      } else {
        if (job == null) {
          await state.createJob(payload);
        } else {
          await state.updateJob(job, payload);
        }
      }
      if (mounted) {
        setState(() => _view = 'mine');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              service != null || job != null
                  ? 'Changes saved'
                  : _isServices
                  ? 'Service published'
                  : 'Job posted',
            ),
          ),
        );
      }
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _requestService(ServiceListing service) async {
    if (!context.read<Property24State>().signedIn) {
      _openSignIn();
      return;
    }
    final message = await _messageDialog(
      title: 'Request ${service.title}',
      hint: 'Tell the provider what you need',
      actionLabel: 'Send request',
    );
    if (message == null || !mounted) return;
    try {
      await context.read<Property24State>().requestService(service, message);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Service request sent')));
      }
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _applyToJob(JobPosting job) async {
    if (!context.read<Property24State>().signedIn) {
      _openSignIn();
      return;
    }
    final coverMessage = await _messageDialog(
      title: 'Apply for ${job.title}',
      hint: 'Introduce yourself and share why you are a good fit',
      actionLabel: 'Submit application',
    );
    if (coverMessage == null || !mounted) return;
    try {
      await context.read<Property24State>().applyToJob(job, coverMessage);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Application submitted')));
      }
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<String?> _messageDialog({
    required String title,
    required String hint,
    required String actionLabel,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(105),
      builder: (_) => _MarketplaceMessageSheet(
        title: title,
        hint: hint,
        actionLabel: actionLabel,
      ),
    );
  }

  Future<void> _deleteService(ServiceListing service) async {
    if (!await _confirmDelete(service.title) || !mounted) return;
    try {
      await context.read<Property24State>().deleteService(service.id);
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _deleteJob(JobPosting job) async {
    if (!await _confirmDelete(job.title) || !mounted) return;
    try {
      await context.read<Property24State>().deleteJob(job.id);
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _updateServiceRequest(
    ServiceRequestItem request,
    String status,
  ) async {
    try {
      await context.read<Property24State>().updateServiceRequest(
        request,
        status,
      );
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _updateJobApplication(
    JobApplicationItem application,
    String status,
  ) async {
    try {
      await context.read<Property24State>().updateJobApplication(
        application,
        status,
      );
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove this listing?'),
            content: Text(title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openSignIn() {
    context.pushNamed(
      AppRoutes.authName,
      pathParameters: const {'role': 'tenant'},
    );
  }

  void _showError(Object exception) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
  }
}

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String>? onSelected;

  static const _markets = [
    ('Properties', 'properties'),
    ('Stays', 'stays'),
    ('Venues', 'venues'),
    ('Services', 'services'),
    ('Jobs', 'jobs'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _markets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, market) = _markets[index];
          final isSelected = market == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: onSelected == null ? null : (_) => onSelected!(market),
            selectedColor: AppTheme.accent,
            backgroundColor: AppTheme.bgSurface,
            side: BorderSide(color: AppTheme.border),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({
    required this.market,
    required this.selected,
    required this.showCandidates,
    required this.onSelected,
  });

  final String market;
  final String selected;
  final bool showCandidates;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = market == 'services'
        ? const [
            ('Browse', 'browse'),
            ('My services', 'mine'),
            ('Requests', 'requests'),
          ]
        : [
            const ('Find work', 'browse'),
            const ('My job posts', 'mine'),
            const ('My applications', 'applications'),
            if (showCandidates) const ('Candidates', 'candidates'),
          ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, value) = tabs[index];
          final isSelected = selected == value;
          return GestureDetector(
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withAlpha(24) : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          prefixIcon: Icon(
            CupertinoIcons.search,
            color: AppTheme.textMuted,
            size: 19,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _ContextFilterRow extends StatelessWidget {
  const _ContextFilterRow({
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  final String selected;
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final (label, value) = items[index];
          final isSelected = selected == value;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            selectedColor: AppTheme.accent.withAlpha(24),
            backgroundColor: AppTheme.bgSurface,
            side: BorderSide(color: AppTheme.border),
            labelStyle: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _MarketplaceListingForm extends StatefulWidget {
  const _MarketplaceListingForm({
    required this.isServices,
    this.service,
    this.job,
  });

  final bool isServices;
  final ServiceListing? service;
  final JobPosting? job;

  @override
  State<_MarketplaceListingForm> createState() =>
      _MarketplaceListingFormState();
}

class _MarketplaceListingFormState extends State<_MarketplaceListingForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _compensation;
  late String _priceType;
  late String _employmentType;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    final job = widget.job;
    _title = TextEditingController(text: service?.title ?? job?.title ?? '');
    _category = TextEditingController(
      text: service?.category ?? job?.category ?? '',
    );
    _location = TextEditingController(
      text: service?.location ?? job?.location ?? '',
    );
    _description = TextEditingController(
      text: service?.description ?? job?.description ?? '',
    );
    _price = TextEditingController(text: service?.price ?? '');
    _compensation = TextEditingController(text: job?.compensation ?? '');
    _priceType = service?.priceType ?? 'fixed';
    _employmentType = job?.employmentType ?? 'full_time';
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _location.dispose();
    _description.dispose();
    _price.dispose();
    _compensation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isEditing = widget.service != null || widget.job != null;
    final title = widget.isServices
        ? isEditing
              ? 'Edit your service'
              : 'Offer a service'
        : isEditing
        ? 'Edit your job post'
        : 'Post a job';
    final subtitle = widget.isServices
        ? 'Help customers understand what you offer and how to reach you.'
        : 'Share the role, location and pay details with potential applicants.';
    final submitLabel = isEditing
        ? 'Save changes'
        : widget.isServices
        ? 'Publish service'
        : 'Publish job';
    final bottomInset = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top - bottomInset - 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.border.withAlpha(130)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withAlpha(85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withAlpha(22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          widget.isServices
                              ? CupertinoIcons.wrench
                              : CupertinoIcons.briefcase,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.border.withAlpha(150)),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _formSectionLabel(
                          'THE ${widget.isServices ? 'OFFER' : 'ROLE'}',
                        ),
                        _input(
                          _title,
                          widget.isServices ? 'Service title' : 'Job title',
                        ),
                        Row(
                          children: [
                            Expanded(child: _input(_category, 'Category')),
                            const SizedBox(width: 12),
                            Expanded(child: _input(_location, 'Location')),
                          ],
                        ),
                        _input(
                          _description,
                          widget.isServices
                              ? 'What do you offer?'
                              : 'About the role',
                          minLines: 3,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 6),
                        _formSectionLabel(
                          widget.isServices ? 'PRICING' : 'JOB DETAILS',
                        ),
                        if (widget.isServices) ...[
                          _input(
                            _price,
                            'Price (optional)',
                            keyboardType: TextInputType.number,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _priceType,
                            decoration: _inputDecoration('Pricing type'),
                            items: const [
                              DropdownMenuItem(
                                value: 'fixed',
                                child: Text('Fixed price'),
                              ),
                              DropdownMenuItem(
                                value: 'hourly',
                                child: Text('Hourly'),
                              ),
                              DropdownMenuItem(
                                value: 'quote',
                                child: Text('Request a quote'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _priceType = value);
                              }
                            },
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            initialValue: _employmentType,
                            decoration: _inputDecoration('Employment type'),
                            items: const [
                              DropdownMenuItem(
                                value: 'full_time',
                                child: Text('Full-time'),
                              ),
                              DropdownMenuItem(
                                value: 'part_time',
                                child: Text('Part-time'),
                              ),
                              DropdownMenuItem(
                                value: 'contract',
                                child: Text('Contract'),
                              ),
                              DropdownMenuItem(
                                value: 'temporary',
                                child: Text('Temporary'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _employmentType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _input(_compensation, 'Pay (optional)'),
                        ],
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppTheme.border.withAlpha(150)),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    submitLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    CupertinoIcons.arrow_right,
                                    size: 17,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label),
        validator: (value) {
          if (label.endsWith('(optional)')) return null;
          if (value == null || value.trim().isEmpty) {
            return 'Enter ${label.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppTheme.bgSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
    ),
  );

  Widget _formSectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.15,
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final payload = widget.isServices
        ? <String, dynamic>{
            'title': _title.text.trim(),
            'category': _category.text.trim(),
            'location': _location.text.trim(),
            'description': _description.text.trim(),
            'price': _price.text.trim(),
            'price_type': _priceType,
          }
        : <String, dynamic>{
            'title': _title.text.trim(),
            'category': _category.text.trim(),
            'location': _location.text.trim(),
            'description': _description.text.trim(),
            'employment_type': _employmentType,
            'compensation': _compensation.text.trim(),
          };
    if (mounted) Navigator.of(context).pop(payload);
  }
}

class _MarketplaceMessageSheet extends StatefulWidget {
  const _MarketplaceMessageSheet({
    required this.title,
    required this.hint,
    required this.actionLabel,
  });

  final String title;
  final String hint;
  final String actionLabel;

  @override
  State<_MarketplaceMessageSheet> createState() =>
      _MarketplaceMessageSheetState();
}

class _MarketplaceMessageSheetState extends State<_MarketplaceMessageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isApplication = widget.actionLabel.toLowerCase().contains(
      'application',
    );
    final bottomInset = media.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top - bottomInset - 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.border.withAlpha(130)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withAlpha(85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withAlpha(22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isApplication
                              ? CupertinoIcons.briefcase
                              : CupertinoIcons.chat_bubble_text,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isApplication
                                  ? 'Add a short note to support your application.'
                                  : 'Share a few details so the provider can help.',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.border.withAlpha(150)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                  child: TextFormField(
                    controller: _message,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 7,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: isApplication
                          ? 'Message to the employer'
                          : 'Your message',
                      hintText: widget.hint,
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppTheme.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a message to continue.'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(_message.text.trim());
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.actionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_right, size: 17),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isOwner,
    required this.hasRequested,
    required this.onRequest,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceListing service;
  final bool isOwner;
  final bool hasRequested;
  final VoidCallback onRequest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isOwner) ...[
                  IconButton(
                    tooltip: 'Edit service',
                    onPressed: onEdit,
                    icon: Icon(
                      CupertinoIcons.pencil,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove service',
                    onPressed: onDelete,
                    icon: Icon(CupertinoIcons.trash, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
            Text(
              '${service.category} · ${service.location}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              service.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.price.isEmpty
                        ? 'Contact for pricing'
                        : '${money(service.price)} · ${_priceLabel(service.priceType)}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isOwner)
                  FilledButton(
                    onPressed: hasRequested ? null : onRequest,
                    child: Text(hasRequested ? 'Requested' : 'Request'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provided by ${service.owner.name}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(String value) => switch (value) {
    'hourly' => 'per hour',
    'quote' => 'quote',
    _ => 'fixed',
  };
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.isOwner,
    required this.hasApplied,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final JobPosting job;
  final bool isOwner;
  final bool hasApplied;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final workType = job.employmentType
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join('-');
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isOwner) ...[
                  IconButton(
                    tooltip: 'Edit job post',
                    onPressed: onEdit,
                    icon: Icon(
                      CupertinoIcons.pencil,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove job post',
                    onPressed: onDelete,
                    icon: Icon(CupertinoIcons.trash, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
            Text(
              '${job.location} · $workType',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              job.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (job.compensation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job.compensation,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Posted by ${job.owner.name}',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
                if (!isOwner)
                  FilledButton(
                    onPressed: hasApplied ? null : onApply,
                    child: Text(hasApplied ? 'Applied' : 'Apply'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRequests extends StatelessWidget {
  const _ServiceRequests({
    required this.requests,
    required this.services,
    required this.userId,
    required this.onStatusChange,
  });

  final List<ServiceRequestItem> requests;
  final List<ServiceListing> services;
  final String? userId;
  final Future<void> Function(ServiceRequestItem, String) onStatusChange;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _MarketplaceEmpty(
        icon: CupertinoIcons.chat_bubble,
        title: 'No service requests yet',
        body: 'Requests you send or receive will appear here.',
      );
    }
    return Column(
      children: [
        for (final request in requests)
          _RequestRow(
            title: _serviceTitleFor(services, request.serviceId),
            subtitle: '${request.status} · ${request.requester.name}',
            message: request.message,
            actions: _requestActions(
              request.status,
              canManage: request.ownerId == userId,
              onStatusChange: (status) => onStatusChange(request, status),
              ownerActions: const [
                ('Accept', 'accepted'),
                ('Decline', 'declined'),
              ],
              participantActions: const [('Cancel request', 'cancelled')],
            ),
          ),
      ],
    );
  }
}

class _JobApplications extends StatelessWidget {
  const _JobApplications({
    required this.applications,
    required this.jobs,
    required this.userId,
    required this.onStatusChange,
  });

  final List<JobApplicationItem> applications;
  final List<JobPosting> jobs;
  final String? userId;
  final Future<void> Function(JobApplicationItem, String) onStatusChange;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const _MarketplaceEmpty(
        icon: CupertinoIcons.doc_text,
        title: 'No applications yet',
        body: 'Applications you send or receive will appear here.',
      );
    }
    return Column(
      children: [
        for (final application in applications)
          _RequestRow(
            title: _jobTitleFor(jobs, application.jobId),
            subtitle: '${application.status} · ${application.applicant.name}',
            message: application.coverMessage,
            actions: _requestActions(
              application.status,
              canManage: application.ownerId == userId,
              onStatusChange: (status) => onStatusChange(application, status),
              ownerActions: const [
                ('Accept', 'accepted'),
                ('Decline', 'declined'),
              ],
              participantActions: const [('Withdraw', 'withdrawn')],
            ),
          ),
      ],
    );
  }
}

String _serviceTitleFor(List<ServiceListing> services, String serviceId) {
  for (final service in services) {
    if (service.id == serviceId) return service.title;
  }
  return 'Service request';
}

String _jobTitleFor(List<JobPosting> jobs, String jobId) {
  for (final job in jobs) {
    if (job.id == jobId) return job.title;
  }
  return 'Job application';
}

Widget? _requestActions(
  String status, {
  required bool canManage,
  required ValueChanged<String> onStatusChange,
  required List<(String, String)> ownerActions,
  required List<(String, String)> participantActions,
}) {
  if (status != 'pending') return null;
  final actions = canManage ? ownerActions : participantActions;
  return Wrap(
    spacing: 8,
    children: [
      for (final (label, value) in actions)
        TextButton(onPressed: () => onStatusChange(value), child: Text(label)),
    ],
  );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.title,
    required this.subtitle,
    required this.message,
    this.actions,
  });

  final String title;
  final String subtitle;
  final String message;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 4),
            Text(message),
            if (actions != null) ...[const SizedBox(height: 4), actions!],
          ],
        ),
      ),
    );
  }
}

class _MarketplaceEmpty extends StatelessWidget {
  const _MarketplaceEmpty({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 25, color: AppTheme.accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
