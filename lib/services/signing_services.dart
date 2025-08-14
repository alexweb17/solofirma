import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:basic_utils/basic_utils.dart';
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
  static const double _textMaxWidth = 150.0;
  static const String _defaultSignerName = 'Firmante no identificado';

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

  /// Calcular coordenadas de firma con validación
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

    double pdfX = signaturePosition.dx * pageSize.width / viewSize.width;
    double pdfY = pageSize.height - (signaturePosition.dy * pageSize.height / viewSize.height) - _qrSize.height;

    // Limitar dentro de la página
    pdfX = pdfX.clamp(0.0, pageSize.width - _qrSize.width).toDouble();
    pdfY = pdfY.clamp(0.0, pageSize.height - _qrSize.height - 25.0).toDouble(); // 25 para texto

    return _SignatureCoords(pdfX, pdfY);
  }

  /// Extraer nombre del firmante del P12 - VERSIÓN SIMPLIFICADA
  String _extractSignerName(Uint8List p12Bytes, String password) {
    try {
      // Usar Pkcs12Utils.parsePkcs12 para obtener los certificados PEM
      final certPemStrings = Pkcs12Utils.parsePkcs12(p12Bytes, password: password);
      
      if (certPemStrings.isEmpty) {
        print('No se encontraron certificados en el archivo P12');
        return _defaultSignerName;
      }

      // Buscar el nombre en cada certificado PEM usando expresiones regulares
      for (final certPem in certPemStrings) {
        if (certPem.contains('BEGIN CERTIFICATE')) {
          final name = _extractNameFromPem(certPem);
          if (name != _defaultSignerName) {
            return name;
          }
        }
      }

      return _defaultSignerName;
    } catch (e) {
      print('Error al extraer nombre del certificado: $e');
      return _defaultSignerName;
    }
  }

  /// Extraer nombre del certificado PEM usando RegExp (método auxiliar)
  String _extractNameFromPem(String certPem) {
    try {
      // Decodificar el certificado base64 para obtener los datos raw
      final base64Content = certPem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), '');
      
      final certBytes = base64.decode(base64Content);
      final certString = String.fromCharCodes(certBytes);
      
      // Buscar patrones comunes de nombres en certificados
      final patterns = [
        RegExp(r'CN=([^,/\n\r]+)', caseSensitive: false),  // Common Name
        RegExp(r'O=([^,/\n\r]+)', caseSensitive: false),   // Organization
        RegExp(r'OU=([^,/\n\r]+)', caseSensitive: false),  // Organizational Unit
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(certString);
        if (match != null) {
          final name = match.group(1);
          if (name != null && name.trim().isNotEmpty) {
            return _cleanSignerName(name);
          }
        }
      }
      
      return _defaultSignerName;
    } catch (e) {
      print('Error al procesar certificado PEM: $e');
      return _defaultSignerName;
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

  /// Dibujar QR y nombre centrado
  void _drawQrAndName(PdfPage page, PdfBitmap qrImage, String signerName, double pdfX, double pdfY) {
    // Dibujar QR
    page.graphics.drawImage(qrImage, Rect.fromLTWH(pdfX, pdfY, _qrSize.width, _qrSize.height));

    // Preparar el texto (truncar si es muy largo)
    final font = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
    String displayName = signerName;
    
    // Si el nombre es muy largo, truncarlo
    final maxCharacters = 25; // Aproximado para el ancho disponible
    if (displayName.length > maxCharacters) {
      displayName = '${displayName.substring(0, maxCharacters - 3)}...';
    }

    // Medir texto y centrar debajo del QR
    final textSize = font.measureString(displayName);
    final textX = pdfX + (_qrSize.width - textSize.width) / 2;
    final textY = pdfY + _qrSize.height + _textSpacing;

    // Asegurar que el texto no se salga de la página
    final finalTextX = textX.clamp(0.0, page.size.width - textSize.width).toDouble();

    page.graphics.drawString(
      displayName,
      font,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(finalTextX, textY, _textMaxWidth, 20),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center, 
        lineAlignment: PdfVerticalAlignment.top
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