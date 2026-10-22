import 'package:dart_openai/dart_openai.dart';
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import '../settings/app_settings.dart';

/// Provider IA disponibili
enum AIProvider { openai, anthropic, google, mistral, cohere, ollama }

/// Il provider IA selezionato non ha un token configurato.
///
/// Il messaggio per l'utente lo traduce il livello UI
/// (`aiProviderNotConfigured`).
class AiProviderNotConfiguredException implements Exception {
  final String provider;

  const AiProviderNotConfiguredException(this.provider);

  @override
  String toString() => 'AI provider "$provider" is not configured';
}

/// Il provider IA selezionato non è ancora implementato
/// (`aiProviderNotImplemented` nel livello UI).
class AiProviderNotImplementedException implements Exception {
  final String provider;

  const AiProviderNotImplementedException(this.provider);

  @override
  String toString() => 'AI provider "$provider" is not implemented yet';
}

/// Servizio centrale per le funzionalità IA
class AIService {
  final AppSettings _settings;

  AIService(this._settings);

  /// Genera descrizione prodotto
  Future<String> generateProductDescription({
    required String productName,
    String? category,
    String? price,
    String? barcodeInterno,
    bool shortDescription = false,
  }) async {
    final prompt = _buildDescriptionPrompt(
      productName: productName,
      category: category,
      price: price,
      barcodeInterno: barcodeInterno,
      shortDescription: shortDescription,
    );

    return await _callAI(prompt);
  }

  /// Suggerisce categorie per un prodotto
  Future<List<String>> suggestCategories({
    required String productName,
    String? description,
  }) async {
    final prompt =
        '''
Sei un esperto di e-commerce per negozi di abbigliamento.
Suggerisci 3-5 categorie appropriate per questo prodotto:

Nome prodotto: $productName
${description != null ? 'Descrizione: $description' : ''}

Rispondi SOLO con le categorie, una per riga, senza numerazione o punteggiatura.
Esempio:
Magliette
T-Shirt
Abbigliamento Casual
Top
''';

    final response = await _callAI(prompt);
    return response
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Suggerisce tag per un prodotto
  Future<List<String>> suggestTags({
    required String productName,
    String? description,
    String? category,
  }) async {
    final prompt =
        '''
Sei un esperto SEO per e-commerce di abbigliamento.
Suggerisci 5-8 tag per migliorare la ricerca di questo prodotto:

Nome prodotto: $productName
${category != null ? 'Categoria: $category' : ''}
${description != null ? 'Descrizione: $description' : ''}

Rispondi SOLO con i tag, uno per riga, senza hashtag o punteggiatura.
I tag devono essere parole chiave singole o brevi frasi.
Esempio:
cotone
estate 2024
casual
uomo
manica corta
''';

    final response = await _callAI(prompt);
    return response
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Costruisce il prompt per la descrizione
  String _buildDescriptionPrompt({
    required String productName,
    String? category,
    String? price,
    String? barcodeInterno,
    required bool shortDescription,
  }) {
    if (shortDescription) {
      return '''
Sei un copywriter esperto per e-commerce di abbigliamento.
Scrivi una descrizione breve e accattivante (max 150 caratteri) per questo prodotto:

Nome: $productName
${category != null ? 'Categoria: $category' : ''}
${price != null ? 'Prezzo: €$price' : ''}

La descrizione deve essere:
- Breve e diretta
- SEO-friendly
- Evidenziare il benefit principale
- In italiano

Rispondi SOLO con la descrizione, senza virgolette.
''';
    } else {
      return '''
Sei un copywriter esperto per e-commerce di abbigliamento.
Scrivi una descrizione completa e dettagliata per questo prodotto:

Nome: $productName
${category != null ? 'Categoria: $category' : ''}
${price != null ? 'Prezzo: €$price' : ''}
${barcodeInterno != null ? 'Barcode interno: $barcodeInterno' : ''}

La descrizione deve:
- Essere di 100-200 parole
- Descrivere materiali, vestibilità, occasioni d'uso
- Usare un tono professionale ma accattivante
- Includere parole chiave per SEO
- Essere in italiano

Rispondi SOLO con la descrizione, senza virgolette o intestazioni.
''';
    }
  }

  /// Chiama il provider IA configurato
  Future<String> _callAI(String prompt) async {
    // Leggi il provider attivo dalle impostazioni
    final activeProvider =
        await _settings.getAiToken('ai_active_provider') ?? 'openai';

    String? token;
    String? model;

    switch (activeProvider) {
      case 'ollama':
        token = await _settings.getAiToken('ai_ollama_url');
        model = await _settings.getAiToken('ai_ollama_model') ?? 'llama3.2';
        if (token != null && token.isNotEmpty) {
          return await _callOllama(token, prompt, model);
        }
        break;
      case 'anthropic':
        token = await _settings.getAiToken('ai_anthropic_token');
        model =
            await _settings.getAiToken('ai_anthropic_model') ??
            'claude-3-5-sonnet-20241022';
        if (token != null && token.isNotEmpty) {
          return await _callAnthropic(token, prompt, model);
        }
        break;
      case 'openai':
        token = await _settings.getAiToken('ai_openai_token');
        model = await _settings.getAiToken('ai_openai_model') ?? 'gpt-4o-mini';
        if (token != null && token.isNotEmpty) {
          return await _callOpenAI(token, prompt, model);
        }
        break;
      case 'google':
        token = await _settings.getAiToken('ai_google_token');
        model =
            await _settings.getAiToken('ai_google_model') ?? 'gemini-1.5-flash';
        if (token != null && token.isNotEmpty) {
          return await _callGoogle(token, prompt, model);
        }
        break;
      case 'mistral':
        token = await _settings.getAiToken('ai_mistral_token');
        model =
            await _settings.getAiToken('ai_mistral_model') ??
            'mistral-small-latest';
        if (token != null && token.isNotEmpty) {
          return await _callMistral(token, prompt, model);
        }
        break;
    }

    throw AiProviderNotConfiguredException(activeProvider);
  }

  /// Chiama Ollama (locale)
  Future<String> _callOllama(
    String baseUrl,
    String prompt,
    String model,
  ) async {
    final client = ollama.OllamaClient.withBaseUrl(baseUrl);

    final response = await client.completions.generate(
      request: ollama.GenerateRequest(model: model, prompt: prompt),
    );

    client.close();
    return response.response ?? '';
  }

  /// Chiama Anthropic (Claude)
  Future<String> _callAnthropic(
    String token,
    String prompt,
    String model,
  ) async {
    final client = anthropic.AnthropicClient.withApiKey(token);

    final response = await client.messages.create(
      anthropic.MessageCreateRequest(
        model: model,
        maxTokens: 1024,
        messages: [anthropic.InputMessage.user(prompt)],
      ),
    );

    client.close();
    return response.text;
  }

  /// Chiama OpenAI
  Future<String> _callOpenAI(String token, String prompt, String model) async {
    OpenAI.apiKey = token;

    final response = await OpenAI.instance.chat.create(
      model: model,
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          ],
        ),
      ],
    );

    return response.choices.first.message.content?.first.text ?? '';
  }

  /// Chiama Google AI (Gemini)
  Future<String> _callGoogle(String token, String prompt, String model) async {
    final generativeModel = GenerativeModel(model: model, apiKey: token);

    final response = await generativeModel.generateContent([
      Content.text(prompt),
    ]);
    return response.text ?? '';
  }

  /// Chiama Mistral AI
  Future<String> _callMistral(String token, String prompt, String model) async {
    // Mistral usa API compatibile con OpenAI
    // Per ora usa dart_openai con base URL diverso
    // TODO: implementare con mistralai_dart quando supporterà meglio
    throw const AiProviderNotImplementedException('Mistral AI');
  }
}
