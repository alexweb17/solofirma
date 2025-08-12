import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solofirma/screens/signing_success_screen.dart';
// ¡RUTA CORREGIDA! Ahora apunta al archivo en plural.
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
  bool _isSigning = false; // Variable para mostrar un indicador de carga

  // Función que se encarga de todo el proceso de firma
  Future<void> _signDocument() async {
    if (_signaturePosition == null) return;

    setState(() {
      _isSigning = true; // Muestra el indicador de carga
    });

    try {
      // Aquí instanciamos y usamos el servicio de firma que ya creamos
      final signingService = SigningService();
      // ¡IMPORTANTE! Necesitarás pasar la posición y el tamaño del cuadro
      // a tu servicio para que sepa dónde estampar el QR.
      final signedFile = await signingService.signPdf(widget.pdfFile, _signaturePosition!);

      if (signedFile != null && mounted) {
        // Si la firma fue exitosa, navegamos a la pantalla de éxito
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SigningSuccessScreen(signedPdfFile: signedFile),
          ),
        );
      } else {
        // Manejo de error si la firma falla
        throw Exception('No se pudo firmar el archivo.');
      }
    } catch (e) {
      // Si algo sale mal, mostramos un mensaje de error
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
          SfPdfViewer.file(
            widget.pdfFile,
          ),
          DraggableSignatureBox(
            onPositionChanged: (position) {
              setState(() {
                _signaturePosition = position;
              });
            },
          ),
          // Indicador de carga que se muestra mientras se firma
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
