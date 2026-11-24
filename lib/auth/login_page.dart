import 'package:flutter/material.dart';

import 'supabase_auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginPage({super.key, required this.onAuthenticated});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseAuthService.signIn(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
      if (mounted) widget.onAuthenticated();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseAuthService.isConfigured;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/fond_dashboard.jpg', fit: BoxFit.cover),
          ColoredBox(color: Colors.black.withOpacity(0.34)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    color: Colors.white.withOpacity(0.97),
                    elevation: 14,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Image.asset(
                              'assets/images/logo_sogb.jpg',
                              height: 66,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'RUBBERWAY · GESTION DES ENQUÊTES RDUE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF27833A),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Connexion',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF17251A),
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connectez-vous avec votre compte RUBBERWAY.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 25),
                            TextFormField(
                              controller: _identifierController,
                              enabled: !_busy && configured,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'Identifiant agent',
                                hintText: 'KwakuKona_RDUESOGB',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'Saisissez votre identifiant agent.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_busy && configured,
                              obscureText: !_passwordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _connecter(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _passwordVisible
                                      ? 'Masquer le mot de passe'
                                      : 'Afficher le mot de passe',
                                  onPressed: () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value ?? '').isEmpty
                                  ? 'Saisissez votre mot de passe.'
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              _MessageBox(message: _error!, isError: true),
                            ],
                            if (!configured) ...[
                              const SizedBox(height: 14),
                              const _MessageBox(
                                message:
                                    'La connexion Supabase doit être configurée pour cette compilation. Consultez le fichier README du projet.',
                                isError: true,
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _busy || !configured
                                    ? null
                                    : _connecter,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF27833A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Se connecter',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Après la connexion, les enquêtes continuent de fonctionner hors ligne sur cet appareil.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBox({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB3261E) : const Color(0xFF27833A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13, height: 1.4),
      ),
    );
  }
}
