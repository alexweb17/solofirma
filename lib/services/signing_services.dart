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

class SigningService {
  final _credentialService = CredentialService();

  // ===================== CONSTANTES =====================
  static const Size _qrSize = Size(60, 60);
  static const double _textSpacing = 5.0;
  static const double _fontSize = 8.0;
  static const String _defaultSignerName = 'Firmante no identificado';
  
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

  // ===================== MÉTODO PRINCIPAL =====================
  Future<File?> signPdf(
    File originalPdf,
    Offset signaturePosition,
    Size viewSize,
    int pageIndex,
  ) async {
    PdfDocument? document;
    try {
      // 1️⃣ Cargar credenciales
      final p12Data = await _loadP12Credentials();

      // 2️⃣ Leer PDF
      final pdfBytes = await originalPdf.readAsBytes();
      document = PdfDocument(inputBytes: pdfBytes);

      // 3️⃣ Generar QR
      final qrImage = await _generateQrImage('Documento Firmado por SoloFirma');

      // 4️⃣ Calcular posición de firma
      final coords = _calculateSignatureCoordinates(document, viewSize, signaturePosition, pageIndex);

      // 5️⃣ Obtener nombre del firmante
      final signerName = _extractSignerName(p12Data.bytes, p12Data.password);

      // 6️⃣ Dibujar QR y nombre
      _drawQrAndName(document.pages[pageIndex], qrImage, signerName, coords.pdfX, coords.pdfY);

      // 7️⃣ Aplicar firma digital
      _applyDigitalSignature(document, p12Data.bytes, p12Data.password, pageIndex, coords.pdfX, coords.pdfY);

      // 8️⃣ Guardar PDF firmado
      final signedFile = await _saveSignedPdf(originalPdf, document);

      return signedFile;
    } catch (e) {
      print('Error al firmar el documento: $e');
      // Asegurar que se libere la memoria incluso si hay error
      document?.dispose();
      return null;
    }
  }

  // ===================== MÉTODOS PRIVADOS =====================

  /// Cargar archivo P12 y contraseña con manejo robusto de errores
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

  /// Generar QR como PdfBitmap
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

  /// Calcular coordenadas de firma con validación y ajuste preciso
  _SignatureCoords _calculateSignatureCoordinates(
    PdfDocument document,
    Size viewSize,
    Offset signaturePosition,
    int pageIndex,
  ) {
    if (pageIndex < 0 || pageIndex >= document.pages.count) {
      throw Exception('Página $pageIndex no válida. Páginas disponibles: 0-${document.pages.count - 1}');
    }
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      throw Exception('Tamaño de vista inválido: $viewSize');
    }

    final page = document.pages[pageIndex];
    final pageSize = page.size;

    print('📐 Calculando coordenadas:');
    print('   Vista: ${viewSize.width}x${viewSize.height}');
    print('   Página PDF: ${pageSize.width}x${pageSize.height}');
    print('   Posición táctil: ${signaturePosition.dx}, ${signaturePosition.dy}');

    // Calcular la escala y el offset considerando aspect ratio
    final scaleX = pageSize.width / viewSize.width;
    final scaleY = pageSize.height / viewSize.height;
    
    // Usar la misma escala para mantener proporciones (como hace el visor PDF)
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Convertir coordenadas de vista a coordenadas PDF
    double pdfX = signaturePosition.dx * scale;
    // Para Y: Flutter usa (0,0) arriba, PDF usa (0,0) abajo
    double pdfY = pageSize.height - (signaturePosition.dy * scale);
    
    // Ajustar para centrar el QR en el punto tocado
    pdfX -= _qrSize.width / 2;
    pdfY -= (_qrSize.height + 25) / 2; // 25 para el texto
    
    print('   Escala aplicada: $scale');
    print('   Posición PDF calculada: $pdfX, $pdfY');

    // Limitar dentro de la página con márgenes
    const margin = 10.0;
    pdfX = pdfX.clamp(margin, pageSize.width - _qrSize.width - margin).toDouble();
    pdfY = pdfY.clamp(margin, pageSize.height - _qrSize.height - 25.0 - margin).toDouble();

    print('   Posición PDF final: $pdfX, $pdfY');
    return _SignatureCoords(pdfX, pdfY);
  }

  /// Extraer nombre del firmante del P12 - VERSIÓN ROBUSTA CON ASN.1
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

  /// Parsea un certificado PEM para extraer el Common Name (CN), el SubjectDN y el IssuerDN
  Map<String, String>? _parseCertificateDetails(String pem) {
    try {
      final bytes = base64.decode(pem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''));

      final asn1Parser = ASN1Parser(bytes);
      final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
      final certSeq = topLevelSeq.elements[0] as ASN1Sequence;

      print('🔍 Estructura del certificado - elementos: ${certSeq.elements.length}');
      for (int i = 0; i < certSeq.elements.length && i < 10; i++) {
        print('  [$i]: ${certSeq.elements[i].runtimeType}');
      }

      // Buscar las secuencias de Distinguished Names dinámicamente
      ASN1Sequence? issuerSeq;
      ASN1Sequence? subjectSeq;
      
      for (int i = 0; i < certSeq.elements.length; i++) {
        final element = certSeq.elements[i];
        if (element is ASN1Sequence && _isDistinguishedNameSequence(element)) {
          if (issuerSeq == null) {
            issuerSeq = element;
            print('✅ Issuer encontrado en posición $i');
          } else if (subjectSeq == null) {
            subjectSeq = element;
            print('✅ Subject encontrado en posición $i');
            break;
          }
        }
      }

      if (issuerSeq == null || subjectSeq == null) {
        print('❌ No se pudieron encontrar las secuencias issuer/subject');
        return null;
      }

      String? commonName;
      final subjectDN = _distinguishedNameToString(subjectSeq);
      final issuerDN = _distinguishedNameToString(issuerSeq);

      // Extraer específicamente el Common Name (CN) del Sujeto
      commonName = _extractCommonNameFromDN(subjectSeq);

      return {
        'cn': _cleanSignerName(commonName ?? ''),
        'subjectDN': subjectDN,
        'issuerDN': issuerDN,
      };
    } catch (e) {
      print('⚠️ Error al parsear un certificado: $e');
      return null;
    }
  }

  /// Verifica si una secuencia ASN.1 es un Distinguished Name
  bool _isDistinguishedNameSequence(ASN1Sequence sequence) {
    try {
      // Un DN típicamente contiene varios SET elements
      if (sequence.elements.isEmpty) return false;
      
      // Verificar que los primeros elementos sean ASN1Set
      for (int i = 0; i < sequence.elements.length && i < 3; i++) {
        if (sequence.elements[i] is! ASN1Set) {
          return false;
        }
        
        // Verificar que cada SET contenga una secuencia con OID
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

  /// Extrae el Common Name de una secuencia Distinguished Name
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
      print('⚠️ Error al extraer CN: $e');
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
        // Para otros tipos, intentar acceder a propiedades comunes
        // usando reflection dinámica o fallback seguro
        final objectStr = asn1Object.toString();
        
        // Intentar extraer el valor si tiene una estructura conocida
        if (objectStr.contains(':')) {
          final parts = objectStr.split(':');
          if (parts.length > 1) {
            return parts.last.trim();
          }
        }
        
        return objectStr;
      }
    } catch (e) {
      print('⚠️ Error al extraer string de objeto ASN.1: $e');
      return asn1Object.toString();
    }
  }

  /// Convierte una secuencia ASN.1 de un Distinguished Name a un String legible
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
          print('⚠️ Error procesando elemento DN: $elementError');
          continue; // Continuar con el siguiente elemento
        }
      }
      
      return parts.join(', ');
    } catch (e) {
      print('⚠️ Error al convertir Distinguished Name: $e');
      return '';
    }
  }

  /// Limpiar y formatear el nombre del firmante
  String _cleanSignerName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F\-\.]'), '') // Mantener acentos, guiones y puntos
        .trim();
  }

  /// Dibujar QR y nombre con ajuste automático de texto
  void _drawQrAndName(PdfPage page, PdfBitmap qrImage, String signerName, double pdfX, double pdfY) {
    // Dibujar QR
    page.graphics.drawImage(qrImage, Rect.fromLTWH(pdfX, pdfY, _qrSize.width, _qrSize.height));

    // Preparar el texto con ajuste automático
    final font = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
    String displayName = signerName.trim();
    
    // Calcular el ancho disponible (un poco más que el QR)
    final maxWidth = _qrSize.width + 40; // 20px extra a cada lado
    final textSize = font.measureString(displayName);
    
    print('📝 Procesando nombre: "$displayName"');
    print('   Ancho del texto: ${textSize.width}');
    print('   Ancho máximo: $maxWidth');

    // Si el texto es muy ancho, intentar ajustarlo
    if (textSize.width > maxWidth) {
      // Opción 1: Intentar con solo nombres y primer apellido
      final nameParts = displayName.split(' ');
      if (nameParts.length > 2) {
        // Tomar primer nombre y primer apellido
        displayName = '${nameParts[0]} ${nameParts[1]}';
        final newSize = font.measureString(displayName);
        
        if (newSize.width > maxWidth) {
          // Opción 2: Solo primer nombre y inicial del apellido
          displayName = '${nameParts[0]} ${nameParts[1][0]}.';
          final finalSize = font.measureString(displayName);
          
          if (finalSize.width > maxWidth) {
            // Opción 3: Truncar con puntos suspensivos
            final maxChars = (maxWidth / (textSize.width / displayName.length)).floor() - 3;
            if (maxChars > 5) {
              displayName = '${signerName.substring(0, maxChars)}...';
            } else {
              displayName = '${signerName.substring(0, 8)}...';
            }
          }
        }
        print('   Nombre ajustado: "$displayName"');
      } else {
        // Si son solo 2 palabras o menos, truncar directamente
        final maxChars = (maxWidth / (textSize.width / displayName.length)).floor() - 3;
        if (maxChars > 5) {
          displayName = '${displayName.substring(0, maxChars)}...';
        }
      }
    }

    // Calcular posición centrada con el ancho real del texto final
    final finalTextSize = font.measureString(displayName);
    final textX = pdfX + (_qrSize.width - finalTextSize.width) / 2;
    final textY = pdfY + _qrSize.height + _textSpacing;

    // Asegurar que el texto no se salga de la página
    final pageWidth = page.size.width;
    final finalTextX = textX.clamp(5.0, pageWidth - finalTextSize.width - 5.0).toDouble();

    print('   Posición final del texto: $finalTextX, $textY');

    // Dibujar el texto
    page.graphics.drawString(
      displayName,
      font,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(finalTextX, textY, maxWidth + 10, 15),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
  }

  /// Aplicar firma digital
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
      bounds: Rect.fromLTWH(pdfX, pdfY, _qrSize.width, _qrSize.height + 25),
      signature: PdfSignature(
        certificate: certificate,
        contactInfo: 'firmado@solofirma.app',
        reason: 'Firmado digitalmente con SoloFirma',
        locationInfo: 'Ecuador',
      ),
    );

    document.form.fields.add(field);
  }

  /// Guardar PDF firmado
  Future<File> _saveSignedPdf(File originalPdf, PdfDocument document) async {
    try {
      final signedBytes = await document.save();
      
      final signedPath = originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
      final signedFile = File(signedPath);
      await signedFile.writeAsBytes(signedBytes);

      print('PDF firmado guardado en: $signedPath');
      return signedFile;
    } finally {
      // Siempre liberar memoria
      document.dispose();
    }
  }
}