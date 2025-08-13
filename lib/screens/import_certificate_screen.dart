import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:solofirma/services/credential_services.dart';
import 'package:solofirma/screens/home_screen.dart';

class ImportCertificateScreen extends StatefulWidget {
  const ImportCertificateScreen({super.key});

  @override
  State<ImportCertificateScreen> createState() => _ImportCertificateScreenState();
}

class _ImportCertificateScreenState extends State<ImportCertificateScreen> {
  final _passwordController = TextEditingController();
  final _credentialService = CredentialService();
  bool _isLoading = false;

  /// Orquesta el proceso de seleccionar un p12, pedir contraseña y guardarlo.
  void _importCertificate() async {
    // 1. Seleccionar el archivo .p12
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12'],
    );

    if (result != null && result.files.single.path != null) {
      final p12File = File(result.files.single.path!);

      // Si el widget sigue "montado", pedimos la contraseña
      if (!mounted) return;

      // 2. Pedir la contraseña en un diálogo
      final String? password = await _showPasswordDialog();

      if (password != null && password.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        // 3. Guardar las credenciales de forma segura
        try {
          // **CAMBIO CLAVE: Pasamos el objeto File, no la ruta. Asumimos que saveCredentials fue actualizado para recibir un File.**
          // Si tu CredentialService espera un String, la línea sería:
          // await _credentialService.saveCredentials(password, p12File.path);
          await _credentialService.saveCredentials(password, p12File.path);
          
          if (!mounted) return;
          // Navegamos a la pantalla principal si todo fue exitoso
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );

        } catch (e) {
          // Manejo de errores
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al guardar credenciales: $e')),
            );
          }
        }
      }
    }
  }

  /// Muestra un diálogo para que el usuario ingrese la contraseña del certificado.
  Future<String?> _showPasswordDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contraseña del Certificado'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Ingrese la contraseña de su archivo .p12',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_passwordController.text);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CAMBIO: Fondo blanco
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Importar Firma Electronica'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CAMBIO: Se reemplaza el Icon por tu logo
              Image.asset(
                'assets/logo.png', // Asegúrate de que esta ruta sea correcta
                height: 120,
              ),
              const SizedBox(height: 40),
              // CAMBIO: Nuevo texto de bienvenida
              const Text(
                'Bienvenido a SoloFirma',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'Tu Firma Electronica (archivo.p12) y tu contraseña nunca saldrán de tu dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),
              // El botón se mantiene igual
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Seleccionar Archivo .p12'),
                  onPressed: _importCertificate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
