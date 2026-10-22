import 'package:flutter/material.dart';
import '../notification/notification_service.dart';
import 'package:provider/provider.dart';
import 'app_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

/// Tab per le impostazioni dell'Intelligenza Artificiale
class AISettingsTab extends StatefulWidget {
  const AISettingsTab({super.key});

  @override
  State<AISettingsTab> createState() => _AISettingsTabState();
}

class _AISettingsTabState extends State<AISettingsTab> {
  final _formKey = GlobalKey<FormState>();

  // Controller per i token API
  final _openAIController = TextEditingController();
  final _anthropicController = TextEditingController();
  final _googleAIController = TextEditingController();
  final _mistralController = TextEditingController();
  final _cohereController = TextEditingController();
  final _ollamaController = TextEditingController();

  // Modelli selezionati
  String _selectedOpenAIModel = 'gpt-4o-mini';
  String _selectedAnthropicModel = 'claude-3-5-sonnet-20241022';
  String _selectedGoogleModel = 'gemini-1.5-flash';
  String _selectedMistralModel = 'mistral-small-latest';
  String _selectedOllamaModel = 'llama3.2';

  // Provider attivo
  String _activeProvider = 'openai';

  // Liste modelli disponibili
  final List<String> _openAIModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-3.5-turbo',
  ];

  final List<String> _anthropicModels = [
    'claude-3-5-sonnet-20241022',
    'claude-3-opus-20240229',
    'claude-3-sonnet-20240229',
    'claude-3-haiku-20240307',
  ];

  final List<String> _googleModels = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-1.0-pro',
  ];

  final List<String> _mistralModels = [
    'mistral-small-latest',
    'mistral-medium-latest',
    'mistral-large-latest',
    'open-mistral-7b',
    'open-mixtral-8x7b',
  ];

  final List<String> _ollamaModels = [
    'llama3.2',
    'llama3.1',
    'llama3',
    'llama2',
    'mistral',
    'mixtral',
    'phi3',
    'gemma2',
    'qwen2',
    'codellama',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = context.read<AppSettings>();
    _openAIController.text = await settings.getAiToken('ai_openai_token') ?? '';
    _anthropicController.text =
        await settings.getAiToken('ai_anthropic_token') ?? '';
    _googleAIController.text =
        await settings.getAiToken('ai_google_token') ?? '';
    _mistralController.text =
        await settings.getAiToken('ai_mistral_token') ?? '';
    _cohereController.text = await settings.getAiToken('ai_cohere_token') ?? '';
    _ollamaController.text = await settings.getAiToken('ai_ollama_url') ?? '';

    // Carica modelli selezionati
    _selectedOpenAIModel =
        await settings.getAiToken('ai_openai_model') ?? 'gpt-4o-mini';
    _selectedAnthropicModel =
        await settings.getAiToken('ai_anthropic_model') ??
        'claude-3-5-sonnet-20241022';
    _selectedGoogleModel =
        await settings.getAiToken('ai_google_model') ?? 'gemini-1.5-flash';
    _selectedMistralModel =
        await settings.getAiToken('ai_mistral_model') ?? 'mistral-small-latest';
    _selectedOllamaModel =
        await settings.getAiToken('ai_ollama_model') ?? 'llama3.2';
    _activeProvider =
        await settings.getAiToken('ai_active_provider') ?? 'openai';

    setState(() {});
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final settings = context.read<AppSettings>();

      // Salva token
      await settings.setAiToken(
        'ai_openai_token',
        _openAIController.text.trim(),
      );
      await settings.setAiToken(
        'ai_anthropic_token',
        _anthropicController.text.trim(),
      );
      await settings.setAiToken(
        'ai_google_token',
        _googleAIController.text.trim(),
      );
      await settings.setAiToken(
        'ai_mistral_token',
        _mistralController.text.trim(),
      );
      await settings.setAiToken(
        'ai_cohere_token',
        _cohereController.text.trim(),
      );
      await settings.setAiToken('ai_ollama_url', _ollamaController.text.trim());

      // Salva modelli selezionati
      await settings.setAiToken('ai_openai_model', _selectedOpenAIModel);
      await settings.setAiToken('ai_anthropic_model', _selectedAnthropicModel);
      await settings.setAiToken('ai_google_model', _selectedGoogleModel);
      await settings.setAiToken('ai_mistral_model', _selectedMistralModel);
      await settings.setAiToken('ai_ollama_model', _selectedOllamaModel);
      await settings.setAiToken('ai_active_provider', _activeProvider);

      if (mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'ai_settings',
          context.l10n.settingsAiSaved,
        );
      }
    }
  }

  @override
  void dispose() {
    _openAIController.dispose();
    _anthropicController.dispose();
    _googleAIController.dispose();
    _mistralController.dispose();
    _cohereController.dispose();
    _ollamaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.settingsAiTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.settingsAiDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.colors.subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Avviso privacy: i provider cloud ricevono i dati dei prodotti
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.l10n.settingsAiPrivacyTitle),
                subtitle: Text(context.l10n.settingsAiPrivacyBody),
              ),
            ),
            const SizedBox(height: 24),

            // Selezione provider attivo
            Card(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsAiActiveProvider,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _activeProvider,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ollama',
                          child: Text(context.l10n.settingsAiProviderOllama),
                        ),
                        const DropdownMenuItem(
                          value: 'openai',
                          child: Text('OpenAI'),
                        ),
                        const DropdownMenuItem(
                          value: 'anthropic',
                          child: Text('Anthropic (Claude)'),
                        ),
                        const DropdownMenuItem(
                          value: 'google',
                          child: Text('Google AI (Gemini)'),
                        ),
                        const DropdownMenuItem(
                          value: 'mistral',
                          child: Text('Mistral AI'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _activeProvider = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ollama (locale)
            _buildProviderCard(
              label: context.l10n.settingsAiProviderOllama,
              hint: 'http://localhost:11434',
              controller: _ollamaController,
              icon: Icons.computer,
              color: context.colors.neutralColor,
              models: _ollamaModels,
              selectedModel: _selectedOllamaModel,
              onModelChanged: (model) =>
                  setState(() => _selectedOllamaModel = model),
              isUrl: true,
            ),
            const SizedBox(height: 16),

            // OpenAI
            _buildProviderCard(
              label: 'OpenAI',
              hint: 'sk-...',
              controller: _openAIController,
              icon: Icons.auto_awesome,
              color: context.colors.successColor,
              models: _openAIModels,
              selectedModel: _selectedOpenAIModel,
              onModelChanged: (model) =>
                  setState(() => _selectedOpenAIModel = model),
            ),
            const SizedBox(height: 16),

            // Anthropic (Claude)
            _buildProviderCard(
              label: 'Anthropic (Claude)',
              hint: 'sk-ant-...',
              controller: _anthropicController,
              icon: Icons.smart_toy,
              color: context.colors.warningColor,
              models: _anthropicModels,
              selectedModel: _selectedAnthropicModel,
              onModelChanged: (model) =>
                  setState(() => _selectedAnthropicModel = model),
            ),
            const SizedBox(height: 16),

            // Google AI (Gemini)
            _buildProviderCard(
              label: 'Google AI (Gemini)',
              hint: 'AIza...',
              controller: _googleAIController,
              icon: Icons.diamond,
              color: context.colors.infoColor,
              models: _googleModels,
              selectedModel: _selectedGoogleModel,
              onModelChanged: (model) =>
                  setState(() => _selectedGoogleModel = model),
            ),
            const SizedBox(height: 16),

            // Mistral AI
            _buildProviderCard(
              label: 'Mistral AI',
              hint: context.l10n.settingsAiMistralHint,
              controller: _mistralController,
              icon: Icons.air,
              color: context.colors.infoColor,
              models: _mistralModels,
              selectedModel: _selectedMistralModel,
              onModelChanged: (model) =>
                  setState(() => _selectedMistralModel = model),
            ),

            const SizedBox(height: 32),

            // Pulsante Salva
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: Text(context.l10n.settingsAiSaveButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Note informative
            Card(
              color: context.colors.warningColor.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.colors.warningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.settingsAiSecurityNote,
                        style: TextStyle(
                          color: context.colors.warningColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required List<String> models,
    required String selectedModel,
    required Function(String) onModelChanged,
    bool isUrl = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Campo token/URL
            TextFormField(
              controller: controller,
              obscureText: !isUrl,
              decoration: InputDecoration(
                hintText: hint,
                labelText: isUrl
                    ? context.l10n.settingsAiUrlLabel
                    : context.l10n.settingsAiTokenLabel,
                border: const OutlineInputBorder(),
                suffixIcon: !isUrl
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditTokenDialog(controller, label),
                        tooltip: context.l10n.settingsAiEditTokenTooltip,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // Selezione modello
            DropdownButtonFormField<String>(
              initialValue: models.contains(selectedModel)
                  ? selectedModel
                  : models.first,
              decoration: InputDecoration(
                labelText: context.l10n.settingsAiModelLabel,
                border: const OutlineInputBorder(),
              ),
              items: models
                  .map(
                    (model) =>
                        DropdownMenuItem(value: model, child: Text(model)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onModelChanged(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTokenDialog(
    TextEditingController controller,
    String label,
  ) async {
    final editController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settingsAiTokenDialogTitle(label)),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.settingsAiTokenDialogHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, editController.text),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      controller.text = result;
      setState(() {});
    }
    editController.dispose();
  }
}
