import 'package:flutter/material.dart';
import 'package:solofirma/screens/import_certificate_screen.dart';
void main() {
  runApp(const SoloFirmaApp());
}

class SoloFirmaApp extends StatelessWidget {
  const SoloFirmaApp({super.key});
@override
Widget build(BuildContext context) {
  // MaterialApp es el widget principal que le da a nuestra app
  // la apariencia y funcionalidades básicas de Material Design.
  return MaterialApp(
    title: 'SoloFirma',
    // Desactivamos la cinta de "DEBUG" en la esquina.
    debugShowCheckedModeBanner: false, 
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    // 'home' define la primera pantalla que se mostrará.
    // Esta es la forma correcta y limpia.
    home: const ImportCertificateScreen(),
  ); // <-- El paréntesis de MaterialApp se cierra aquí. No hay nada más.
}
  }
