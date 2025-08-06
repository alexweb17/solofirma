import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoloFirma - Principal'),
        // Esto evita que el usuario pueda volver a la pantalla de importación
        automaticallyImplyLeading: false, 
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 100),
            SizedBox(height: 20),
            Text(
              '¡Certificado configurado!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            // Aquí irá la lista de documentos para firmar
            Text('Listo para firmar documentos.'),
          ],
        ),
      ),
    );
  }
}
