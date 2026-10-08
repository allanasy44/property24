import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late Future<List<Map<String, dynamic>>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final token = context.read<Property24State>().token;
    if (token == null) {
      throw const ApiException('Sign in with a support-admin account.');
    }
    return Property24Api().adminReports(token);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _reports = next);
    await context.read<Property24State>().refresh();
    await next;
  }

  Future<void> _updateReport(
    Map<String, dynamic> report,
    String status,
  ) async {
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().updateAdminReport(
        token: token,
        reportId: '${report['id']}',
        data: {'status': status},
      );
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text('${report['subject'] ?? 'Support report'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().deleteAdminReport(
        token: token,
        reportId: '${report['id']}',
      );
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _reviewVerification(
    VerificationItem verification,
    String status,
  ) async {
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().reviewAdminVerification(
        token: token,
        verificationId: verification.id,
        status: status,
      );
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _updateApplication(
    ApplicationItem application,
    String status,
  ) async {
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().updateAdminApplication(
        token: token,
        applicationId: application.id,
        status: status,
      );
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _updateViewing(ViewingItem viewing, String status) async {
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().updateViewingStatus(token, viewing.id, status);
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  void _showError(Object exception) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(exception))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = context.watch<Property24State>().snapshot;
    final verifications = platform.verifications;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Support queue'),
        actions: [
          IconButton(
            tooltip: 'Create support report',
            onPressed: _createReport,
            icon: const Icon(CupertinoIcons.plus),
          ),
          IconButton(
            tooltip: 'Refresh support queue',
            onPressed: _reload,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    userFacingError(snapshot.error!),
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              );
            }
            final reports = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionTitle(
                  title: 'Reports',
                  count: reports.length,
                ),
                if (reports.isEmpty)
                  const _EmptyCard(message: 'No support reports.'),
                for (final report in reports) _reportCard(report),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Applications',
                  count: platform.applications.length,
                ),
                if (platform.applications.isEmpty)
                  const _EmptyCard(message: 'No rental applications.'),
                for (final application in platform.applications)
                  _applicationCard(application),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Viewings',
                  count: platform.viewings.length,
                ),
                if (platform.viewings.isEmpty)
                  const _EmptyCard(message: 'No viewing bookings.'),
                for (final viewing in platform.viewings) _viewingCard(viewing),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Identity verification',
                  count: verifications.length,
                ),
                if (verifications.isEmpty)
                  const _EmptyCard(message: 'No verification requests.'),
                for (final verification in verifications)
                  _verificationCard(verification),
                const SizedBox(height: 12),
                Text(
                  'Private chats and call contents are not available in this support workspace.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textMuted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createReport() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (data == null || !mounted) return;
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().createAdminReport(token: token, data: data);
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final status = '${report['status'] ?? 'open'}';
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report['subject'] ?? 'Support report'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${report['description'] ?? ''}',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'From ${report['reporter'] ?? 'User'} · ${status.toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                if (status == 'open')
                  TextButton(
                    onPressed: () => _updateReport(report, 'reviewing'),
                    child: const Text('Review'),
                  ),
                if (status != 'resolved')
                  TextButton(
                    onPressed: () => _updateReport(report, 'resolved'),
                    child: const Text('Resolve'),
                  ),
                TextButton(
                  onPressed: () => _deleteReport(report),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationCard(VerificationItem verification) {
    final normalized = verification.status.toLowerCase();
    final pending = !{'verified', 'approved', 'rejected', 'failed'}
        .contains(normalized);
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        leading: const Icon(
          CupertinoIcons.checkmark_shield,
          color: AppTheme.accent,
        ),
        title: Text(verification.name),
        subtitle: Text('${verification.role} · ${verification.status}'),
        trailing: pending
            ? PopupMenuButton<String>(
                tooltip: 'Review verification',
                onSelected: (status) => _reviewVerification(
                  verification,
                  status,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'approved',
                    child: Text('Approve'),
                  ),
                  PopupMenuItem(
                    value: 'rejected',
                    child: Text('Reject'),
                  ),
                  PopupMenuItem(
                    value: 'reviewing',
                    child: Text('Mark reviewing'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _applicationCard(ApplicationItem application) {
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        leading: const Icon(
          CupertinoIcons.doc_text,
          color: AppTheme.accent,
        ),
        title: Text(application.property),
        subtitle: Text(
          '${application.applicant} · ${application.status} · Score ${application.score}',
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Update application',
          onSelected: (status) => _updateApplication(application, status),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'submitted', child: Text('Submitted')),
            PopupMenuItem(value: 'under_review', child: Text('Under review')),
            PopupMenuItem(value: 'approved', child: Text('Approve')),
            PopupMenuItem(value: 'declined', child: Text('Decline')),
            PopupMenuItem(value: 'withdrawn', child: Text('Withdraw')),
          ],
        ),
      ),
    );
  }

  Widget _viewingCard(ViewingItem viewing) {
    return Card(
      color: AppTheme.bgCard,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        leading: const Icon(
          CupertinoIcons.calendar,
          color: AppTheme.accent,
        ),
        title: Text(viewing.property),
        subtitle: Text(
          '${viewing.tenant} · ${viewing.scheduledFor} · ${viewing.status}',
        ),
        trailing: viewing.status.toLowerCase() == 'pending'
            ? PopupMenuButton<String>(
                tooltip: 'Update viewing',
                onSelected: (status) => _updateViewing(viewing, status),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'confirmed', child: Text('Confirm')),
                  PopupMenuItem(value: 'rejected', child: Text('Reject')),
                ],
              )
            : null,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text('$count', style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'subject': _subject.text.trim(),
      'description': _description.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New support report'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Add a subject' : null,
            ),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Details'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add report details'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}
