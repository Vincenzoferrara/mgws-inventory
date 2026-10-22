import 'package:flutter/material.dart';
import '../notification/notification_service.dart';
import 'package:dio/dio.dart';
import '../login/jwt_api/jwt_connect.dart';
import '../l10n/extensions.dart';

class WooCommerceCustomFields {
  final JwtConnect _jwtConnect = JwtConnect();

  /// Ottiene la lista dei campi personalizzati supportati
  Future<List<CustomField>> getSupportedFields() async {
    try {
      final dio = _jwtConnect.getAuthenticatedDio();
      final response = await dio.get('/wc-custom-fields/v1/supported-fields');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((field) => CustomField.fromJson(field)).toList();
      } else {
        throw Exception(
          'Errore nel caricamento dei campi: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Errore API: ${e.message}');
    } catch (e) {
      throw Exception('Errore di connessione: $e');
    }
  }

  /// Ottiene i campi personalizzati di un prodotto
  Future<Map<String, String>> getProductCustomFields(int productId) async {
    try {
      final dio = _jwtConnect.getAuthenticatedDio();
      final response = await dio.get('/wc/v3/products/$productId');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final Map<String, dynamic> customFields = data['custom_fields'] ?? {};
        return customFields.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } else {
        throw Exception(
          'Errore nel caricamento dei campi del prodotto: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Errore API: ${e.message}');
    } catch (e) {
      throw Exception('Errore di connessione: $e');
    }
  }

  /// Aggiorna i campi personalizzati di un prodotto
  Future<bool> updateProductCustomFields(
    int productId,
    Map<String, String> customFields,
  ) async {
    try {
      final dio = _jwtConnect.getAuthenticatedDio();
      final response = await dio.put(
        '/wc/v3/products/$productId',
        data: {'custom_fields': customFields},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Errore API: ${e.message}');
    } catch (e) {
      throw Exception('Errore nell\'aggiornamento dei campi: $e');
    }
  }

  /// Crea un nuovo prodotto con campi personalizzati
  Future<int> createProductWithCustomFields({
    required String name,
    required String price,
    required Map<String, String> customFields,
  }) async {
    try {
      final dio = _jwtConnect.getAuthenticatedDio();
      final response = await dio.post(
        '/wc/v3/products',
        data: {
          'name': name,
          'regular_price': price,
          'custom_fields': customFields,
        },
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = response.data;
        return data['id'];
      } else {
        throw Exception(
          'Errore nella creazione del prodotto: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Errore API: ${e.message}');
    } catch (e) {
      throw Exception('Errore di connessione: $e');
    }
  }

  /// Aggiunge dinamicamente nuovi campi personalizzati al plugin
  Future<bool> addCustomField({
    required String name,
    required String label,
    String type = 'text',
    String? placeholder,
    String? description,
  }) async {
    try {
      final dio = _jwtConnect.getAuthenticatedDio();
      final response = await dio.post(
        '/wc-custom-fields/v1/add-field',
        data: {
          'name': name,
          'label': label,
          'type': type,
          'placeholder': placeholder ?? '',
          'description': description ?? '',
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Errore API: ${e.message}');
    } catch (e) {
      throw Exception('Errore nell\'aggiunta del campo: $e');
    }
  }
}

class CustomField {
  final String name;
  final String label;
  final String type;
  final String placeholder;
  final String description;

  CustomField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.description,
  });

  factory CustomField.fromJson(Map<String, dynamic> json) {
    return CustomField(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      type: json['type'] ?? 'text',
      placeholder: json['placeholder'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'label': label,
      'type': type,
      'placeholder': placeholder,
      'description': description,
    };
  }
}

/// Widget per la gestione dei campi personalizzati
class CustomFieldsWidget extends StatefulWidget {
  final List<CustomField> fields;
  final Map<String, String> initialValues;
  final Function(Map<String, String>) onChanged;

  const CustomFieldsWidget({
    super.key,
    required this.fields,
    required this.initialValues,
    required this.onChanged,
  });

  @override
  State<CustomFieldsWidget> createState() => _CustomFieldsWidgetState();
}

class _CustomFieldsWidgetState extends State<CustomFieldsWidget> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (var field in widget.fields) {
      _controllers[field.name] = TextEditingController(
        text: widget.initialValues[field.name] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.fields.map((field) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            controller: _controllers[field.name],
            decoration: InputDecoration(
              labelText: field.label,
              hintText: field.placeholder,
              helperText: field.description,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final updatedValues = <String, String>{};
              for (var entry in _controllers.entries) {
                updatedValues[entry.key] = entry.value.text;
              }
              widget.onChanged(updatedValues);
            },
          ),
        );
      }).toList(),
    );
  }
}

/// Esempio di utilizzo in una pagina prodotto
class ProductCustomFieldsPage extends StatefulWidget {
  final int productId;

  const ProductCustomFieldsPage({super.key, required this.productId});

  @override
  State<ProductCustomFieldsPage> createState() =>
      _ProductCustomFieldsPageState();
}

class _ProductCustomFieldsPageState extends State<ProductCustomFieldsPage> {
  final WooCommerceCustomFields _wooService = WooCommerceCustomFields();

  List<CustomField> _supportedFields = [];
  Map<String, String> _customFields = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supportedFields = await _wooService.getSupportedFields();
      final productFields = await _wooService.getProductCustomFields(
        widget.productId,
      );

      if (mounted) {
        setState(() {
          _supportedFields = supportedFields;
          _customFields = productFields;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationService.instance.messageBar(
          'errore',
          'woocommerce_custom_fields',
          'Errore: $e',
        );
      }
    }
  }

  Future<void> _saveFields() async {
    try {
      final success = await _wooService.updateProductCustomFields(
        widget.productId,
        _customFields,
      );

      if (mounted && success) {
        NotificationService.instance.messageBar(
          'successo',
          'woocommerce_custom_fields',
          'Campi salvati con successo',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.messageBar(
          'errore',
          'woocommerce_custom_fields',
          'Errore nel salvataggio: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.wooCampiPersonalizzati),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveFields),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomFieldsWidget(
                fields: _supportedFields,
                initialValues: _customFields,
                onChanged: (values) {
                  if (mounted) {
                    setState(() {
                      _customFields = values;
                    });
                  }
                },
              ),
            ),
    );
  }
}
