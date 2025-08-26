import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:asn1lib/asn1lib.dart';
import 'credential_services.dart';

// ***** Clases auxiliares *****
class _P12Data {
  final Uint8List bytes;
  final String password;
  _P12Data(this.bytes, this.password);
}

class _SignatureCoords {
  final double pdfX;
  final double pdfY;
  _SignatureCoords(this.pdfX, this.pdfY);
}

class DebugInfo {
  final String label;
  final double x;
  final double y;
  final Color color;
  DebugInfo(this.label, this.x, this.y, this.color);
}

class SigningService {
  final _credentialService = CredentialService();

  // ===================== CONSTANTES =====================
  static const Size _qrSize = Size(60, 60);
  static const double _textSpacing = 5.0;
  static const double _fontSize = 8.0;
  static const String _defaultSignerName = 'Firmante no identificado';
  
  // 🐛 MODO DEBUG - Activar para ver marcadores visuales
  static const bool _debugMode = true;
  
  // Mapa de OIDs comunes a nombres legibles
  static const Map<String, String> _oidToName = {
    '2.5.4.3': 'CN',
    '2.5.4.6': 'C',
    '2.5.4.7': 'L',
    '2.5.4.8': 'ST',
    '2.5.4.10': 'O',
    '2.5.4.11': 'OU',
    '1.2.840.113549.1.9.1': 'emailAddress',
  };

  // ===================== MÉTODO PRINCIPAL CON DEBUG =====================
  Future<File?> signPdf(
    File originalPdf,
    Offset pdfOffset,
    int pageIndex,
  ) async {
    PdfDocument? document;
    
    try {
      print('🚀 === INICIANDO PROCESO DE FIRMA ===');
      print('📂 Archivo: ${originalPdf.path}');
      print('✍️ Posición PDF: ${pdfOffset.dx}, ${pdfOffset.dy}');
      print('📄 Página: $pageIndex');
      
      // 1️⃣ Cargar credenciales
      final p12Data = await _loadP12Credentials();
      print('✅ Credenciales cargadas');

      // 2️⃣ Leer PDF
      final pdfBytes = await originalPdf.readAsBytes();
      document = PdfDocument(inputBytes: pdfBytes);
      print('✅ PDF cargado para firma');

      // 3️⃣ Generar QR
      final qrImage = await _generateQrImage('Documento Firmado por SoloFirma');
      print('✅ QR generado');

      // 4️⃣ Obtener nombre del firmante
      final signerName = _extractSignerName(p12Data.bytes, p12Data.password);
      print('✅ Nombre firmante: $signerName');

      // 5️⃣ Dibujar QR y nombre
      final page = document.pages[pageIndex];
      _drawQrAndName(page, qrImage, signerName, pdfOffset.dx, pdfOffset.dy);
      print('✅ QR y nombre dibujados');

      // 6️⃣ Aplicar firma digital
      _applyDigitalSignature(document, p12Data.bytes, p12Data.password, pageIndex, pdfOffset.dx, pdfOffset.dy);
      print('✅ Firma digital aplicada');

      // 7️⃣ Guardar PDF firmado
      final signedFile = await _saveSignedPdf(originalPdf, document);
      print('✅ PDF firmado guardado');

      return signedFile;
    } catch (e) {
      print('❌ Error al firmar el documento: $e');
      document?.dispose();
      return null;
    }
  }

  // ===================== RESTO DE MÉTODOS =====================

  Future<_P12Data> _loadP12Credentials() async {
    try {
      final credentials = await _credentialService.getCredentials();
      final password = credentials['password'];
      final p12Path = credentials['path'];

      if (password == null || password.isEmpty) {
        throw Exception('Contraseña del certificado no proporcionada');
      }
      if (p12Path == null || p12Path.isEmpty) {
        throw Exception('Ruta del certificado no proporcionada');
      }

      final p12File = File(p12Path);
      if (!await p12File.exists()) {
        throw Exception('El archivo .p12 no existe en la ruta: $p12Path');
      }

      final p12Bytes = await p12File.readAsBytes();
      return _P12Data(p12Bytes, password);
    } catch (e) {
      throw Exception('Error al cargar credenciales: $e');
    }
  }

  Future<PdfBitmap> _generateQrImage(String data) async {
    final qrImageData = await QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    ).toImageData(200);

    if (qrImageData == null) {
      throw Exception('No se pudo generar la imagen del QR.');
    }
    return PdfBitmap(qrImageData.buffer.asUint8List());
  }

  String _extractSignerName(Uint8List p12Bytes, String password) {
    try {
      print('🔍 Iniciando extracción robusta de nombre del certificado...');
      
      final certPemStrings = Pkcs12Utils.parsePkcs12(p12Bytes, password: password)
          .where((pem) => pem.contains('BEGIN CERTIFICATE'))
          .toList();

      if (certPemStrings.isEmpty) {
        print('❌ No se encontraron certificados válidos.');
        return _defaultSignerName;
      }

      print('📋 Certificados encontrados: ${certPemStrings.length}');

      // Paso 1: Parsear todos los certificados para obtener sus detalles
      final List<Map<String, dynamic>> certDetails = [];
      for (int i = 0; i < certPemStrings.length; i++) {
        final details = _parseCertificateDetails(certPemStrings[i]);
        if (details != null) {
          certDetails.add(details);
          print('✅ Certificado $i parseado: CN="${details['cn']}", Subject="${details['subjectDN']}"');
        } else {
          print('❌ No se pudo parsear el certificado $i');
        }
      }

      if (certDetails.isEmpty) {
        print('❌ No se pudo parsear ningún certificado');
        return _defaultSignerName;
      }

      // Paso 2: Crear un conjunto con todos los nombres de los Emisores (Issuers)
      final issuers = certDetails.map((details) => details['issuerDN']).toSet();
      print('🏢 Emisores encontrados: ${issuers.length}');

      // Paso 3: Encontrar el certificado cuyo Sujeto (Subject) NO está en la lista de Emisores
      Map<String, dynamic>? endEntityCert;
      for (final details in certDetails) {
        if (!issuers.contains(details['subjectDN'])) {
          endEntityCert = details;
          print('🎯 Certificado final identificado: "${details['cn']}"');
          break;
        }
      }

      if (endEntityCert != null) {
        final signerName = endEntityCert['cn'] ?? _defaultSignerName;
        print('✅ Nombre del firmante final encontrado: "$signerName"');
        return signerName;
      }
      
      print('⚠️ No se pudo identificar el certificado final. Usando el primero disponible.');
      final fallbackName = certDetails.first['cn'] ?? _defaultSignerName;
      print('🔄 Nombre de fallback: "$fallbackName"');
      return fallbackName;

    } catch (e) {
      print('💥 Error fatal durante la extracción del nombre: $e');
      return _defaultSignerName;
    }
  }

  Map<String, String>? _parseCertificateDetails(String pem) {
    try {
      final bytes = base64.decode(pem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''));

      final asn1Parser = ASN1Parser(bytes);
      final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
      final certSeq = topLevelSeq.elements[0] as ASN1Sequence;

      // Buscar las secuencias de Distinguished Names dinámicamente
      ASN1Sequence? issuerSeq;
      ASN1Sequence? subjectSeq;
      
      for (int i = 0; i < certSeq.elements.length; i++) {
        final element = certSeq.elements[i];
        if (element is ASN1Sequence && _isDistinguishedNameSequence(element)) {
          if (issuerSeq == null) {
            issuerSeq = element;
          } else if (subjectSeq == null) {
            subjectSeq = element;
            break;
          }
        }
      }

      if (issuerSeq == null || subjectSeq == null) {
        return null;
      }

      final subjectDN = _distinguishedNameToString(subjectSeq);
      final issuerDN = _distinguishedNameToString(issuerSeq);
      final commonName = _extractCommonNameFromDN(subjectSeq);

      return {
        'cn': _cleanSignerName(commonName ?? ''),
        'subjectDN': subjectDN,
        'issuerDN': issuerDN,
      };
    } catch (e) {
      return null;
    }
  }

  bool _isDistinguishedNameSequence(ASN1Sequence sequence) {
    try {
      if (sequence.elements.isEmpty) return false;
      
      for (int i = 0; i < sequence.elements.length && i < 3; i++) {
        if (sequence.elements[i] is! ASN1Set) {
          return false;
        }
        
        final set = sequence.elements[i] as ASN1Set;
        if (set.elements.isEmpty || set.elements.first is! ASN1Sequence) {
          return false;
        }
        
        final innerSeq = set.elements.first as ASN1Sequence;
        if (innerSeq.elements.isEmpty || innerSeq.elements.first is! ASN1ObjectIdentifier) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  String? _extractCommonNameFromDN(ASN1Sequence dnSequence) {
    try {
      for (var element in dnSequence.elements) {
        if (element is ASN1Set && element.elements.isNotEmpty) {
          final seq = element.elements.first;
          if (seq is ASN1Sequence && seq.elements.length >= 2) {
            final oid = seq.elements[0];
            if (oid is ASN1ObjectIdentifier && oid.identifier == '2.5.4.3') {
              return _extractStringFromASN1Object(seq.elements[1]);
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _extractStringFromASN1Object(ASN1Object asn1Object) {
    try {
      if (asn1Object is ASN1PrintableString) {
        return asn1Object.stringValue;
      } else if (asn1Object is ASN1UTF8String) {
        return asn1Object.utf8StringValue;
      } else if (asn1Object is ASN1IA5String) {
        return asn1Object.stringValue;
      } else {
        final objectStr = asn1Object.toString();
        if (objectStr.contains(':')) {
          final parts = objectStr.split(':');
          if (parts.length > 1) {
            return parts.last.trim();
          }
        }
        return objectStr;
      }
    } catch (e) {
      return asn1Object.toString();
    }
  }

  String _distinguishedNameToString(ASN1Sequence dnSequence) {
    try {
      final parts = <String>[];
      
      for (var element in dnSequence.elements) {
        try {
          if (element is ASN1Set && element.elements.isNotEmpty) {
            final seq = element.elements.first;
            if (seq is ASN1Sequence && seq.elements.length >= 2) {
              final oid = seq.elements[0];
              final value = seq.elements[1];
              
              if (oid is ASN1ObjectIdentifier) {
                final oidName = _oidToName[oid.identifier] ?? oid.identifier;
                final stringValue = _extractStringFromASN1Object(value);
                if (stringValue.isNotEmpty) {
                  parts.add('$oidName=$stringValue');
                }
              }
            }
          }
        } catch (elementError) {
          continue;
        }
      }
      
      return parts.join(', ');
    } catch (e) {
      return '';
    }
  }

  String _cleanSignerName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F\-\.]'), '')
        .trim();
  }

  void _drawQrAndName(PdfPage page, PdfBitmap qrImage, String signerName, double pdfX, double pdfY) {
    // Dibujar QR
    page.graphics.drawImage(qrImage, Rect.fromLTWH(pdfX, pdfY, _qrSize.width, _qrSize.height));

    // Dibujar nombre simplificado
    final font = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
    page.graphics.drawString(
      signerName,
      font,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(pdfX, pdfY + _qrSize.height + _textSpacing, _qrSize.width + 40, 20),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }

  void _applyDigitalSignature(
    PdfDocument document,
    Uint8List p12Bytes,
    String password,
    int pageIndex,
    double pdfX,
    double pdfY,
  ) {
    final certificate = PdfCertificate(p12Bytes, password);

    final field = PdfSignatureField(
      document.pages[pageIndex],
      'SoloFirmaSignature_${DateTime.now().millisecondsSinceEpoch}',
      bounds: Rect.fromLTWH(pdfX, pdfY, _qrSize.width, _qrSize.height + 35),
      signature: PdfSignature(
        certificate: certificate,
        contactInfo: 'firmado@solofirma.app',
        reason: 'Firmado digitalmente con SoloFirma',
        locationInfo: 'Ecuador',
      ),
    );

    document.form.fields.add(field);
  }

  Future<File> _saveSignedPdf(File originalPdf, PdfDocument document) async {
    try {
      final signedBytes = await document.save();
      
      final signedPath = originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
      final signedFile = File(signedPath);
      await signedFile.writeAsBytes(signedBytes);

      print('✅ PDF firmado guardado en: $signedPath');
      return signedFile;
    } finally {
      document.dispose();
    }
  }
}