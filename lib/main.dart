import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solofirma/screens/home_screen.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final CredentialService _credentialService = CredentialService();

  Future<bool> _areCredentialsValid() async {
    final credentials = await _credentialService.getCredentials();
    final path = credentials['path'];

    if (path == null) {
      return false;
    }

    final file = File(path);
    return await file.exists();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _areCredentialsValid(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error al verificar credenciales')),
          );
        }

        final bool isValid = snapshot.data ?? false;
        return isValid ? const HomeScreen() : const ImportCertificateScreen();
      },
    );
  }
}
