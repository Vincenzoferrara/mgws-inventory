import '../../l10n/error_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/theme.dart';
import '../../l10n/extensions.dart';

class CalDavLoginTab extends StatefulWidget {
  const CalDavLoginTab({super.key});

  @override
  State<CalDavLoginTab> createState() => _CalDavLoginTabState();
}

class _CalDavLoginTabState extends State<CalDavLoginTab> {
  final _storage = const FlutterSecureStorage();
  final _siteController = TextEditingController();
  final _parameterController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  static const String _keySite = 'caldav_site';
  static const String _keyParameter = 'caldav_parameter';
  static const String _keyUsername = 'caldav_username';
  static const String _keyPassword = 'caldav_password';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final site = await _storage.read(key: _keySite);
      final parameter = await _storage.read(key: _keyParameter);
      final username = await _storage.read(key: _keyUsername);
      final password = await _storage.read(key: _keyPassword);

      setState(() {
        _siteController.text = site ?? '';
        _parameterController.text = parameter ?? '';
        _usernameController.text = username ?? '';
        _passwordController.text = password ?? '';
      });
    } catch (e) {
      // Ignora errori di caricamento
    }
  }

  Future<void> _saveCredentials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _storage.write(key: _keySite, value: _siteController.text.trim());
      await _storage.write(
        key: _keyParameter,
        value: _parameterController.text.trim(),
      );
      await _storage.write(
        key: _keyUsername,
        value: _usernameController.text.trim(),
      );
      await _storage.write(key: _keyPassword, value: _passwordController.text);

      setState(() {
        _successMessage = context.l10n.caldavCredenzialiSalvate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.caldavErroreSalvataggio(
          localizedErrorText(context.l10n, e),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCredentials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _storage.delete(key: _keySite);
      await _storage.delete(key: _keyParameter);
      await _storage.delete(key: _keyUsername);
      await _storage.delete(key: _keyPassword);

      _siteController.clear();
      _parameterController.clear();
      _usernameController.clear();
      _passwordController.clear();

      setState(() {
        _successMessage = context.l10n.caldavCredenzialiCancellate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.caldavErroreCancellamento(
          localizedErrorText(context.l10n, e),
        );
        _isLoading = false;
      });
    }
  }

  void _setPreset(String service) {
    if (service == 'Nextcloud') {
      _siteController.text = 'your-nextcloud.com';
      _parameterController.text = '/remote.php/dav/';
    } else if (service == 'Vikunja') {
      _siteController.text = 'your-vikunja.com';
      _parameterController.text = '/dav/';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.caldavConfigurazione,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.caldavSelezionaServizio),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _setPreset('Nextcloud'),
                child: const Text('Nextcloud'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _setPreset('Vikunja'),
                child: const Text('Vikunja'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _siteController,
            decoration: InputDecoration(
              labelText: context.l10n.caldavNomeSito,
              hintText: 'tuosito.com',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _parameterController,
            decoration: InputDecoration(
              labelText: context.l10n.caldavParametroUrl,
              hintText: '/remote.php/dav/',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.loginUsername,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: context.l10n.loginPassword,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.errorColorStatus,
              ),
            ),
          if (_successMessage != null)
            Text(
              _successMessage!,
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.successColor,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCredentials,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(context.l10n.caldavSalvaCredenziali),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _clearCredentials,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.errorColorStatus,
                  foregroundColor: Colors.white,
                ),
                child: Text(context.l10n.caldavCancella),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.caldavNotaSicurezza,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _siteController.dispose();
    _parameterController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
