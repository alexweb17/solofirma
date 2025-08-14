import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:x509/x509.dart';
import 'credential_services.dart';



class SigningService {
  final _credentialService = CredentialService();

  /// Convierte bytes DER a texto PEM
  String _derToPem(Uint8List derBytes) {
    final base64Cert = base64.encode(derBytes);
    final chunked = base64Cert.replaceAllMapped(
      RegExp(r'.{1,64}'),
      (match) => '${match.group(0)}\n',
    );
    return '-----BEGIN CERTIFICATE-----\n$chunked-----END CERTIFICATE-----\n';
  }

  /// Parsea un archivo PKCS#12 (.p12/.pfx) y devuelve el CN del certificado principal
  String _extractCommonNameFromP12(Uint8List p12Bytes, String password) {
    try {
      // Esta es una implementación manual para parsear. Es compleja.
      // Si en el futuro falla con otros certificados, considera volver a 'basic_utils'.
      final parser = ASN1Parser(p12Bytes);
      final topLevelSeq = parser.nextObject() as ASN1Sequence;

      for (var el in topLevelSeq.elements) {
        if (el is ASN1Sequence) {
          for (var subEl in el.elements) {
            if (subEl is ASN1Sequence) {
              try {
                // Convertimos este posible DER a PEM
                final pem = _derToPem(subEl.encodedBytes);
                final certs = parsePem(pem);
                if (certs.isNotEmpty) {
                  final cn = certs.first.subject['commonName'];
                  if (cn != null && cn.isNotEmpty) {
                    return cn; // Devuelve el primer Common Name que encuentre
                  }
                }
              } catch (_) {
                // No es un certificado válido en esta secuencia, se ignora y continúa la búsqueda.
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error al parsear el .p12: $e");
    }
    return "Firmante no identificado";
  }

  Future<File?> signPdf(
    File originalPdf,
    Offset signaturePosition,
    Size viewSize,
    int pageIndex,
  ) async {
    try {
      // --- OBTENCIÓN DE CREDENCIALES ---
      final credentials = await _credentialService.getCredentials();
      final password = credentials['password'];
      final p12Path = credentials['path'];

      if (password == null || p12Path == null) {
        throw Exception('No se encontraron las credenciales del certificado.');
      }

      final p12File = File(p12Path);
      if (!await p12File.exists()) {
        throw Exception(
          'El archivo de la firma electrónica no existe en la ruta: $p12Path',
        );
      }

      final Uint8List pdfBytes = await originalPdf.readAsBytes();
      final Uint8List p12Bytes = await p12File.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

      // --- GENERACIÓN DE QR ---
      const qrData = 'Documento Firmado por SoloFirma';
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
      ).toImageData(200);

      if (qrImage == null) {
        throw Exception('No se pudo generar la imagen del QR.');
      }
      final Uint8List qrImageBytes = qrImage.buffer.asUint8List();
      final PdfBitmap pdfQrImage = PdfBitmap(qrImageBytes);

      // --- CÁLCULO DE POSICIONES ---
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        throw Exception('El número de página no es válido.');
      }
      final PdfPage page = document.pages[pageIndex];
      final Size pageSize = page.size;
      const Size signatureQrSize = Size(60, 60);

      final double scaleX = pageSize.width / viewSize.width;
      final double scaleY = pageSize.height / viewSize.height;
      final double pdfX = signaturePosition.dx * scaleX;
      final double pdfY = pageSize.height -
          (signaturePosition.dy * scaleY) -
          (signatureQrSize.height + 20);

      final signatureBounds = Rect.fromLTWH(
        pdfX,
        pdfY + 20,
        signatureQrSize.width,
        signatureQrSize.height,
      );

      // Dibujamos el QR directamente en la página
      page.graphics.drawImage(pdfQrImage, signatureBounds);

      // --- EXTRAER CN DESDE .P12 ---
      final signerName = _extractCommonNameFromP12(p12Bytes, password);

      // Dibujamos el CN debajo del QR, directamente en la página
      page.graphics.drawString(
        signerName,
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(pdfX, pdfY, 150, 20),
      );

      // --- FIRMA DIGITAL ---
      final PdfCertificate certificate = PdfCertificate(p12Bytes, password);
      final String signatureFieldName =
          'SoloFirmaSignature_${DateTime.now().millisecondsSinceEpoch}';

      final Rect fieldBounds = Rect.fromLTWH(
        pdfX,
        pdfY,
        signatureQrSize.width,
        signatureQrSize.height + 20,
      );

      final PdfSignatureField field = PdfSignatureField(
        page,
        signatureFieldName,
        bounds: fieldBounds,
        signature: PdfSignature(
          certificate: certificate,
          contactInfo: 'firmado@solofirma.app',
          reason: 'Firmado digitalmente con SoloFirma',
          locationInfo: 'Ecuador',
        ),
      );

      // ***** CORRECCIÓN: ELIMINAR ESTA LÍNEA *****
      // Esta línea causaba ambos errores. Es innecesaria porque ya dibujamos
      // la apariencia (QR y texto) manualmente en la página.
      // field.signature.appearance.graphics = field.graphics;

      document.form.fields.add(field);

      // --- GUARDADO ---
      final List<int> signedBytes = await document.save();
      document.dispose();

      final String signedPdfPath =
          originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
      final File signedFile = File(signedPdfPath);
      await signedFile.writeAsBytes(signedBytes);

      print('PDF firmado en: $signedPdfPath');
      return signedFile;
    } on Exception catch (e) {
      print('Error al firmar el documento: $e');
      return null;
    }
  }
}
