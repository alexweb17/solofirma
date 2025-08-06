import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Necesario para la clase Rect
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'credential_services.dart';

class SigningService {
  final _credentialService = CredentialService();

  /// Firma un documento PDF utilizando las credenciales guardadas y el motor de Syncfusion.
  Future<File?> signPdf(File originalPdf) async {
    try {
      // 1. Obtener credenciales seguras
      print('Recuperando credenciales...');
      final credentials = await _credentialService.getCredentials();
      final password = credentials['password'];
      final p12Path = credentials['path'];

      if (password == null || p12Path == null) {
        print('Error: No se encontraron las credenciales del certificado.');
        return null;
      }
      print('Credenciales recuperadas.');

      final p12File = File(p12Path);
      if (!await p12File.exists()) {
        print('Error: El archivo del certificado no se encuentra en la ruta guardada.');
        return null;
      }

      // Leemos los bytes del PDF y del certificado
      final Uint8List pdfBytes = await originalPdf.readAsBytes();
      final Uint8List p12Bytes = await p12File.readAsBytes();

      // 2. Cargar el documento PDF con el motor de Syncfusion
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

      // 3. Crear la firma digital
      final PdfSignatureField field = PdfSignatureField(
        document.pages[0], // Firmamos en la primera página
        'SoloFirmaSignature',
        bounds: const Rect.fromLTWH(0, 0, 0, 0), // Rectángulo invisible por ahora
        signature: PdfSignature(
          certificate: PdfCertificate(p12Bytes, password),
          contactInfo: 'firmado@solofirma.app',
          reason: 'Firmado digitalmente con SoloFirma',
          locationInfo: 'Ecuador'
        ),
      );

      // Añadimos el campo de firma al documento
      document.form.fields.add(field);

      // 4. Guardar el documento firmado y liberar memoria
      final List<int> signedBytes = await document.save();
      document.dispose();

      // 5. Escribir los bytes en un nuevo archivo
      final signedPdfPath = originalPdf.path.replaceAll('.pdf', '-firmado.pdf');
      final signedFile = File(signedPdfPath);
      await signedFile.writeAsBytes(signedBytes);

      print('PDF firmado con éxito usando Syncfusion en: $signedPdfPath');
      return signedFile;

    } on Exception catch (e) {
      print('Error al firmar el documento: $e');
      return null;
    }
  }
}
