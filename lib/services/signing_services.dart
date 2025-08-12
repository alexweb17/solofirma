import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 1. Importamos el paquete del QR
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'credential_services.dart';

class SigningService {
  final _credentialService = CredentialService();

  Future<File?> signPdf(File originalPdf, Offset signaturePosition) async {
    try {
      // --- PASOS 1 Y 2: OBTENER CREDENCIALES Y CARGAR PDF (SIN CAMBIOS) ---
      print('Recuperando credenciales...');
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

      // --- PASO 3: GENERAR LA IMAGEN DEL QR ---
      print('Generando imagen del QR...');
      // Datos que irán en el QR (puedes personalizarlos)
      const qrData = 'Documento Firmado por SoloFirma'; 
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
      ).toImageData(200); // Tamaño de la imagen

      if (qrImage == null) {
        throw Exception('No se pudo generar la imagen del QR.');
      }
      final Uint8List qrImageBytes = qrImage.buffer.asUint8List();
      final PdfBitmap pdfQrImage = PdfBitmap(qrImageBytes);
      print('Imagen del QR generada.');

      // --- PASO 4: DIBUJAR EL QR EN EL PDF ---
      print('Dibujando QR en el PDF...');
      final page = document.pages[0]; // Trabajamos en la primera página
      final signatureSize = const Size(75, 75); // Tamaño del QR en el PDF
      final signatureBounds = Rect.fromLTWH(
        signaturePosition.dx,
        signaturePosition.dy,
        signatureSize.width,
        signatureSize.height,
      );
      // Dibujamos la imagen del QR en la página
      page.graphics.drawImage(pdfQrImage, signatureBounds);
      print('QR dibujado en la posición: $signaturePosition');

      // --- PASO 5: CREAR Y APLICAR LA FIRMA DIGITAL (INVISIBLE) ---
      final PdfSignatureField field = PdfSignatureField(
        page,
        'SoloFirmaSignature',
        bounds: signatureBounds, // La firma invisible ocupa el mismo espacio que el QR
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
