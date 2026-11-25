import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../log_viewer/app_logger.dart';

/// Tipi di smartcard supportati
enum CardType {
  nfc, // NFC tag (NTAG, MIFARE, etc.)
  usb, // Lettore USB
  rfid, // RFID contactless
}

/// Dati salvati sulla smartcard
class SmartcardData {
  final String siteUrl;
  final String username;
  final String password;
  final String? customJwtEndpoint;
  final DateTime createdAt;

  SmartcardData({
    required this.siteUrl,
    required this.username,
    required this.password,
    this.customJwtEndpoint,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'site_url': siteUrl,
    'username': username,
    'password': password,
    'custom_endpoint': customJwtEndpoint,
    'created_at': createdAt.toIso8601String(),
  };

  factory SmartcardData.fromJson(Map<String, dynamic> json) {
    return SmartcardData(
      siteUrl: json['site_url'],
      username: json['username'],
      password: json['password'],
      customJwtEndpoint: json['custom_endpoint'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// Converte i dati in stringa cifrata (AES-256).
  ///
  /// Il prefisso `aes:` distingue il formato cifrato dal vecchio formato
  /// base64 (ancora leggibile per compatibilita' con card scritte in
  /// precedenza, ma mai piu' prodotto).
  String toEncryptedString() {
    final jsonString = jsonEncode(toJson());
    final seed = 'smartcard_encryption_key_mgws_inventory';
    final keyBytes = sha256.convert(utf8.encode(seed)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    return 'aes:${iv.base64}:${encrypted.base64}';
  }

  /// Decodifica una stringa cifrata (AES) o, in fallback, base64 legacy.
  static SmartcardData fromEncryptedString(String encrypted) {
    // Valida l'URL prima di decodificare: nessun bypass su HTTP non sicuro.
    String? siteUrl;
    try {
      if (encrypted.startsWith('aes:')) {
        final parts = encrypted.split(':');
        // aes:<iv>:<payload> (il payload base64 non contiene ':')
        if (parts.length < 3) throw const FormatException('formato aes non valido');
        final iv = encrypt.IV.fromBase64(parts[1]);
        final payload = parts.sublist(2).join(':');
        final seed = 'smartcard_encryption_key_mgws_inventory';
        final keyBytes = sha256.convert(utf8.encode(seed)).bytes;
        final key = encrypt.Key(Uint8List.fromList(keyBytes));
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final jsonString = encrypter.decrypt64(payload, iv: iv);
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        siteUrl = json['site_url']?.toString();
        _validateSiteUrl(siteUrl);
        return SmartcardData.fromJson(json);
      }
      // Fallback legacy base64 (card scritte prima della cifratura reale).
      final bytes = base64Decode(encrypted);
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      siteUrl = json['site_url']?.toString();
      _validateSiteUrl(siteUrl);
      return SmartcardData.fromJson(json);
    } catch (e) {
      throw FormatException('Impossibile decodificare i dati smartcard: $e');
    }
  }

  /// Rifiuta URL non sicuri (HTTP su host non locale) per evitare bypass.
  static void _validateSiteUrl(String? siteUrl) {
    if (siteUrl == null || siteUrl.isEmpty) {
      throw const FormatException('site_url mancante');
    }
    final uri = Uri.tryParse(siteUrl);
    if (uri == null || !uri.isAbsolute) {
      throw const FormatException('site_url non valido');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      throw const FormatException('schema non supportato');
    }
    if (scheme == 'http') {
      final host = uri.host.toLowerCase();
      final isLocal = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1';
      if (!isLocal) {
        throw const FormatException('HTTP consentito solo su localhost');
      }
    }
  }
}

/// Servizio per gestire l'autenticazione tramite smartcard
///
/// Supporta:
/// - NFC (Android/iOS)
/// - Lettori USB (Desktop/Android con OTG)
/// - RFID contactless
///
/// NOTA: Per usare questo servizio aggiungi al pubspec.yaml:
/// - nfc_manager: ^3.5.0  (per NFC)
/// - usb_serial: ^0.5.0    (per lettori USB)
class SmartcardService {
  static final SmartcardService _instance = SmartcardService._internal();
  factory SmartcardService() => _instance;
  SmartcardService._internal();

  final log = AppLogger();

  /// Verifica se il dispositivo supporta NFC
  Future<bool> isNfcAvailable() async {
    try {
      // Implementazione con nfc_manager
      // Decommenta quando aggiungi nfc_manager al pubspec.yaml
      /*
      final isAvailable = await NfcManager.instance.isAvailable();
      return isAvailable;
      */

      // Per test: simula disponibilità su Android/iOS
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        log.i('NFC potenzialmente disponibile su questo dispositivo');
        // Ritorna true per permettere test, ma senza package reale non funzionerà
        return false; // Cambia in true quando aggiungi nfc_manager
      }

      log.w('NFC non supportato su questa piattaforma');
      return false;
    } catch (e) {
      log.e('Error checking NFC availability', e);
      return false;
    }
  }

  /// Verifica se c'è un lettore USB connesso
  Future<bool> isUsbReaderAvailable() async {
    try {
      // Implementazione con usb_serial
      // Decommenta quando aggiungi usb_serial al pubspec.yaml
      /*
      final devices = await UsbSerial.listDevices();
      return devices.isNotEmpty;
      */

      // Per test: simula disponibilità su Android con OTG o Desktop
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        log.i('Lettore USB potenzialmente disponibile su questa piattaforma');
        return false; // Cambia in true quando aggiungi usb_serial
      }

      log.w('Lettori USB non supportati su questa piattaforma');
      return false;
    } catch (e) {
      log.e('Error checking USB reader', e);
      return false;
    }
  }

  /// Scrive le credenziali su smartcard NFC
  Future<bool> writeToNfcCard(SmartcardData data) async {
    try {
      log.i('Writing credentials to NFC card...');

      // IMPLEMENTAZIONE COMPLETA con nfc_manager
      // Aggiungi al pubspec.yaml: nfc_manager: ^3.5.0
      // Poi decommenta questo blocco:
      /*
      import 'package:nfc_manager/nfc_manager.dart';

      bool success = false;
      String? errorMsg;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              errorMsg = 'Card non supporta NDEF';
              return;
            }

            if (!ndef.isWritable) {
              errorMsg = 'Card protetta da scrittura';
              return;
            }

            // Verifica spazio disponibile
            final dataString = data.toEncryptedString();
            final dataBytes = utf8.encode(dataString);

            if (ndef.maxSize < dataBytes.length) {
              errorMsg = 'Dati troppo grandi per questa card (${dataBytes.length} bytes, max ${ndef.maxSize})';
              return;
            }

            // Crea messaggio NDEF con i dati cifrati
            final message = NdefMessage([
              NdefRecord.createText(dataString),
            ]);

            // Scrivi sulla card
            await ndef.write(message);
            log.i('✅ Credenziali scritte su NFC card (${dataBytes.length} bytes)');
            success = true;
          } catch (e) {
            errorMsg = e.toString();
            log.e('Error writing to NFC card', e);
          } finally {
            await NfcManager.instance.stopSession(errorMessage: errorMsg);
          }
        },
      );

      return success;
      */

      log.w(
        'NFC write non implementato - aggiungi nfc_manager: ^3.5.0 al pubspec.yaml',
      );
      return false;
    } catch (e) {
      log.e('Error writing to NFC card', e);
      return false;
    }
  }

  /// Legge le credenziali da smartcard NFC
  Future<SmartcardData?> readFromNfcCard() async {
    try {
      log.i('Reading credentials from NFC card...');

      // IMPLEMENTAZIONE COMPLETA con nfc_manager
      // Aggiungi al pubspec.yaml: nfc_manager: ^3.5.0
      // Poi decommenta questo blocco:
      /*
      import 'package:nfc_manager/nfc_manager.dart';

      SmartcardData? result;
      String? errorMsg;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              errorMsg = 'Card non NDEF formattata';
              return;
            }

            // Leggi il messaggio NDEF
            final message = await ndef.read();
            if (message.records.isEmpty) {
              errorMsg = 'Nessun dato sulla card';
              return;
            }

            // Estrai il payload del primo record
            final record = message.records.first;

            // Il payload di un text record ha:
            // - Byte 0: status byte (encoding + language code length)
            // - Bytes 1-N: language code
            // - Bytes N+1-end: text data
            final languageCodeLength = record.payload[0] & 0x3F;
            final textBytes = record.payload.sublist(1 + languageCodeLength);
            final dataString = utf8.decode(textBytes);

            // Decodifica i dati
            result = SmartcardData.fromEncryptedString(dataString);
            log.i('✅ Credenziali lette da NFC card');
          } catch (e) {
            errorMsg = e.toString();
            log.e('Error reading from NFC card', e);
          } finally {
            await NfcManager.instance.stopSession(errorMessage: errorMsg);
          }
        },
      );

      return result;
      */

      log.w(
        'NFC read non implementato - aggiungi nfc_manager: ^3.5.0 al pubspec.yaml',
      );
      return null;
    } catch (e) {
      log.e('Error reading from NFC card', e);
      return null;
    }
  }

  /// Scrive le credenziali su smartcard USB
  Future<bool> writeToUsbCard(SmartcardData data) async {
    try {
      log.i('Writing credentials to USB smartcard...');

      // IMPLEMENTAZIONE COMPLETA con usb_serial
      // Aggiungi al pubspec.yaml: usb_serial: ^0.6.0
      // Poi decommenta questo blocco:
      /*
      import 'package:usb_serial/usb_serial.dart';
      import 'dart:typed_data';

      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        log.e('Nessun lettore USB trovato');
        return false;
      }

      log.d('Trovati ${devices.length} dispositivi USB');

      // Prova il primo dispositivo (puoi espandere per supportare più reader)
      final device = devices.first;
      final port = await device.create();

      if (port == null) {
        log.e('Impossibile creare porta USB');
        return false;
      }

      // Apri la porta
      final opened = await port.open();
      if (!opened) {
        log.e('Impossibile aprire porta USB');
        return false;
      }

      // Configura la porta seriale
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        9600, // Baud rate
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Prepara i dati: comando WRITE + lunghezza + dati cifrati
      final dataString = data.toEncryptedString();
      final dataBytes = utf8.encode(dataString);

      // Protocollo semplice: [CMD][LEN_H][LEN_L][DATA...]
      final command = Uint8List.fromList([
        0x02, // CMD: WRITE
        (dataBytes.length >> 8) & 0xFF, // Length high byte
        dataBytes.length & 0xFF, // Length low byte
        ...dataBytes,
      ]);

      // Invia al lettore
      await port.write(command);
      log.d('Inviati ${command.length} bytes al lettore USB');

      // Attendi risposta (timeout 5 secondi)
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await port.read();

      await port.close();

      // Verifica risposta (ACK = 0x06)
      if (response.isNotEmpty && response[0] == 0x06) {
        log.i('✅ Credenziali scritte su USB smartcard');
        return true;
      }

      log.e('Scrittura fallita o nessuna risposta dal lettore');
      return false;
      */

      log.w(
        'USB write non implementato - aggiungi usb_serial: ^0.6.0 al pubspec.yaml',
      );
      return false;
    } catch (e) {
      log.e('Error writing to USB smartcard', e);
      return false;
    }
  }

  /// Legge le credenziali da smartcard USB
  Future<SmartcardData?> readFromUsbCard() async {
    try {
      log.i('Reading credentials from USB smartcard...');

      // IMPLEMENTAZIONE COMPLETA con usb_serial
      // Aggiungi al pubspec.yaml: usb_serial: ^0.6.0
      // Poi decommenta questo blocco:
      /*
      import 'package:usb_serial/usb_serial.dart';
      import 'dart:typed_data';

      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        log.e('Nessun lettore USB trovato');
        return null;
      }

      final device = devices.first;
      final port = await device.create();

      if (port == null) {
        log.e('Impossibile creare porta USB');
        return null;
      }

      final opened = await port.open();
      if (!opened) {
        log.e('Impossibile aprire porta USB');
        return null;
      }

      // Configura la porta
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Invia comando READ
      final command = Uint8List.fromList([0x01]); // CMD: READ
      await port.write(command);

      // Attendi e leggi risposta
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await port.read();

      await port.close();

      if (response.isEmpty) {
        log.e('Nessuna risposta dal lettore');
        return null;
      }

      // Protocollo: [STATUS][LEN_H][LEN_L][DATA...]
      if (response[0] != 0x06) { // ACK
        log.e('Errore nella lettura: ${response[0]}');
        return null;
      }

      final length = (response[1] << 8) | response[2];
      final dataBytes = response.sublist(3, 3 + length);
      final dataString = utf8.decode(dataBytes);

      // Decodifica i dati
      final result = SmartcardData.fromEncryptedString(dataString);
      log.i('✅ Credenziali lette da USB smartcard');
      return result;
      */

      log.w(
        'USB read non implementato - aggiungi usb_serial: ^0.6.0 al pubspec.yaml',
      );
      return null;
    } catch (e) {
      log.e('Error reading from USB smartcard', e);
      return null;
    }
  }

  /// Legge automaticamente da qualsiasi tipo di smartcard disponibile
  Future<SmartcardData?> readFromAnyCard() async {
    log.i('Trying to read from any available smartcard...');

    // Prova prima NFC (più comune su mobile)
    if (await isNfcAvailable()) {
      final data = await readFromNfcCard();
      if (data != null) return data;
    }

    // Poi prova USB (common su desktop)
    if (await isUsbReaderAvailable()) {
      final data = await readFromUsbCard();
      if (data != null) return data;
    }

    log.w('No smartcard data found');
    return null;
  }

  /// Formatta una smartcard (cancella tutti i dati)
  Future<bool> formatCard(CardType type) async {
    try {
      log.i('Formatting $type card...');

      switch (type) {
        case CardType.nfc:
          // Scrivi messaggio NDEF vuoto per formattare la card
          /*
          import 'package:nfc_manager/nfc_manager.dart';

          bool success = false;
          await NfcManager.instance.startSession(
            onDiscovered: (NfcTag tag) async {
              try {
                final ndef = Ndef.from(tag);
                if (ndef != null && ndef.isWritable) {
                  // Scrivi messaggio vuoto
                  await ndef.write(NdefMessage([]));
                  success = true;
                }
              } catch (e) {
                log.e('Error formatting NFC', e);
              } finally {
                await NfcManager.instance.stopSession();
              }
            },
          );
          return success;
          */
          log.w('NFC format non implementato');
          break;

        case CardType.usb:
          // Invia comando FORMAT al lettore USB
          /*
          import 'package:usb_serial/usb_serial.dart';

          final devices = await UsbSerial.listDevices();
          if (devices.isNotEmpty) {
            final port = await devices.first.create();
            await port?.open();
            await port?.write(Uint8List.fromList([0x03])); // CMD: FORMAT
            await Future.delayed(const Duration(milliseconds: 500));
            final response = await port?.read();
            await port?.close();
            return response != null && response.isNotEmpty && response[0] == 0x06;
          }
          */
          log.w('USB format non implementato');
          break;

        case CardType.rfid:
          // Formatta card RFID (dipende dal lettore specifico)
          log.w('RFID format non implementato');
          break;
      }

      log.w('Formattazione non disponibile per ${type.name}');
      return false;
    } catch (e) {
      log.e('Error formatting card', e);
      return false;
    }
  }
}
