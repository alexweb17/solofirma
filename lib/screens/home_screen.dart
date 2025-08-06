import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// Importamos la nueva pantalla de previsualización
import 'pdf_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  /// Orquesta el proceso de seleccionar un PDF y navegar a la previsualización.
  void _selectAndPreviewPdf() async {
    // 1. Seleccionar el PDF
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final pdfFile = File(result.files.single.path!);
      
      // Si el widget sigue "montado", navegamos a la pantalla de preview
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(pdfFile: pdfFile),
        ),
      );
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
        child: Column(
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
                  // Cambiamos el texto del botón para reflejar la nueva acción
                  label: const Text('Seleccionar PDF'),
                  // Llamamos a la nueva función
                  onPressed: _selectAndPreviewPdf,
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

