import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_terms.dart';
import '../screens/user/terms_privacy_screen.dart';

/// Stops signed-in users from entering the app until they accept the current
/// Terms & Privacy version. The server remains the source of truth.
class TermsAcceptanceGate extends StatefulWidget {
  const TermsAcceptanceGate({super.key, required this.child});
  final Widget child;

  @override
  State<TermsAcceptanceGate> createState() => _TermsAcceptanceGateState();
}

class _TermsAcceptanceGateState extends State<TermsAcceptanceGate> {
  bool _loading = true;
  bool _accepted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAcceptance();
  }

  Future<void> _checkAcceptance() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() { _loading = false; _accepted = true; });
      return;
    }
    try {
      final row = await client.from('users').select('terms_version').eq('id', userId).single();
      if (!mounted) return;
      setState(() {
        _accepted = row['terms_version'] == kTermsVersion;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not check your Terms & Privacy acceptance. Connect to the internet and retry.';
      });
    }
  }

  Future<void> _accept() async {
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('accept_terms', params: {'p_version': kTermsVersion});
      if (mounted) setState(() { _accepted = true; _saving = false; });
    } catch (_) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'We could not save your acceptance. Please try again.';
      });
    }
  }

  void _openLegal(bool privacy) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TermsPrivacyScreen(initialTab: privacy ? 1 : 0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.policy_outlined, size: 36),
                const SizedBox(height: 14),
                Text('Terms & Privacy updated', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text('Please review and accept the current Terms of Use and Privacy Policy to continue.', textAlign: TextAlign.center),
                Wrap(alignment: WrapAlignment.center, children: [
                  TextButton(onPressed: () => _openLegal(false), child: const Text('Read Terms')),
                  TextButton(onPressed: () => _openLegal(true), child: const Text('Read Privacy Policy')),
                ]),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
                  TextButton(onPressed: _checkAcceptance, child: const Text('Retry')),
                ],
                const SizedBox(height: 8),
                FilledButton(onPressed: _saving ? null : _accept, child: Text(_saving ? 'Saving…' : 'Accept and continue')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
