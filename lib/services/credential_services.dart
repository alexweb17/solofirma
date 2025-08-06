import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class CredentialService {
  final _secureStorage = const FlutterSecureStorage();

  /// Verifica si ya existen credenciales guardadas en el dispositivo.
  Future<bool> areCredentialsSaved() async {
    final path = await _secureStorage.read(key: 'user_p12_path');
    return path != null && path.isNotEmpty;
  }

  // --- NUEVA FUNCIÓN ---
  /// Recupera las credenciales guardadas de forma segura.
  /// Retorna un mapa con la contraseña y la ruta al archivo .p12.
  Future<Map<String, String?>> getCredentials() async {
    final password = await _secureStorage.read(key: 'user_p12_password');
    final path = await _secureStorage.read(key: 'user_p12_path');
    return {'password': password, 'path': path};
  }
  // --- FIN DE LA NUEVA FUNCIÓN ---

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
}
