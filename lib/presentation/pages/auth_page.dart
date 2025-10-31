import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final pwd = _passwordController.text.trim();
      final current = FirebaseAuth.instance.currentUser;
      final credential = EmailAuthProvider.credential(email: email, password: pwd);
      if (current != null && current.isAnonymous) {
        // Link anonymous account to email/password
        await current.linkWithCredential(credential);
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('匿名アカウントをメールに紐付けしました')));
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pwd);
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('登録成功')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('登録に失敗しました: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('登録に失敗しました: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final pwd = _passwordController.text.trim();
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pwd);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('ログイン成功')));
    } on FirebaseAuthException catch (e) {
      // Normalize code/message to detect credential errors reliably
  final raw = e.code.toString();
  final code = raw.toLowerCase().replaceAll('auth/', '').replaceAll('_', '-');
  final message = (e.message ?? '').toLowerCase();

      // Keywords that typically indicate wrong email/password responses
      final credKeywords = [
        'wrong-password',
        'wrong',
        'invalid-password',
        'invalid-credential',
        'invalid-credentials',
        'user-not-found',
        'email-not-found',
        'invalid-email',
        'invalid',
        'password'
      ];

      final isCredError = credKeywords.any((k) => code.contains(k) || message.contains(k) || message.contains(k.replaceAll('-', ' ')) || message.contains('email not found') || message.contains('invalid password'));

      if (isCredError) {
        // For credential-related failures, always show a friendly, non-raw message
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('メールアドレスまたはパスワードに誤りがあります')));
      } else {
        // For other failures, avoid exposing raw server responses in the UI;
        // log details for debugging and show a generic failure message.
        debugPrint('FirebaseAuthException during login: code=${e.code}, message=${e.message}');
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('ログインに失敗しました')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('ログインに失敗しました: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _anonymous() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('匿名で継続します')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('匿名サインインに失敗しました: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('パスワード再設定用のメールを送信しました。メールをご確認ください。')));
    } on FirebaseAuthException catch (e) {
      // Handle common cases without exposing raw server message
      final code = e.code.toString().toLowerCase().replaceAll('auth/', '').replaceAll('_', '-');
      if (code.contains('user-not-found') || code.contains('email-not-found')) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('該当するアカウントが見つかりません')));
      } else if (code.contains('invalid-email') || code.contains('invalid')) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('メールアドレスの形式が正しくありません')));
      } else {
        debugPrint('Password reset failed: code=${e.code}, message=${e.message}');
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('パスワード再設定メールの送信に失敗しました')));
      }
    } catch (e) {
      debugPrint('Password reset unexpected error: $e');
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('パスワード再設定メールの送信に失敗しました')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final controller = TextEditingController(text: _emailController.text);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パスワードを忘れた場合'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '登録済みのメールアドレス'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('送信')),
        ],
      ),
    );

    if (res == true) {
      final email = controller.text.trim();
      if (email.isEmpty) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('メールアドレスを入力してください')));
        return;
      }
      await _sendPasswordReset(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ログイン / 登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'メールアドレス'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'パスワード（6文字以上）'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading) const CircularProgressIndicator(),
                    if (!_isLoading) ...[
                      Row(
                        children: [
                          Expanded(child: ElevatedButton(onPressed: _login, child: const Text('ログイン'))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(onPressed: _register, child: const Text('登録'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _showPasswordResetDialog, child: const Text('パスワードを忘れた場合')),
                      TextButton(onPressed: _anonymous, child: const Text('匿名で続ける')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
