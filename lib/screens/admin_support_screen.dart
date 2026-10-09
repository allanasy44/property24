import 'dart:typed_data';

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
  late Future<List<VerificationItem>> _verifications;

  @override
  void initState() {
    super.initState();
    _verifications = _load();
  }

  Future<List<VerificationItem>> _load() {
    final token = context.read<Property24State>().token;
    if (token == null) {
      throw const ApiException('Sign in with a support-admin account.');
    }
    return Property24Api().adminFailedLandlordVerifications(token);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _verifications = next);
    await next;
  }

  Future<void> _review(VerificationItem verification, String status) async {
    final approved = status == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Approve verification?' : 'Reject verification?'),
        content: Text(
          approved
              ? 'This will mark ${verification.name} as verified.'
              : 'This will keep ${verification.name} unverified and close this failed-check review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().reviewAdminVerification(
        token: token,
        verificationId: verification.id,
        status: status,
      );
      await _reload();
      await context.read<Property24State>().refresh(silent: true);
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _previewDocument(
    VerificationItem verification,
    String documentType,
  ) async {
    final token = context.read<Property24State>().token;
    if (token == null) return;
    final future = Property24Api().adminVerificationDocument(
      token: token,
      verificationId: verification.id,
      documentType: documentType,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verification.name} · ${_documentLabel(documentType)}'),
        content: SizedBox(
          width: 560,
          child: FutureBuilder<Uint8List>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(userFacingError(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'The verification document could not be displayed.',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _documentLabel(String type) => switch (type) {
        'id-front' => 'ID front',
        'id-back' => 'ID back',
        _ => 'Document',
      };

  void _showError(Object exception) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(exception))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Failed landlord verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh verification queue',
            onPressed: _reload,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<VerificationItem>>(
          future: _verifications,
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
            final verifications = snapshot.data!
                .where((item) =>
                    item.role.toLowerCase() == 'landlord' &&
                    {'failed', 'rejected'}.contains(item.status.toLowerCase()),)
                .toList(growable: false);
            if (verifications.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'There are no failed landlord document checks to review.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: verifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _verificationCard(verifications[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _verificationCard(VerificationItem verification) {
    return Card(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.doc_text_viewfinder,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verification.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  verification.status,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              verification.failureReason.isNotEmpty
                  ? verification.failureReason
                  : 'Automated document verification failed.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            if (verification.verificationProvider.isNotEmpty ||
                verification.verificationScore.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (verification.verificationProvider.isNotEmpty)
                    verification.verificationProvider,
                  if (verification.verificationScore.isNotEmpty)
                    'Score ${verification.verificationScore}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (verification.checks.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final check in verification.checks)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '• $check',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (verification.frontDocumentUploaded)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _previewDocument(verification, 'id-front'),
                    icon: const Icon(CupertinoIcons.doc_text_search),
                    label: const Text('View ID front'),
                  ),
                if (verification.backDocumentUploaded)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _previewDocument(verification, 'id-back'),
                    icon: const Icon(CupertinoIcons.doc_text_search),
                    label: const Text('View ID back'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _review(verification, 'rejected'),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _review(verification, 'approved'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
