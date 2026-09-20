import 'package:flutter/material.dart';
import 'services/local_vault.dart';

/// A device-local profile, never a cloud account or an identity provider.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.vault,
    required this.onGuest,
    required this.onUnlocked,
    required this.onCreate,
  });
  final LocalVault vault;
  final Future<void> Function() onGuest, onUnlocked;
  final Future<void> Function(String username, String password) onCreate;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      password = TextEditingController(),
      repeat = TextEditingController();
  bool busy = false, visible = false, creating = false;
  String? error;
  int failures = 0;
  DateTime? retryAt;
  @override
  void initState() {
    super.initState();
    creating = !widget.vault.hasProfile;
    username.text = widget.vault.username;
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (retryAt?.isAfter(DateTime.now()) ?? false) {
      setState(
        () => error = 'Espera unos segundos antes de intentarlo otra vez.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (creating) {
        await widget.onCreate(username.text.trim(), password.text);
      } else if (await widget.vault.unlock(username.text, password.text)) {
        await widget.onUnlocked();
      } else {
        failures++;
        if (failures >= 3) {
          retryAt = DateTime.now().add(const Duration(seconds: 15));
        }
        if (mounted) {
          setState(() => error = 'El usuario o la contraseña no coinciden.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          creating = !widget.vault.hasProfile;
          error =
              'No se pudo completar el acceso. Tus datos no se han borrado. Revisa tu contraseña y vuelve a intentar.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      creating
                          ? 'Tu hogar, a tu manera.'
                          : 'Bienvenido a casa.',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      creating
                          ? 'Organiza tu despensa, cocina rico y haz espacio para lo importante.'
                          : 'Desbloquea tu perfil local de Foráneo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: username,
                      enabled: !busy,
                      maxLength: 80,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 3
                          ? 'Usa al menos 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: !visible,
                      autofillHints: [
                        creating
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: creating
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!creating) submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        helperText: creating
                            ? 'Mínimo 10 caracteres. No existe recuperación en línea.'
                            : null,
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: visible
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) < (creating ? 10 : 1)
                          ? (creating
                                ? 'Usa al menos 10 caracteres'
                                : 'Escribe tu contraseña')
                          : null,
                    ),
                    if (creating) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: repeat,
                        enabled: !busy,
                        obscureText: !visible,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                          labelText: 'Repetir contraseña',
                        ),
                        validator: (v) => v != password.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              creating
                                  ? 'Crear perfil local'
                                  : 'Iniciar sesión',
                            ),
                    ),
                    if (!widget.vault.hasProfile) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                await widget.onGuest();
                                if (mounted) setState(() => busy = false);
                              },
                        child: const Text('Continuar sin cuenta'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Sin API, pagos ni cuentas en la nube. El perfil cifra los datos de este dispositivo. Tu contraseña no se envía a ningún servidor. Conserva un respaldo: si olvidas la contraseña, no podemos recuperarla.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'by Joseph Ubaldo Trejo Hernandez',
                      style: TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
