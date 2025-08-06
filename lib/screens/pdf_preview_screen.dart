import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  final File pdfFile;

  const PdfPreviewScreen({super.key, required this.pdfFile});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  // Esta variable guardará la posición (x, y) de tu toque.
  Offset? _signaturePosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toque para ubicar la firma'),
        actions: [
          // Botón para confirmar la firma
          IconButton(
            icon: const Icon(Icons.check),
            // El botón solo se activa si ya has tocado la pantalla
            onPressed: _signaturePosition == null
                ? null
                : () {
                    // Lógica para firmar usando la posición guardada
                    print('Posición de la firma seleccionada: $_signaturePosition');
                    // Próximo paso: Generar QR y estamparlo aquí
                  },
          ),
        ],
      ),
      // Usamos un Stack para poder poner el marcador ENCIMA del PDF
      body: Stack(
        children: [
          // Este detector de gestos envuelve al visor y escucha tus toques
          GestureDetector(
            onTapUp: (details) {
              // Cuando tocas, guardamos la posición y redibujamos la pantalla
              setState(() {
                _signaturePosition = details.localPosition;
              });
            },
            child: SfPdfViewer.file(
              widget.pdfFile,
            ),
          ),
          // Este es el marcador visual. Solo aparece si ya has tocado la pantalla.
          if (_signaturePosition != null)
            Positioned(
              // Usamos las coordenadas guardadas para posicionarlo
              left: _signaturePosition!.dx - 25,
              top: _signaturePosition!.dy - 25,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                  color: Colors.red.withOpacity(0.2),
                ),
                child: const Icon(Icons.add, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
