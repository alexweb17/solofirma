import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:solofirma/screens/pdf_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupReceiveIntent();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupReceiveIntent() {
    // CASO 1: La app ya está abierta y recibe archivos compartidos
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen(_handleSharedFiles, onError: (err) {
      if (kDebugMode) {
        print("Error en getMediaStream: $err");
      }
    });

    // CASO 2: La app está cerrada y se abre con un archivo compartido
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedFiles);
  }

  void _handleSharedFiles(List<SharedMediaFile> sharedFiles) {
    if (sharedFiles.isNotEmpty) {
      // Buscar archivos PDF en los archivos compartidos
      final pdfFile = sharedFiles.firstWhere(
        (file) => file.path.toLowerCase().endsWith('.pdf'),
        orElse: () => sharedFiles.first, // Si no hay PDF, tomar el primero
      );
      
      if (pdfFile.path.toLowerCase().endsWith('.pdf')) {
        _navigateToPreview(pdfFile.path);
      } else {
        // Mostrar mensaje si no es un PDF
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solo se pueden abrir archivos PDF'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToPreview(String filePath) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(pdfFile: File(filePath)),
        ),
      );
    }
  }

  void _selectAndPreviewPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      _navigateToPreview(result.files.single.path!);
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
              label: const Text('Seleccionar PDF'),
              onPressed: _selectAndPreviewPdf,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}