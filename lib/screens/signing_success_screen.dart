import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class SigningSuccessScreen extends StatefulWidget {
  final File signedPdfFile;

  const SigningSuccessScreen({super.key, required this.signedPdfFile});

  @override
  State<SigningSuccessScreen> createState() => _SigningSuccessScreenState();
}

class _SigningSuccessScreenState extends State<SigningSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Tan pronto como la pantalla se construye, se dispara la acción de compartir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareFile();
    });
  }

  // Función para abrir el diálogo nativo de compartir
  void _shareFile() {
    Share.shareXFiles(
      [XFile(widget.signedPdfFile.path)],
      text: 'Aquí está mi documento firmado con SoloFirma.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Documento Firmado!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu documento ha sido firmado digitalmente con éxito. Se está abriendo el diálogo para compartir o guardar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // Permite al usuario volver a la pantalla de inicio
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Volver al Inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
