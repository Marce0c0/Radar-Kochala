import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ai_validation_service.dart';
import '../role/role_selection_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isVerifyingDoc = false;
  String _docType = 'ci'; // 'ci' o 'pasaporte'
  String _docVerificationStatus = 'none'; // 'none', 'verified', 'failed'
  List<int>? _docImageBytes;
  String? _docImagePath;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _documentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _docImageBytes = bytes;
      _docImagePath = picked.path;
      _docVerificationStatus = 'none';
    });
  }

  Future<void> _verifyDocumentWithAI() async {
    if (_docImageBytes == null) {
      _showError('Primero selecciona una foto de tu documento.');
      return;
    }
    if (_documentCtrl.text.trim().isEmpty) {
      _showError('Ingresa el número de documento antes de verificar.');
      return;
    }

    setState(() => _isVerifyingDoc = true);
    try {
      final docTypeName = _docType == 'ci' ? 'Cédula de Identidad boliviana' : 'Pasaporte';
      final result = await AiValidationService.verifyIdentityDocument(
        Uint8List.fromList(_docImageBytes!),
        docTypeName,
        _documentCtrl.text.trim(),
      );
      setState(() => _docVerificationStatus = result ? 'verified' : 'failed');
    } catch (e) {
      setState(() => _docVerificationStatus = 'failed');
      _showError('Error al verificar el documento: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingDoc = false);
    }
  }

  Future<void> _register() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final docNumber = _documentCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Ingresa un correo electrónico válido.');
      return;
    }
    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (phone.isEmpty) {
      _showError('El número de teléfono es obligatorio.');
      return;
    }
    if (docNumber.isEmpty) {
      _showError('El número de documento es obligatorio.');
      return;
    }
    if (_docType == 'ci' && (docNumber.length < 6 || docNumber.length > 10)) {
      _showError('La Cédula de Identidad debe tener entre 6 y 10 dígitos.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // Guardar datos de identidad en el perfil
        await Supabase.instance.client.from('profiles').update({
          'phone_number': phone,
          'document_type': _docType,
          'document_number': docNumber,
          'document_verified': _docVerificationStatus == 'verified',
        }).eq('id', res.user!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada exitosamente! Bienvenido.'),
              backgroundColor: AppTheme.teal,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionView()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      _showError(_translateError(e.message));
    } catch (e) {
      _showError('Error al registrarse. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateError(String msg) {
    if (msg.contains('already registered')) return 'Este correo ya está registrado.';
    if (msg.contains('Password should be at least')) return 'La contraseña debe tener al menos 6 caracteres.';
    return msg;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xffd9684b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta ciudadana', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Sección: Acceso ---
              _SectionTitle(icon: Icons.lock_outline, label: 'Datos de acceso'),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDeco('Correo electrónico', Icons.email_outlined, hint: 'tu@correo.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: _inputDeco('Contraseña', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Sección: Contacto ---
              _SectionTitle(icon: Icons.phone_outlined, label: 'Teléfono (WhatsApp / Contacto)'),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]'))],
                decoration: _inputDeco('Ej: +591 7XXXXXXX', Icons.phone_outlined),
              ),
              const SizedBox(height: 4),
              const Text('  Solo se usará para contactarte sobre tus reportes.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),

              // --- Sección: Documento de identidad ---
              _SectionTitle(icon: Icons.badge_outlined, label: 'Documento de identidad'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _DocTypeChip(
                    label: '🇧🇴 Cédula (CI)',
                    selected: _docType == 'ci',
                    onTap: () => setState(() { _docType = 'ci'; _docVerificationStatus = 'none'; }),
                  ),
                  const SizedBox(width: 10),
                  _DocTypeChip(
                    label: '🌎 Pasaporte',
                    selected: _docType == 'pasaporte',
                    onTap: () => setState(() { _docType = 'pasaporte'; _docVerificationStatus = 'none'; }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _documentCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z-]'))],
                decoration: _inputDeco(
                  _docType == 'ci' ? 'Número de Cédula (ej: 1234567)' : 'Número de Pasaporte',
                  Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 12),

              // Botón de foto del documento + verificación IA
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDocumentImage,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_docImageBytes == null ? 'Foto del documento (opcional)' : 'Cambiar foto'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.teal),
                        foregroundColor: AppTheme.teal,
                      ),
                    ),
                  ),
                  if (_docImageBytes != null) ...[
                    const SizedBox(width: 8),
                    _isVerifyingDoc
                        ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                        : FilledButton(
                            onPressed: _verifyDocumentWithAI,
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.teal),
                            child: const Text('Verificar'),
                          ),
                  ],
                ],
              ),

              // Estado de verificación de documento
              if (_docVerificationStatus == 'verified')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.verified, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Documento verificado por IA ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ]),
                )
              else if (_docVerificationStatus == 'failed')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(child: Text('La IA no pudo verificar el documento. Puedes continuar sin verificación.', style: TextStyle(color: Colors.red, fontSize: 12))),
                  ]),
                )
              else if (_docImageBytes != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Presiona "Verificar" para que la IA confirme tu documento.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    prefixIcon: Icon(icon),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.teal, size: 20),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.ink)),
  ]);
}

class _DocTypeChip extends StatelessWidget {
  const _DocTypeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.teal),
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.teal, fontWeight: FontWeight.w600)),
    ),
  );
}
