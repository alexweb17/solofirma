import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solofirma/screens/signing_success_screen.dart';
import 'package:solofirma/services/signing_services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  final File pdfFile;

  const PdfPreviewScreen({super.key, required this.pdfFile});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfDocument? _pdfDocument;

  Offset? _signaturePosition;
  Offset? _guideBoxPosition;
  bool _isSigning = false;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final doc = PdfDocument(inputBytes: await widget.pdfFile.readAsBytes());
    if (mounted) {
      setState(() {
        _pdfDocument = doc;
      });
    }
  }

  Future<void> _signDocument() async {
    if (_signaturePosition == null || _pdfDocument == null) return;

    setState(() {
      _isSigning = true;
    });

    try {
      final signingService = SigningService();

      final signedFile = await signingService.signPdf(
        widget.pdfFile,
        _signaturePosition!,
        _currentPageIndex,
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
        title: const Text('Toque para ubicar la firma'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: (_signaturePosition == null || _isSigning || _pdfDocument == null) ? null : _signDocument,
          ),
        ],
      ),
      body: _pdfDocument == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SfPdfViewer.file(
                  widget.pdfFile,
                  controller: _pdfViewerController,
                  onPageChanged: (PdfPageChangedDetails details) {
                    setState(() {
                      _currentPageIndex = details.newPageNumber - 1;
                      _signaturePosition = null; // Reset signature position on page change
                      _guideBoxPosition = null;
                    });
                  },
                  onTap: (PdfGestureDetails details) {
                    setState(() {
                      _signaturePosition = details.pagePosition;
                      _guideBoxPosition = details.position;
                    });
                  },
                ),
                if (_guideBoxPosition != null)
                  Positioned(
                    left: _guideBoxPosition!.dx,
                    top: _guideBoxPosition!.dy,
                    child: Container(
                      width: 180,  // Proporcional a 270pt en el PDF
                      height: 47,  // Proporcional a 70pt en el PDF
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.blue.withOpacity(0.15),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Icon(Icons.qr_code_2, size: 36, color: Colors.blue.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Firma aquí',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
