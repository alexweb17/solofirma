import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solofirma/screens/home_screen.dart';
// Usamos el nombre de tu pantalla de importación
import 'package:solofirma/screens/import_certificate_screen.dart';
import 'package:solofirma/services/credential_services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoloFirma',
      // He mantenido tu tema original
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // La lógica de arranque ahora vive en esta pantalla de verificación
      home: const AuthCheckScreen(),
    );
  }
}

// Esta pantalla de verificación es la clave para la robustez.
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final CredentialService _credentialService = CredentialService();

  // Esta función es más segura: no solo comprueba si la ruta está guardada,
  // sino que también comprueba si el archivo REALMENTE existe en esa ruta.
  Future<bool> _areCredentialsValid() async {
    final credentials = await _credentialService.getCredentials();
    final path = credentials['path'];

    if (path == null) {
      // Si no hay ruta guardada, no hay nada que hacer.
      return false;
    }

    // El paso extra de seguridad: ¿existe el archivo en el disco?
    final file = File(path);
    return await file.exists();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _areCredentialsValid(),
      builder: (context, snapshot) {
        // Mientras espera, muestra una pantalla de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si hubo un error
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error al verificar credenciales')),
          );
        }

        // Una vez que tenemos la respuesta...
        final bool isValid = snapshot.data ?? false;

        // Si las credenciales son válidas, vamos a HomeScreen.
        // Si no, vamos a tu pantalla de importación.
        return isValid ? const HomeScreen() : const ImportCertificateScreen();
      },
    );
  }
}
