import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class CredentialService {
  final _secureStorage = const FlutterSecureStorage();

  // ESTA ES LA NUEVA FUNCIÓN
  /// Verifica si ya existen credenciales guardadas en el dispositivo.
  Future<bool> areCredentialsSaved() async {
    // Intentamos leer la ruta del certificado. Si existe y no está vacía,
    // asumimos que las credenciales están completas.
    final path = await _secureStorage.read(key: 'user_p12_path');
    return path != null && path.isNotEmpty;
  }

  /// Guarda la contraseña y el archivo P12 de forma segura
  Future<void> saveCredentials(String password, String originalP12Path) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = '${appDir.path}/cert.p12';
      final originalFile = File(originalP12Path);

      await originalFile.copy(newPath);

      await _secureStorage.write(key: 'user_p12_password', value: password);
      await _secureStorage.write(key: 'user_p12_path', value: newPath);
      
      print('¡Credenciales guardadas con éxito!');
      print('Certificado copiado a: $newPath');

    } catch (e) {
      print('ERROR al guardar las credenciales: $e');
    }
  }

  // (Aquí irían otras funciones como getCredentials, deleteCredentials, etc.)
}
