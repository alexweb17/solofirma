import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solofirma/screens/signing_success_screen.dart';
import 'package:solofirma/services/signing_services.dart';
import 'package:solofirma/widgets/draggable_signature_box.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  final File pdfFile;

  const PdfPreviewScreen({super.key, required this.pdfFile});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Offset? _signaturePosition;
  bool _isSigning = false;

  final PdfViewerController _pdfViewerController = PdfViewerController();
  Size? _pdfViewSize;
  // ***** CAMBIO 1: Variable de estado para la página actual *****
  int _currentPageIndex = 0;

  Future<void> _signDocument() async {
    if (_signaturePosition == null || _pdfViewSize == null) return;

    setState(() {
      _isSigning = true;
    });

    try {
      final signingService = SigningService();

      // ***** CAMBIO 2: Usamos nuestra variable de estado, que es más precisa *****
      final signedFile = await signingService.signPdf(
        widget.pdfFile,
        _signaturePosition!,
        _pdfViewSize!,
        _currentPageIndex, // <-- Usamos la variable de estado
      );

      if (signedFile != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SigningSuccessScreen(signedPdfFile: signedFile),
          ),
        );
      } else {
        throw Exception('No se pudo firmar el archivo.');
      }
    } catch (e) {
      setState(() {
        _isSigning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al firmar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubique el área de la firma'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: (_signaturePosition == null || _isSigning) ? null : _signDocument,
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              _pdfViewSize = constraints.biggest;
              
              return SfPdfViewer.file(
                widget.pdfFile,
                controller: _pdfViewerController,
                // ***** CAMBIO 3: Escuchamos cuando el usuario cambia de página *****
                onPageChanged: (PdfPageChangedDetails details) {
                  // Actualizamos nuestra variable de estado.
                  // Restamos 1 porque el visor cuenta desde 1, y nosotros desde 0.
                  setState(() {
                    _currentPageIndex = details.newPageNumber - 1;
                  });
                },
              );
            },
          ),
          DraggableSignatureBox(
            onPositionChanged: (position) {
              setState(() {
                _signaturePosition = position;
              });
            },
          ),
          if (_isSigning)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
