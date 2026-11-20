import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/settings/presentation/cubit/animejoy_account_cubit.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_state.dart';
import 'package:iris/features/settings/presentation/widgets/settings_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class AnimejoyAccountSection extends StatelessWidget {
  const AnimejoyAccountSection({this.onSignIn, super.key});

  static const signInButtonKey = Key('settings_animejoy_sign_in_button');
  static const signOutButtonKey = Key('settings_animejoy_sign_out_button');
  static const verifyButtonKey = Key('settings_animejoy_verify_button');
  static const signInSheetKey = Key('animejoy_sign_in_sheet');
  static const loginFieldKey = Key('animejoy_login_field');
  static const passwordFieldKey = Key('animejoy_password_field');
  static const submitButtonKey = Key('animejoy_submit_button');

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<AnimejoyAccountCubit>();
    final state = context.watch<AnimejoyAccountCubit>().state;
    final failure = switch (state) {
      AnimejoyAccountSignedOut(:final failure) ||
      AnimejoyAccountSignedIn(:final failure) => failure,
      _ => null,
    };
    final errorMessage =
        failure == null || failure == AnimejoyAuthFailure.invalidCredentials
        ? null
        : _failureMessage(l10n, failure);
    final status = switch (state) {
      AnimejoyAccountInitial() || AnimejoyAccountChecking() =>
        SettingsStatus.loading(l10n.settingsCheckingSession),
      AnimejoyAccountSigningIn() => SettingsStatus.loading(
        l10n.settingsSigningIn,
      ),
      AnimejoyAccountSignedOut(:final expired) => SettingsStatus(
        errorMessage ??
            (expired
                ? l10n.settingsAnimejoyExpired
                : l10n.settingsAccountSignedOut),
        color: errorMessage == null ? null : scheme.error,
      ),
      AnimejoyAccountSignedIn(:final unverified) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unverified)
            SettingsStatus(
              l10n.settingsAnimejoyUnverified,
              leading: PixelIcon(
                PixelGlyph.markWarning,
                size: 14,
                color: scheme.error,
              ),
            )
          else
            SettingsStatus(
              l10n.settingsAnimejoySignedIn,
              signalColor: scheme.tertiary,
            ),
          if (errorMessage != null) ...[
            const SizedBox(height: 4),
            SettingsStatus(errorMessage, color: scheme.error),
          ],
        ],
      ),
    };

    return SettingsAccountRow(
      title: 'AnimeJoy',
      statusKey: state,
      status: status,
      actions: [
        if (state is AnimejoyAccountSignedOut)
          TextButton(
            key: signInButtonKey,
            style: settingsActionStyle(context, primary: true),
            onPressed:
                onSignIn ??
                () => showAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: const _AnimejoySignInSheet(),
                  ),
                ),
            child: Text(l10n.commonSignIn),
          ),
        if (state case AnimejoyAccountSignedIn(:final unverified)) ...[
          if (unverified)
            TextButton(
              key: verifyButtonKey,
              onPressed: cubit.verify,
              style: settingsActionStyle(context),
              child: Text(l10n.settingsAnimejoyVerify),
            ),
          TextButton(
            key: signOutButtonKey,
            onPressed: cubit.signOut,
            style: settingsActionStyle(context),
            child: Text(l10n.commonSignOut),
          ),
        ],
      ],
    );
  }
}

class _AnimejoySignInSheet extends StatelessWidget {
  const _AnimejoySignInSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = WindowSizeClass.of(context).isCompact;
    return Padding(
      key: AnimejoyAccountSection.signInSheetKey,
      padding: EdgeInsets.only(
        bottom: compact ? MediaQuery.viewInsetsOf(context).bottom : 0,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: compact
              ? const EdgeInsets.fromLTRB(20, 8, 20, 24)
              : const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.settingsAnimejoySignInTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(wordSpacing: -3.6),
                ),
              ),
              AnimejoySignInForm(onDone: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimejoySignInForm extends StatefulWidget {
  const AnimejoySignInForm({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<AnimejoySignInForm> createState() => _AnimejoySignInFormState();
}

class _AnimejoySignInFormState extends State<AnimejoySignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  AnimejoyAuthFailure? _failure;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearFailure(String _) {
    if (_failure != null) setState(() => _failure = null);
  }

  Future<void> _submit() async {
    final cubit = context.read<AnimejoyAccountCubit>();
    if (cubit.state is! AnimejoyAccountSignedOut ||
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _failure = null);
    await cubit.signIn(login: _login.text, password: _password.text);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (cubit.state is AnimejoyAccountSignedIn) {
      TextInput.finishAutofillContext();
      widget.onDone();
    } else if (cubit.state case AnimejoyAccountSignedOut(:final failure)) {
      setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = WindowSizeClass.of(context).isCompact;
    final signingIn =
        context.watch<AnimejoyAccountCubit>().state is AnimejoyAccountSigningIn;
    final labelStyle = SettingsRow.labelStyle(theme);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: Color.lerp(scheme.outline, scheme.onSurfaceVariant, 0.5)!,
      ),
    );

    Widget field(String label, TextFormField input) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(label, style: SettingsRow.captionStyle(theme)),
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: input),
      ],
    );

    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(
              l10n.settingsAnimejoyLoginLabel,
              TextFormField(
                key: AnimejoyAccountSection.loginFieldKey,
                controller: _login,
                readOnly: signingIn,
                autofocus: !compact,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                onChanged: _clearFailure,
                validator: (value) => value!.trim().isEmpty
                    ? l10n.settingsAnimejoyLoginRequired
                    : null,
                style: labelStyle,
                decoration: InputDecoration(
                  enabledBorder: fieldBorder,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            field(
              l10n.settingsAnimejoyPasswordLabel,
              TextFormField(
                key: AnimejoyAccountSection.passwordFieldKey,
                controller: _password,
                readOnly: signingIn,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                onChanged: _clearFailure,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value!.isEmpty
                    ? l10n.settingsAnimejoyPasswordRequired
                    : null,
                style: labelStyle,
                decoration: InputDecoration(
                  enabledBorder: fieldBorder,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? l10n.settingsAnimejoyShowPassword
                        : l10n.settingsAnimejoyHidePassword,
                    onPressed: signingIn
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: PixelIcon(
                      PixelGlyph.eye,
                      size: 16,
                      color: _obscurePassword
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            if (_failure case final failure?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: SettingsStatus(
                  _failureMessage(l10n, failure),
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: signingIn ? null : widget.onDone,
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  key: AnimejoyAccountSection.submitButtonKey,
                  style: busyButtonStyle(busy: signingIn),
                  onPressed: signingIn ? null : _submit,
                  child: BusyButtonChild(
                    l10n.commonSignIn,
                    busy: signingIn,
                    busyLabel: l10n.settingsSigningIn,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _failureMessage(AppLocalizations l10n, AnimejoyAuthFailure failure) =>
    switch (failure) {
      AnimejoyAuthFailure.invalidCredentials =>
        l10n.settingsAnimejoyErrorInvalidCredentials,
      AnimejoyAuthFailure.network => l10n.settingsAnimejoyErrorNetwork,
      AnimejoyAuthFailure.unavailable => l10n.settingsAnimejoyErrorUnavailable,
    };
