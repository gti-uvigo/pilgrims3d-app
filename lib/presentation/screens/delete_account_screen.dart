// lib/screens/delete_account_page.dart

import 'package:flutter/material.dart';
import 'package:mailto/mailto.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Constants for String Literals ---
class AppStrings {
  static const String pageTitle = 'Solicitar eliminación de cuenta';
  static const String instructions =
      'Envía tu solicitud a los administradores para eliminar tu cuenta. Recibirás confirmación por correo una vez procesada.';
  static const String emailLabel = 'Correo electrónico asociado a la cuenta';
  static const String reasonLabel = 'Motivo de la solicitud (opcional)';
  static const String messageLabel = 'Mensaje al administrador';
  static const String requiredField = 'Campo obligatorio';
  static const String invalidEmail = 'Introduce un correo válido';
  static const String messageRequired = 'Escribe un mensaje';
  static const String confirmationText =
      'Confirmo que deseo eliminar mi cuenta y entiendo que esta acción puede ser irreversible.';
  static const String sendButtonText = 'Enviar solicitud';
  static const String emailRecipient = 'jbeiro@gti.uvigo.es';
  static const String emailSubject = 'Solicitud de eliminación de cuenta';
  static const String snackbarError = 'No se pudo abrir el cliente de correo.';
}

// --- Reusable Confirmation Widget ---
class ConfirmationCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String text;

  const ConfirmationCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}

// --- Main Page Widget ---
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController();
  final _messageController = TextEditingController();
  bool _confirmDelete = false;

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Basic email validation regex
  String? _emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.requiredField;
    }
    // Simple regex for email structure
    const pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return AppStrings.invalidEmail;
    }
    return null;
  }

  Future<void> _sendEmail() async {
    // 1. Validate form fields
    if (!_formKey.currentState!.validate()) return;
    
    // 2. Check confirmation checkbox
    if (!_confirmDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, confirma que deseas eliminar la cuenta.')),
      );
      return;
    }

    // 3. Construct email body
    final mailtoBody = '''
Hola equipo de soporte,

Solicito la eliminación de mi cuenta.

Correo asociado: ${_emailController.text}
Motivo: ${_reasonController.text.isEmpty ? 'No especificado' : _reasonController.text}

Mensaje adicional:
${_messageController.text}

Gracias.
''';

    final mailtoLink = Mailto(
      to: [AppStrings.emailRecipient],
      subject: AppStrings.emailSubject,
      body: mailtoBody,
    );

    // 4. Launch email client
    final Uri emailUri = Uri.parse(mailtoLink.toString());
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.snackbarError)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.snackbarError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.pageTitle),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                AppStrings.instructions,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: AppStrings.emailLabel,
                  border: OutlineInputBorder(),
                ),
                validator: _emailValidator,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // Reason Field
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: AppStrings.reasonLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Message Field
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: AppStrings.messageLabel,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) =>
                    value == null || value.isEmpty ? AppStrings.messageRequired : null,
              ),
              const SizedBox(height: 20),
              
              // Confirmation Checkbox
              ConfirmationCheckbox(
                value: _confirmDelete,
                onChanged: (v) => setState(() => _confirmDelete = v ?? false),
                text: AppStrings.confirmationText,
              ),

              const SizedBox(height: 20),
              
              // Send Button
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text(AppStrings.sendButtonText),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: _sendEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}