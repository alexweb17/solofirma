import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// 1. IMPORTAMOS LA NUEVA PANTALLA
import 'home_screen.dart'; 
// Importamos el servicio que creamos
import '../services/credential_services.dart';

class ImportCertificateScreen extends StatefulWidget {
  const ImportCertificateScreen({super.key});

  @override
  State<ImportCertificateScreen> createState() =>
      _ImportCertificateScreenState();
}

class _ImportCertificateScreenState extends State<ImportCertificateScreen> {
  final _credentialService = CredentialService();

  Future<void> _showPasswordDialog(String filePath) async {
    if (!mounted) return;

    final passwordController = TextEditingController();

    // Usamos un context diferente para el diálogo para evitar confusiones
    return showDialog<void>(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        return AlertDialog(
          title: const Text('Contraseña del Certificado'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                    'Por favor, ingresa la contraseña de tu archivo .p12.'),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true, 
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Contraseña',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              child: const Text('Guardar'),
              onPressed: () async { // 1. Convertir la función a async
                final password = passwordController.text;
                // Capturamos el Navigator y ScaffoldMessenger ANTES de la operación asíncrona
                // para evitar advertencias del linter.
                final navigator = Navigator.of(context);
                final dialogNavigator = Navigator.of(dialogContext);

                try {
                  // 2. Esperar a que la operación de guardado termine
                  await _credentialService.saveCredentials(password, filePath);

                  // 3. Si todo va bien, cerramos el diálogo y navegamos
                  dialogNavigator.pop();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (Route<dynamic> route) => false,
                  );

                } catch (e) {
                  // 4. Si hay un error, lo mostramos y permanecemos en el diálogo
                  dialogNavigator.pop(); // Cerramos el diálogo de contraseña
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _pickCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['p12'], 
      );

      if (!mounted) return;

      if (result != null) {
        String? filePath = result.files.single.path;
        if (filePath != null) {
          _showPasswordDialog(filePath);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ningún archivo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar el archivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // El resto del código de la UI no necesita cambios.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Certificado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 24),
              const Text(
                'Para empezar, importa tu certificado digital.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu certificado (.p12) y tu contraseña nunca saldrán de tu dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Seleccionar Archivo .p12'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: _pickCertificate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
