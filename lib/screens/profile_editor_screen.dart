import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_repository.dart';
import '../auth/username.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _link;
  late final TextEditingController _phone;
  String? _usernameError;
  bool _busy = false;

  Profile get _profile =>
      authRepository.current?.profile ?? const Profile();

  @override
  void initState() {
    super.initState();
    final p = _profile;
    _name = TextEditingController(text: p.displayName ?? '');
    _username = TextEditingController(text: p.username ?? '');
    _bio = TextEditingController(text: p.bio ?? '');
    _link = TextEditingController(text: p.link ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _bio, _link, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      await authRepository.updateAvatar(
        bytes,
        picked.mimeType ?? 'image/jpeg',
      );
      if (mounted) {
        setState(() {}); // перерисовать аватар в шапке
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Аватар обновлён')));
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final newUsername = _username.text.trim().toLowerCase();
    final usernameChanged = newUsername != (_profile.username ?? '');
    if (usernameChanged) {
      final error = validateUsernameFormat(newUsername);
      if (error != null) {
        setState(() => _usernameError = error);
        return;
      }
    }
    setState(() {
      _usernameError = null;
      _busy = true;
    });
    try {
      if (usernameChanged) {
        if (!await authRepository.isUsernameAvailable(newUsername)) {
          setState(() => _usernameError = 'Этот ник уже занят');
          return;
        }
        await authRepository.claimUsername(
          username: newUsername,
          displayName: _name.text,
        );
      }
      await authRepository.updateProfile(
        displayName: _name.text,
        bio: _bio.text,
        link: _link.text,
        phone: _phone.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сохранено')));
      Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: pillDecoration(
                        colors.surface,
                        borderColor: colors.accent,
                      ),
                      child: Icon(Icons.arrow_back,
                          color: colors.accent, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: pillDecoration(colors.accent),
                      child: Text(
                        'Редактор профиля',
                        style: TextStyle(
                          color: colors.bg,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(2),
                    decoration: pillDecoration(
                      colors.surface,
                      borderColor: colors.accent,
                    ),
                    child: AAvatar(size: 32, url: _profile.avatarUrl),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _EditorField(
                          label: 'Имя?',
                          hint: 'Вася Пупкин',
                          controller: _name,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Фото?',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _busy ? null : _pickAvatar,
                            child: Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(12),
                              decoration: pillDecoration(colors.surface),
                              child: Image.asset('assets/images/react_3.png'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'Имя пользователя?',
                    hint: 'vasok',
                    controller: _username,
                    errorText: _usernameError,
                  ),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'О себе?',
                    hint: 'жестка чувствую',
                    controller: _bio,
                  ),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'Ссылки на другие соц. сети?',
                    hint: 'TG:@vasya',
                    controller: _link,
                  ),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'Номер телефона?',
                    hint: '+7 900 000-00-00',
                    controller: _phone,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _busy ? null : _save,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.bg,
                              ),
                            )
                          : Text(
                              'Сохранить',
                              style: TextStyle(
                                color: colors.bg,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.label,
    required this.hint,
    required this.controller,
    this.errorText,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: pillDecoration(colors.surface),
          child: Center(
            child: TextField(
              controller: controller,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: TextStyle(color: colors.hint, fontSize: 16),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Text(
              errorText!,
              style: TextStyle(color: colors.accent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
