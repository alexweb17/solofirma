import 'package:flutter/material.dart';
import 'package:solofirma/screens/home_screen.dart';
import 'package:solofirma/screens/import_certificate_screen.dart';
import 'package:solofirma/services/credential_services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Usamos un FutureBuilder para manejar la comprobación asíncrona
  final Future<bool> _areCredentialsSaved = CredentialService().areCredentialsSaved();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoloFirma',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // El FutureBuilder decide qué pantalla mostrar
      home: FutureBuilder<bool>(
        future: _areCredentialsSaved,
        builder: (context, snapshot) {
          // Mientras espera, muestra una pantalla de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Si hubo un error (poco probable aquí), muestra un error
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Error al verificar credenciales')),
            );
          }

          // Una vez que tenemos la respuesta...
          final bool isConfigured = snapshot.data ?? false;

          // Si está configurado, vamos a HomeScreen.
          // Si no, vamos a ImportCertificateScreen.
          return isConfigured ? const HomeScreen() : const ImportCertificateScreen();
        },
      ),
    );
  }
}
