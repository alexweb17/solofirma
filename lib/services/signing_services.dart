import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ===================== FUNCIÓN DE ISOLATE PARA LA FIRMA (FALLBACK) =====================
Future<String?> _signPdfIsolate(Map<String, dynamic> params) async {
  final pdfBytes = params['pdfBytes'] as Uint8List;
  final p12Bytes = params['p12Bytes'] as Uint8List;
  final password = params['password'] as String;
  final qrBytes = params['qrBytes'] as Uint8List;
  final pdfOffsetX = params['pdfOffsetX'] as double;
  final pdfOffsetY = params['pdfOffsetY'] as double;
  final pageIndex = params['pageIndex'] as int;
  final originalPath = params['originalPath'] as String;

  PdfDocument? document;

  try {
    print('DEBUG: Starting _signPdfIsolate (Syncfusion fallback)...');
    document = PdfDocument(inputBytes: pdfBytes);
    final qrImage = PdfBitmap(qrBytes);
    final signerName = _extractSignerName(p12Bytes, password);
    _applyDigitalSignature(document, p12Bytes, password, pageIndex, pdfOffsetX, pdfOffsetY, qrBytes, signerName);
    final signedFile = await _saveSignedPdf(originalPath, document);
    print('DEBUG: PDF Signed and saved at: ${signedFile.path}');
    return signedFile.path;
  } catch (e, stackTrace) {
    print('ERROR IN ISOLATE: $e');
    print(stackTrace);
    document?.dispose();
    return null;
  }
}

class SigningService {
  final _credentialService = CredentialService();
  
  // Native Android signing channel
  static const _signingChannel = MethodChannel('com.dataguapp.solofirma/signing');

  // ===================== MÉTODO PRINCIPAL - USA NATIVO PRIMERO =====================
  Future<File?> signPdf(
    File originalPdf,
    Offset pdfOffset,
    int pageIndex,
  ) async {
    try {
      print('DEBUG: Starting signPdf...');
      final p12Data = await _loadP12Credentials();
      
      // Extraer nombre del firmante
      String signerName = 'Firmado Digitalmente';
      try {
        signerName = _extractSignerName(p12Data.bytes, p12Data.password);
      } catch (e) {
        print('WARN: Could not extract signer name: $e');
      }
      
      // Intentar firma nativa primero (Android)
      if (Platform.isAndroid) {
        try {
          final outputPath = originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
          
          final result = await _signingChannel.invokeMethod<String>('signPdfWithLtv', {
            'pdfPath': originalPdf.path,
            'p12Bytes': p12Data.bytes,
            'password': p12Data.password,
            'outputPath': outputPath,
            'signerName': signerName,
            'reason': 'Documento firmado con SoloFirma',
            'location': 'Ecuador',
            'pageNumber': pageIndex + 1, // iText uses 1-based page numbers
            'x': pdfOffset.dx,
            'y': pdfOffset.dy,
            'width': 200.0,
            'height': 50.0,
          });
          
          if (result != null) {
            print('DEBUG: Native signing successful: $result');
            return File(result);
          }
        } catch (e) {
          print('DEBUG: Native signing failed: $e');
          // CRITICAL: Rethrow so UI shows the error from Kotlin (e.g. LTV failure)
          // Do NOT fallback to Syncfusion as it produces freezing PDFs.
          rethrow;
        }
      } else {
        // Non-Android platforms: continue to Syncfusion fallback below
      }
      
      // Fallback: usar Syncfusion (sin LTV)
      print('DEBUG: Using Syncfusion fallback...');
      final qrBytes = await _generateQrImage('Documento Firmado por SoloFirma');
      if (qrBytes == null) {
        throw Exception('No se pudo generar la imagen del QR.');
      }

      final signedFilePath = await compute(_signPdfIsolate, {
        'pdfBytes': await originalPdf.readAsBytes(),
        'p12Bytes': p12Data.bytes,
        'password': p12Data.password,
        'qrBytes': qrBytes,
        'pdfOffsetX': pdfOffset.dx,
        'pdfOffsetY': pdfOffset.dy,
        'pageIndex': pageIndex,
        'originalPath': originalPdf.path,
      });

      if (signedFilePath != null) {
        // Habilitar LTV via canal nativo (iText)
        try {
          print('DEBUG: Requesting Native LTV enablement for: $signedFilePath');
          await enableLtv(signedFilePath);
          print('DEBUG: Native LTV enabled successfully.');
        } catch (e) {
          print('WARN: Failed to enable LTV via native channel: $e');
          // No lanzamos excepción aquí para no bloquear el flujo si LTV falla,
          // aunque el PDF podría no ser validable a largo plazo.
        }
        return File(signedFilePath);
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      print('ERROR IN SIGNPDF: $e');
      print(stackTrace);
      // CRITICAL: Rethrow to show the specific error in the UI (e.g. PlatformException)
      // instead of the generic "No se pudo firmar" message.
      rethrow;
    }
  }


  // ===================== MÉTODO LTV NATIVO =====================
  Future<void> enableLtv(String filePath) async {
    try {
      await _signingChannel.invokeMethod('enableLtv', {'path': filePath});
    } on PlatformException catch (e) {
      print("Failed to enable LTV: '${e.message}'.");
      rethrow;
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
}

// ===================== FUNCIONES DE AYUDA (NIVEL SUPERIOR) =====================

Future<Uint8List?> _generateQrImage(String data) async {
  final qrImageData = await QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: false,
  ).toImageData(200);

  return qrImageData?.buffer.asUint8List();
}

String _extractSignerName(Uint8List p12Bytes, String password) {
  try {
    final certPemStrings = Pkcs12Utils.parsePkcs12(p12Bytes, password: password)
        .where((pem) => pem.contains('BEGIN CERTIFICATE'))
        .toList();

    if (certPemStrings.isEmpty) {
      return 'Firmante no identificado';
    }

    final List<Map<String, dynamic>> certDetails = [];
    for (int i = 0; i < certPemStrings.length; i++) {
      final details = _parseCertificateDetails(certPemStrings[i]);
      if (details != null) {
        certDetails.add(details);
      } else {
      }
    }

    if (certDetails.isEmpty) {
      return 'Firmante no identificado';
    }

    final issuers = certDetails.map((details) => details['issuerDN']).toSet();

    Map<String, dynamic>? endEntityCert;
    for (final details in certDetails) {
      if (!issuers.contains(details['subjectDN'])) {
        endEntityCert = details;
        break;
      }
    }

    if (endEntityCert != null) {
      final signerName = endEntityCert['cn'] ?? 'Firmante no identificado';
      return signerName;
    }
    
    final fallbackName = certDetails.first['cn'] ?? 'Firmante no identificado';
    return fallbackName;

  } catch (e) {
    return 'Firmante no identificado';
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
    const oidToName = {
      '2.5.4.3': 'CN',
      '2.5.4.6': 'C',
      '2.5.4.7': 'L',
      '2.5.4.8': 'ST',
      '2.5.4.10': 'O',
      '2.5.4.11': 'OU',
      '1.2.840.113549.1.9.1': 'emailAddress',
    };
    
    for (var element in dnSequence.elements) {
      try {
        if (element is ASN1Set && element.elements.isNotEmpty) {
          final seq = element.elements.first;
          if (seq is ASN1Sequence && seq.elements.length >= 2) {
            final oid = seq.elements[0];
            final value = seq.elements[1];
            
            if (oid is ASN1ObjectIdentifier) {
              final oidName = oidToName[oid.identifier] ?? oid.identifier;
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

void _drawSignatureAppearance(PdfGraphics graphics, Uint8List qrBytes, String signerName, Size size) {
  final qrImage = PdfBitmap(qrBytes);
  
  // Tamaño del QR
  const qrSize = Size(60, 60);
  const textSpacing = 10.0;
  
  // 1. Dibujar QR a la izquierda (Coordenadas relativas al campo de firma)
  graphics.drawImage(qrImage, Rect.fromLTWH(0, 0, qrSize.width, qrSize.height));

  // 2. Dibujar texto a la derecha
  final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 6);
  final nameFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
  
  final textStartX = qrSize.width + textSpacing;
  
  // Etiqueta superior
  graphics.drawString(
    'Firmado electrónicamente por:',
    labelFont,
    bounds: Rect.fromLTWH(textStartX, 8, 200, 10),
    brush: PdfBrushes.black,
  );
  
  // Nombre del firmante (en negrita)
  graphics.drawString(
    signerName,
    nameFont,
    bounds: Rect.fromLTWH(textStartX, 18, 220, 40), 
    brush: PdfBrushes.black,
    format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.top, wordWrap: PdfWordWrapType.word),
  );
}

void _applyDigitalSignature(
  PdfDocument document,
  Uint8List p12Bytes,
  String password,
  int pageIndex,
  double pdfX,
  double pdfY,
  Uint8List qrBytes,
  String signerName,
) {
  const qrSize = Size(60, 60);
  // Ancho total estimado: QR (60) + Espacio (10) + Texto (~200) = ~270
  // Alto: ~60
  const signatureSize = Size(270, 60);
  
  final certificate = PdfCertificate(p12Bytes, password);

  final signature = PdfSignature(
    certificate: certificate,
    digestAlgorithm: DigestAlgorithm.sha256,
    cryptographicStandard: CryptographicStandard.cades,
  );
  
  // LTV (Long Term Validation) y Timestamp
  // La implementación de Syncfusion tiene limitaciones con LTV.
  // Se ha movido la lógica LTV al lado nativo (Android/Kotlin con iText).
  // Por lo tanto, no intentamos habilitar LTV aquí para evitar errores.
  
  // NOTE: Previamente aquí se intentaba signature.createLongTermValidity(chain);
  // lo cual causaba errores "Too many positional arguments" o fallos en runtime.
  

  final field = PdfSignatureField(
    document.pages[pageIndex],
    'SoloFirmaSignature_${DateTime.now().millisecondsSinceEpoch}',
    bounds: Rect.fromLTWH(pdfX, pdfY, signatureSize.width, signatureSize.height),
    signature: signature,
  );

  // DIBUJAR APARIENCIA DENTRO DEL CAMPO
  _drawSignatureAppearance(field.appearance.normal.graphics!, qrBytes, signerName, signatureSize);

  document.form.fields.add(field);
}

Future<File> _saveSignedPdf(String originalPath, PdfDocument document) async {
  try {
    final signedBytes = await document.save();
    
    final signedPath = originalPath.replaceAll('.pdf', '-firmado.pdf');
    final signedFile = File(signedPath);
    await signedFile.writeAsBytes(signedBytes);

    return signedFile;
  } finally {
    document.dispose();
  }
}