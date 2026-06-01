import 'dart:convert';
import 'package:crypto/crypto.dart';

Future<String?> getEmailSha256(email) async {

    final bytes = utf8.encode(email);

    // Calculamos el SHA-256
    final digest = sha256.convert(bytes);

    // Lo devolvemos como string hexadecimal
    return digest.toString();
}