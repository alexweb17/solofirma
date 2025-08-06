import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart'; 
import '../services/signing_services.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _signingService = SigningService();
  bool _isSigning = false;

  void _selectAndSignPdf() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    // CORRECCIÓN 1: Se mejora la comprobación de nulos para ser más segura.
    if (result != null && result.files.single.path != null) {
      // Para evitar la advertencia "don't use BuildContexts across async gaps",
      // capturamos el ScaffoldMessenger ANTES de la operación asíncrona de firma.
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final pdfToSign = File(result.files.single.path!);

      setState(() {
        _isSigning = true;
      });

      final signedPdf = await _signingService.signPdf(pdfToSign);

      // Después de una operación `await`, el widget podría haberse eliminado del árbol.
      // Siempre es seguro comprobar `mounted` antes de llamar a `setState` o usar el context.
      if (!mounted) return;

      setState(() {
        _isSigning = false;
      });

      if (signedPdf != null) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('¡PDF firmado con éxito!')));
        // CORRECCIÓN 2: Usamos 'Share' en lugar de 'SharePlus'.
        await Share.shareXFiles([XFile(signedPdf.path)], text: 'Documento firmado con SoloFirma');
      } else {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error: No se pudo firmar el PDF.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoloFirma - Principal'),
        automaticallyImplyLeading: false, 
      ),
      body: Center(
        child: _isSigning 
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf, size: 100, color: Colors.redAccent),
                const SizedBox(height: 30),
                const Text(
                  '¿Listo para firmar?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'Selecciona un documento PDF para aplicar tu firma digital.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Seleccionar PDF y Firmar'),
                  onPressed: _selectAndSignPdf,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16)
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
