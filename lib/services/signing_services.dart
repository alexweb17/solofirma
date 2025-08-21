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
    Offset signaturePosition,
    Size viewSize,
    int pageIndex,
  ) async {
    PdfDocument? document;
    PdfDocument? debugDocument;
    
    try {
      print('🚀 === INICIANDO PROCESO DE FIRMA ===');
      print('📂 Archivo: ${originalPdf.path}');
      print('👆 Posición: ${signaturePosition.dx}, ${signaturePosition.dy}');
      print('📱 Tamaño vista: ${viewSize.width} x ${viewSize.height}');
      
      // 🐛 CREAR PDF DEBUG PRIMERO (antes de modificar nada)
      if (_debugMode) {
        final pdfBytes = await originalPdf.readAsBytes();
        debugDocument = PdfDocument(inputBytes: pdfBytes);
        await _createDebugVersion(debugDocument, viewSize, signaturePosition, pageIndex, originalPdf);
        debugDocument.dispose(); // Liberar inmediatamente
        debugDocument = null;
      }

      // 1️⃣ Cargar credenciales
      final p12Data = await _loadP12Credentials();
      print('✅ Credenciales cargadas');

      // 2️⃣ Leer PDF (nueva instancia para firma)
      final pdfBytes = await originalPdf.readAsBytes();
      document = PdfDocument(inputBytes: pdfBytes);
      print('✅ PDF cargado para firma');

      // 3️⃣ Generar QR
      final qrImage = await _generateQrImage('Documento Firmado por SoloFirma');
      print('✅ QR generado');

      // 4️⃣ Calcular posición
      final coords = _calculateSignatureCoordinates(document, viewSize, signaturePosition, pageIndex);
      print('✅ Coordenadas calculadas: (${coords.pdfX}, ${coords.pdfY})');

      // 5️⃣ Obtener nombre del firmante
      final signerName = _extractSignerName(p12Data.bytes, p12Data.password);
      print('✅ Nombre firmante: $signerName');

      // 6️⃣ Dibujar QR y nombre
      _drawQrAndName(document.pages[pageIndex], qrImage, signerName, coords.pdfX, coords.pdfY);
      print('✅ QR y nombre dibujados');

      // 7️⃣ Aplicar firma digital
      _applyDigitalSignature(document, p12Data.bytes, p12Data.password, pageIndex, coords.pdfX, coords.pdfY);
      print('✅ Firma digital aplicada');

      // 8️⃣ Guardar PDF firmado
      final signedFile = await _saveSignedPdf(originalPdf, document);
      print('✅ PDF firmado guardado');

      return signedFile;
    } catch (e) {
      print('❌ Error al firmar el documento: $e');
      document?.dispose();
      debugDocument?.dispose();
      return null;
    }
  }

  // 🐛 ===================== MÉTODO DEBUG SEPARADO =====================
  Future<void> _createDebugVersion(
    PdfDocument debugDoc,
    Size viewSize,
    Offset signaturePosition,
    int pageIndex,
    File originalFile,
  ) async {
    try {
      print('🐛 === CREANDO VERSIÓN DEBUG ===');
      
      final page = debugDoc.pages[pageIndex];
      final pageSize = page.size;
      
      print('📱 Vista: ${viewSize.width} x ${viewSize.height}');
      print('📄 PDF: ${pageSize.width} x ${pageSize.height}');
      print('👆 Toque: (${signaturePosition.dx}, ${signaturePosition.dy})');

      // Lista de puntos para marcar con diferentes métodos
      final debugPoints = <DebugInfo>[
        // Método 1: Coordenadas directas 
        DebugInfo('DIRECTO', signaturePosition.dx, pageSize.height - signaturePosition.dy, Colors.red),
        
        // Método 2: Escala proporcional
        DebugInfo('ESCALA', 
          (signaturePosition.dx * pageSize.width) / viewSize.width,
          pageSize.height - (signaturePosition.dy * pageSize.height) / viewSize.height,
          Colors.blue
        ),
        
        // Método 3: Coordenadas relativas
        DebugInfo('RELATIVO', 
          (signaturePosition.dx / viewSize.width) * pageSize.width,
          pageSize.height - ((signaturePosition.dy / viewSize.height) * pageSize.height),
          Colors.green
        ),
        
        // Método 4: Punto central de página (referencia)
        DebugInfo('CENTRO', pageSize.width / 2, pageSize.height / 2, Colors.orange),
      ];

      // Dibujar grid de referencia primero
      _drawReferenceGrid(page, pageSize);
      
      // Dibujar marcadores de debug
      for (int i = 0; i < debugPoints.length; i++) {
        final point = debugPoints[i];
        _drawDebugMarker(page, point, i);
        print('🎯 ${point.label}: (${point.x.toStringAsFixed(1)}, ${point.y.toStringAsFixed(1)})');
      }

      // Dibujar información en la esquina
      _drawDebugInfo(page, viewSize, pageSize, signaturePosition);
      
      // Guardar versión debug
      final debugBytes = await debugDoc.save();
      final debugPath = originalFile.path.replaceAll('.pdf', '_DEBUG.pdf');
      final debugFile = File(debugPath);
      await debugFile.writeAsBytes(debugBytes);
      
      print('🐛 ✅ Archivo DEBUG guardado en: $debugPath');
      print('🐛 === FIN DEBUG ===\n');
      
    } catch (e) {
      print('❌ Error creando versión debug: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Dibujar información debug en la esquina
  void _drawDebugInfo(PdfPage page, Size viewSize, Size pageSize, Offset position) {
    final font = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final info = [
      'DEBUG INFO:',
      'Vista: ${viewSize.width.toInt()} x ${viewSize.height.toInt()}',
      'PDF: ${pageSize.width.toInt()} x ${pageSize.height.toInt()}',
      'Toque: ${position.dx.toInt()}, ${position.dy.toInt()}',
      '',
      'MARCADORES:',
      '🔴 ROJO = Directo',
      '🔵 AZUL = Escala',
      '🟢 VERDE = Relativo', 
      '🟠 NARANJA = Centro',
    ];

    double y = 20;
    for (final line in info) {
      page.graphics.drawString(
        line,
        font,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(20, y, 200, 15),
      );
      y += 12;
    }
  }

  // Dibujar marcador de debug
  void _drawDebugMarker(PdfPage page, DebugInfo debug, int index) {
    // Convertir Color de Flutter a PdfBrush
    PdfBrush brush;
    switch (debug.color) {
      case Colors.red:
        brush = PdfBrushes.red;
        break;
      case Colors.blue:
        brush = PdfBrushes.blue;
        break;
      case Colors.green:
        brush = PdfBrushes.green;
        break;
      case Colors.orange:
        brush = PdfBrushes.orange;
        break;
      default:
        brush = PdfBrushes.black;
    }
    
    // Dibujar círculo más grande
    page.graphics.drawEllipse(
      Rect.fromLTWH(debug.x - 8, debug.y - 8, 16, 16),
      brush: brush,
    );
    
    // Dibujar etiqueta
    final font = PdfStandardFont(PdfFontFamily.helvetica, 8);
    page.graphics.drawString(
      debug.label,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(debug.x + 12, debug.y - 4, 60, 12),
    );
    
    // Dibujar cruz centrada
    page.graphics.drawLine(
      PdfPens.black,
      Offset(debug.x - 6, debug.y),
      Offset(debug.x + 6, debug.y),
    );
    page.graphics.drawLine(
      PdfPens.black,
      Offset(debug.x, debug.y - 6),
      Offset(debug.x, debug.y + 6),
    );

    // Dibujar coordenadas
    page.graphics.drawString(
      '(${debug.x.toInt()},${debug.y.toInt()})',
      PdfStandardFont(PdfFontFamily.helvetica, 6),
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(debug.x + 12, debug.y + 8, 60, 10),
    );
  }

  // Dibujar grid de referencia
  void _drawReferenceGrid(PdfPage page, Size pageSize) {
    final gridPen = PdfPen(PdfColor(220, 220, 220), width: 0.3);
    final font = PdfStandardFont(PdfFontFamily.helvetica, 6);
    
    // Líneas verticales cada 100 puntos
    for (double x = 0; x <= pageSize.width; x += 100) {
      page.graphics.drawLine(gridPen, Offset(x, 0), Offset(x, pageSize.height));
      if (x > 0 && x < pageSize.width - 50) {
        page.graphics.drawString('${x.toInt()}', font, 
          brush: PdfBrushes.gray,
          bounds: Rect.fromLTWH(x + 2, 2, 30, 10));
      }
    }
    
    // Líneas horizontales cada 100 puntos
    for (double y = 0; y <= pageSize.height; y += 100) {
      page.graphics.drawLine(gridPen, Offset(0, y), Offset(pageSize.width, y));
      if (y > 0 && y < pageSize.height - 20) {
        page.graphics.drawString('${y.toInt()}', font,
          brush: PdfBrushes.gray,
          bounds: Rect.fromLTWH(2, y + 2, 30, 10));
      }
    }
  }

  // ===================== MÉTODO SIMPLE PARA TESTING =====================
  _SignatureCoords _calculateSignatureCoordinates(
    PdfDocument document,
    Size viewSize,
    Offset signaturePosition,
    int pageIndex,
  ) {
    final page = document.pages[pageIndex];
    final pageSize = page.size;

    // Usar método relativo (el que suele funcionar mejor)
    final relativeX = signaturePosition.dx / viewSize.width;
    final relativeY = signaturePosition.dy / viewSize.height;
    
    double pdfX = relativeX * pageSize.width;
    double pdfY = pageSize.height - (relativeY * pageSize.height);
    
    // Centrar el QR en el punto
    pdfX -= _qrSize.width / 2;
    pdfY -= (_qrSize.height + 35) / 2;

    // Ajuste vertical para corregir el desfase de ~50px reportado
    pdfY += 10;
    pdfX += 100;
    
    // Aplicar márgenes
    const margin = 10.0;
    pdfX = pdfX.clamp(margin, pageSize.width - _qrSize.width - margin);
    pdfY = pdfY.clamp(margin, pageSize.height - _qrSize.height - 35 - margin);
    
    return _SignatureCoords(pdfX, pdfY);
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