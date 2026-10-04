import 'package:flutter/material.dart';
import 'package:mgws_inventory/login/jwt_api/error_list.dart';
import 'package:mgws_inventory/login/jwt_api/jwt_connect.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme.dart';
import '../../traduzioni/estensioni.dart';
import 'login.code.dart';
import '../jwt_api/url_validator.dart';
import '../smartcard/smartcard_login_widget.dart';

/// Metodo di login disponibile
enum LoginMethod {
  credentials, // Username/Password o API Key
  smartcard, // Smartcard NFC/USB
}

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Chiavi per SharedPreferences
  static const String _prefKeyAuthType = 'login_auth_type';
  static const String _prefKeySiteUrl = 'login_site_url';

  final _formKey = GlobalKey<FormState>();
  final _siteUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jwtEndpointController = TextEditingController(
    text: 'simple-jwt-login/v1',
  );
  final _consumerKeyController = TextEditingController();
  final _consumerSecretController = TextEditingController();

  AuthType _authType = AuthType.wordpress;
  LoginMethod _loginMethod = LoginMethod.credentials;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _allowLocalhost = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Carica le preferenze salvate
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Carica il tipo di autenticazione (default: WordPress)
      final authTypeStr = prefs.getString(_prefKeyAuthType);
      if (authTypeStr == 'api') {
        _authType = AuthType.woocommerceApi;
      } else if (authTypeStr == 'jwt') {
        _authType = AuthType.jwt;
      } else {
        _authType = AuthType.wordpress;
      }

      // Carica l'URL del sito (prima dalle preferenze, poi dalla cache)
      final savedUrl = prefs.getString(_prefKeySiteUrl);
      _siteUrlController.text = savedUrl ?? loginCode.cachedSiteUrl ?? '';
    });
  }

  /// Salva le preferenze correnti
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Salva il tipo di autenticazione
    String authTypeStr;
    switch (_authType) {
      case AuthType.jwt:
        authTypeStr = 'jwt';
        break;
      case AuthType.woocommerceApi:
        authTypeStr = 'api';
        break;
      case AuthType.wordpress:
        authTypeStr = 'wordpress';
        break;
    }
    await prefs.setString(_prefKeyAuthType, authTypeStr);

    // Salva l'URL del sito
    await prefs.setString(_prefKeySiteUrl, _siteUrlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: context.spacing.iXL,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.loginAccediAlNegozio,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _siteUrlController,
                    decoration: InputDecoration(
                      labelText: context.l10n.loginUrlSito,
                      hintText: 'https://tuosito.com',
                      prefixIcon: const Icon(Icons.public),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      final correctedUrl = _autoCorrectUrl(value);
                      return UrlValidator.validateUrl(
                        correctedUrl,
                        allowLocalhost: _allowLocalhost,
                      );
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 8),

                  // Checkbox per connessioni locali
                  Row(
                    children: [
                      Checkbox(
                        value: _allowLocalhost,
                        onChanged: (value) =>
                            setState(() => _allowLocalhost = value ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _allowLocalhost = !_allowLocalhost,
                          ),
                          child: Text(
                            context.l10n.loginConsentiSviluppoLocale,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        onPressed: _showLocalhostInfo,
                        tooltip: context.l10n.loginTooltipSicurezza,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Pannello selezione METODO di login
                  _buildLoginMethodSelector(theme),

                  const SizedBox(height: 16),

                  // Pannello selezione tipo di autenticazione (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        borderRadius: context.shapes.s,
                      ),
                      padding: context.spacing.iL,
                      child: RadioGroup<AuthType>(
                        groupValue: _authType,
                        onChanged: (value) =>
                            setState(() => _authType = value ?? _authType),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.loginTipoAutenticazione,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RadioListTile<AuthType>(
                              title: Text(context.l10n.loginAutenticazioneWordpress),
                              subtitle: Text(context.l10n.loginUsaWpAdmin),
                              value: AuthType.wordpress,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<AuthType>(
                              title: Text(
                                context.l10n.loginAutenticazioneWoocommerce,
                              ),
                              subtitle: Text(context.l10n.loginUsaConsumerKey),
                              value: AuthType.woocommerceApi,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<AuthType>(
                              title: Text(context.l10n.loginAutenticazioneJwt),
                              subtitle: Text(context.l10n.loginUsaSimpleJwt),
                              value: AuthType.jwt,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Banner di avviso per connessioni locali
                  if (_allowLocalhost)
                    Container(
                      margin: EdgeInsets.only(bottom: context.spacing.l),
                      padding: context.spacing.iM,
                      decoration: BoxDecoration(
                        color: context.colors.warningColor.withValues(
                          alpha: 0.1,
                        ),
                        border: Border.all(
                          color: context.colors.warningColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        borderRadius: context.shapes.s,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: context.colors.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.loginAvvisoSviluppoLocale,
                              style: context.text.bodyLarge?.copyWith(
                                color: context.colors.warningColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Widget smartcard (se selezionato)
                  if (_loginMethod == LoginMethod.smartcard) ...[
                    SmartcardLoginWidget(
                      onLoginSuccess: () {
                        if (widget.onLoginSuccess != null) {
                          widget.onLoginSuccess!();
                        }
                      },
                    ),
                  ],

                  // Campi per WordPress Admin (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials &&
                      _authType == AuthType.wordpress) ...[
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginUsernameWordPress,
                        prefixIcon: const Icon(Icons.person),
                        hintText: context.l10n.loginHintWpAdmin,
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.loginValidatorUsernameWordpress
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginPasswordWordpress,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.loginValidatorPasswordWordpress
                          : null,
                    ),
                  ],

                  // Campi per WooCommerce API (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials &&
                      _authType == AuthType.woocommerceApi) ...[
                    TextFormField(
                      controller: _consumerKeyController,
                      decoration:  InputDecoration(
                        labelText: context.l10n.loginConsumerKey,
                        prefixIcon: const Icon(Icons.key),
                        hintText: 'ck_...',
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.loginValidatorConsumerKey
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _consumerSecretController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginConsumerSecret,
                        prefixIcon: const Icon(Icons.lock),
                        hintText: 'cs_...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.loginValidatorConsumerSecret
                          : null,
                    ),
                  ],

                  // Campi per JWT Authentication (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials &&
                      _authType == AuthType.jwt) ...[
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginUsername,
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.loginValidatorUsername
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginPassword,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Inserisci password'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Impostazioni avanzate (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials)
                    ExpansionTile(
                      title: Text(
                        context.l10n.loginImpostazioniAvanzate,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      leading: const Icon(Icons.settings, size: 20),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.l,
                            vertical: context.spacing.s,
                          ),
                          child: TextFormField(
                            controller: _jwtEndpointController,
                            decoration: InputDecoration(
                              labelText: context.l10n.loginEndpointJwtOpzionale,
                              hintText: 'simple-jwt-login/v1',
                              prefixIcon: const Icon(Icons.api),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Messaggio di successo
                  if (_successMessage != null)
                    Container(
                      margin: EdgeInsets.only(bottom: context.spacing.l),
                      padding: context.spacing.iM,
                      decoration: BoxDecoration(
                        color: context.colors.successColor.withValues(
                          alpha: 0.1,
                        ),
                        border: Border.all(
                          color: context.colors.successColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        borderRadius: context.shapes.s,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: context.colors.successColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: context.text.bodyLarge?.copyWith(
                                color: context.colors.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Messaggio di errore
                  if (_errorMessage != null)
                    Container(
                      margin: EdgeInsets.only(bottom: context.spacing.l),
                      padding: context.spacing.iM,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.3),
                        ),
                        borderRadius: context.shapes.s,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              _errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottone login (solo se credenziali standard)
                  if (_loginMethod == LoginMethod.credentials)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: context.spacing.vL,
                      ),
                      onPressed: _isLoading ? null : _submitLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.loginAccedi),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    // Corregge l'URL prima della validazione
    final correctedUrl = _autoCorrectUrl(_siteUrlController.text);
    _siteUrlController.text = correctedUrl ?? '';

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    // Le stringhe dei messaggi sono risolte prima degli await: dopo un await non
    // e garantito che il widget sia ancora montato, quindi non posso usare
    // context.l10n in quel punto.
    final l10n = context.l10n;

    try {
      if (_authType == AuthType.wordpress) {
        // Login con credenziali wp-admin (Application Passwords)
        await loginCode.performWpLogin(
          siteUrl: _siteUrlController.text,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } else if (_authType == AuthType.woocommerceApi) {
        // Login con WooCommerce API
        await loginCode.performApiLogin(
          siteUrl: _siteUrlController.text,
          consumerKey: _consumerKeyController.text.trim(),
          consumerSecret: _consumerSecretController.text.trim(),
        );
      } else {
        // Login con JWT
        await loginCode.performLogin(
          siteUrl: _siteUrlController.text,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          customJwtEndpoint: _jwtEndpointController.text.trim().isEmpty
              ? null
              : _jwtEndpointController.text.trim(),
        );
      }

      // Login riuscito - salva le preferenze
      await _savePreferences();

      setState(() {
        _successMessage = l10n.loginConnessioneRiuscita;
        _isLoading = false;
      });

      // Chiama il callback se fornito
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      if (_authType == AuthType.jwt || _authType == AuthType.wordpress) {
        _passwordController.clear();
      } else {
        _consumerSecretController.clear();
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.loginErroreSconosciuto;
        _isLoading = false;
      });
      if (_authType == AuthType.jwt || _authType == AuthType.wordpress) {
        _passwordController.clear();
      } else {
        _consumerSecretController.clear();
      }
    }
  }

  void _showLocalhostInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security),
            const SizedBox(width: 8),
            Text(context.l10n.loginSviluppoLocale),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(context.l10n.loginSviluppoLocaleAvviso),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.loginHoCapito),
          ),
        ],
      ),
    );
  }

  String? _autoCorrectUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    String corrected = url.trim();

    if (!corrected.startsWith('http')) {
      if (_allowLocalhost &&
          UrlValidator.isLocalOrReservedIp(corrected.split(':')[0])) {
        corrected = 'http://$corrected';
      } else {
        corrected = 'https://$corrected';
      }
    }
    return corrected;
  }

  /// Costruisce il selettore del metodo di login
  Widget _buildLoginMethodSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
        borderRadius: context.shapes.m,
      ),
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.login, color: theme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                context.l10n.loginMetodoAccesso,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Opzione credenziali standard
          InkWell(
            onTap: () => setState(() => _loginMethod = LoginMethod.credentials),
            borderRadius: context.shapes.s,
            child: Container(
              padding: context.spacing.iM,
              decoration: BoxDecoration(
                color: _loginMethod == LoginMethod.credentials
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: _loginMethod == LoginMethod.credentials
                      ? theme.primaryColor
                      : context.colors.subtitleColor.withValues(alpha: 0.3),
                  width: _loginMethod == LoginMethod.credentials ? 2 : 1,
                ),
                borderRadius: context.shapes.s,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.vpn_key,
                    color: _loginMethod == LoginMethod.credentials
                        ? theme.primaryColor
                        : context.colors.subtitleColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.loginCredenzialiStandard,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _loginMethod == LoginMethod.credentials
                                ? theme.primaryColor
                                : null,
                          ),
                        ),
                        Text(
                          context.l10n.loginCredenzialiStandardDescrizione,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colors.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loginMethod == LoginMethod.credentials)
                    Icon(Icons.check_circle, color: theme.primaryColor),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Opzione smartcard
          InkWell(
            onTap: () => setState(() => _loginMethod = LoginMethod.smartcard),
            borderRadius: context.shapes.s,
            child: Container(
              padding: context.spacing.iM,
              decoration: BoxDecoration(
                color: _loginMethod == LoginMethod.smartcard
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: _loginMethod == LoginMethod.smartcard
                      ? theme.primaryColor
                      : context.colors.subtitleColor.withValues(alpha: 0.3),
                  width: _loginMethod == LoginMethod.smartcard ? 2 : 1,
                ),
                borderRadius: context.shapes.s,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: _loginMethod == LoginMethod.smartcard
                        ? theme.primaryColor
                        : context.colors.subtitleColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.loginSmartcard,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _loginMethod == LoginMethod.smartcard
                                ? theme.primaryColor
                                : null,
                          ),
                        ),
                        Text(
                          context.l10n.loginSmartcardDescrizione,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colors.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loginMethod == LoginMethod.smartcard)
                    Icon(Icons.check_circle, color: theme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _siteUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _jwtEndpointController.dispose();
    _consumerKeyController.dispose();
    _consumerSecretController.dispose();
    super.dispose();
  }
}
