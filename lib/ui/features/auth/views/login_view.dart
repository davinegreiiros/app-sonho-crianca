import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/animations/pressable.dart';
import '../view_models/login_cubit.dart';
import '../view_models/login_state.dart';

/// Tela de login de operador (spec 024-sync-backend-fundacao) — única
/// porta de entrada pra `BusinessSettingsView` (guarda em
/// `openBusinessSettingsScreen`, `lib/widgets/modal_launchers.dart`).
/// `Navigator.pop(true)` no sucesso; `pop(false)`/`pop()` se o operador
/// voltar sem logar — quem chamou decide o que fazer com o resultado.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(context.read()),
      child: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.sucesso) {
            Navigator.of(context).pop(true);
          }
        },
        builder: (context, state) {
          final loading = state.status == LoginStatus.loading;
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Pressable(
                      child: InkWell(
                        key: TestKeys.loginBackButton,
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(false),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.accent700),
                              SizedBox(width: 6),
                              Text('Voltar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.accent700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Entrar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.05)),
                    const SizedBox(height: 4),
                    Text(
                      'Login de operador — necessário pra configurar o negócio.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.68)),
                    ),
                    const SizedBox(height: 24),
                    if (state.errorMessage != null) ...[
                      _ErrorBanner(message: state.errorMessage!, status: state.status),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      key: TestKeys.loginUsernameField,
                      controller: _usernameCtrl,
                      enabled: !loading,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration('Usuário'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: TestKeys.loginPasswordField,
                      controller: _passwordCtrl,
                      enabled: !loading,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: _fieldDecoration('Senha'),
                      onSubmitted: (_) => _submit(context),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Pressable(
                        child: ElevatedButton(
                          key: TestKeys.loginSubmitButton,
                          onPressed: loading ? null : () => _submit(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.bg,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                                )
                              : const Text('Entrar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    context.read<LoginCubit>().submit(_usernameCtrl.text, _passwordCtrl.text);
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.4)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
      );
}

/// Cor por tipo de erro — cenários 3/6 do spec exigem mensagem distinta
/// pra credencial errada vs. sem conexão, não só texto diferente.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.status});

  final String message;
  final LoginStatus status;

  @override
  Widget build(BuildContext context) {
    final isNetwork = status == LoginStatus.semConexao;
    final bg = isNetwork ? AppColors.yellowTint : AppColors.accent2_100;
    final fg = isNetwork ? AppColors.yellowFgDark : AppColors.accent2_700;
    return Container(
      key: TestKeys.loginErrorText,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12.5, color: fg))),
        ],
      ),
    );
  }
}
