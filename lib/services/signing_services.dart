import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'credential_services.dart';

class SigningService {
  final _credentialService = CredentialService();

  Future<File?> signPdf(File originalPdf, Offset signaturePosition) async {
    try {
      // --- PASOS 1 Y 2: OBTENER CREDENCIALES Y CARGAR PDF (SIN CAMBIOS) ---
      final credentials = await _credentialService.getCredentials();
      final password = credentials['password'];
      final p12Path = credentials['path'];

      if (password == null || p12Path == null) {
        throw Exception('No se encontraron las credenciales del certificado.');
      }
      final p12File = File(p12Path);
      final Uint8List pdfBytes = await originalPdf.readAsBytes();
      final Uint8List p12Bytes = await p12File.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

      // --- PASO 3: GENERAR LA IMAGEN DEL QR (SIN CAMBIOS) ---
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

      // --- PASO 4: DIBUJAR EL QR EN EL PDF (SIN CAMBIOS) ---
      final page = document.pages[0];
      final signatureSize = const Size(75, 75);
      final signatureBounds = Rect.fromLTWH(
        signaturePosition.dx,
        signaturePosition.dy,
        signatureSize.width,
        signatureSize.height,
      );
      page.graphics.drawImage(pdfQrImage, signatureBounds);

      // --- PASO 5: CREAR Y APLICAR LA FIRMA DIGITAL ---
      // **CAMBIO CLAVE: Generamos un nombre de campo único cada vez.**
      final String signatureFieldName = 'SoloFirmaSignature_${DateTime.now().millisecondsSinceEpoch}';

      final PdfSignatureField field = PdfSignatureField(
        page,
        signatureFieldName, // <-- Usamos el nombre único
        bounds: signatureBounds,
        signature: PdfSignature(
          certificate: PdfCertificate(p12Bytes, password),
          contactInfo: 'firmado@solofirma.app',
          reason: 'Firmado digitalmente con SoloFirma',
          locationInfo: 'Ecuador',
        ),
      );
      document.form.fields.add(field);

      // --- PASO 6: GUARDAR EL NUEVO DOCUMENTO (SIN CAMBIOS) ---
      final List<int> signedBytes = await document.save();
      document.dispose();
      final signedPdfPath = originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
      final signedFile = File(signedPdfPath);
      await signedFile.writeAsBytes(signedBytes);

      print('PDF firmado y estampado con éxito en: $signedPdfPath');
      return signedFile;

    } on Exception catch (e) {
      print('Error al firmar el documento: $e');
      return null;
    }
  }
}
