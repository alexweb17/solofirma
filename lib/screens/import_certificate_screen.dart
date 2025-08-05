import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// ¡Aún no lo usamos, pero lo dejaremos listo para el siguiente paso!
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ImportCertificateScreen extends StatefulWidget {
  const ImportCertificateScreen({super.key});

  @override
  State<ImportCertificateScreen> createState() => _ImportCertificateScreenState();
}

class _ImportCertificateScreenState extends State<ImportCertificateScreen> {
  Future<void> _showPasswordDialog(String filePath) async {
    // La comprobación de seguridad se hace ANTES de mostrar el diálogo
    if (!mounted) return;

    final passwordController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contraseña del Certificado'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Por favor, ingresa la contraseña de tu archivo .p12.'),
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
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('Guardar'),
              onPressed: () {
                final password = passwordController.text;
                
                // 1. HEMOS QUITADO LOS PRINTS INSEGUROS
                // Aquí irá la lógica para guardar de forma segura
                
                Navigator.of(context).pop(); // Cierra el diálogo
                
                // 2. AÑADIMOS LA COMPROBACIÓN ANTES DE USAR EL CONTEXT
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Certificado y contraseña listos!')),
                );
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

      // 2. AÑADIMOS LA COMPROBACIÓN ANTES DE USAR EL CONTEXT
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
      // 2. AÑADIMOS LA COMPROBACIÓN ANTES DE USAR EL CONTEXT
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar el archivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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

