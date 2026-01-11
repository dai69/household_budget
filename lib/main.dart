import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'presentation/pages/input_page.dart';
import 'presentation/pages/list_page_clean.dart';
import 'presentation/pages/report_page.dart';
import 'presentation/pages/auth_page.dart';
import 'presentation/pages/categories_page.dart';
import 'presentation/pages/templates_page.dart';
import 'utils/global_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  int _currentIndex = 0;
  // use the shared app-wide scaffold messenger key
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = appScaffoldMessengerKey;

  static const List<Widget> _pages = <Widget>[
    InputPage(),
    ListPageClean(),
    ReportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Smart家計簿',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (user == null) {
            return const AuthPage();
          }
          return Scaffold(
            appBar: AppBar(
              title: const Text('Smart家計簿'),
              actions: [
                // user account icon: tap to view email and change password
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    tooltip: 'アカウント',
                    icon: CircleAvatar(
                      radius: 14,
                      child: const Icon(Icons.person, size: 18),
                    ),
                    onPressed: () async {
                      final current = FirebaseAuth.instance.currentUser;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: Row(children: [
                              const Text('アカウント'),
                              const Spacer(),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ]),
                            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('メール: ${current?.email ?? '未登録'}'),
                              const SizedBox(height: 8),
                              Text('UID: ${current?.uid ?? '不明'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ]),
                            actions: [
                              if (current?.email != null) TextButton(
                                onPressed: () {
                                  // Close dialog immediately, then perform network operation and report via scaffold messenger key.
                                  Navigator.of(ctx).pop();
                                  FirebaseAuth.instance.sendPasswordResetEmail(email: current!.email!).then((_) {
                                    appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('パスワードリセット用のメールを送信しました')));
                                  }).catchError((e) {
                                    appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('エラー: $e')));
                                  });
                                },
                                child: const Text('パスワード変更（リセットメール送信）'),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Close dialog immediately, then sign out. Report via scaffold messenger key.
                                  Navigator.of(ctx).pop();
                                  FirebaseAuth.instance.signOut().then((_) {
                                    // no-op
                                  }).catchError((e) {
                                    appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('サインアウトエラー: $e')));
                                  });
                                },
                                child: const Text('ログアウト'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'categories') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesPage()));
                    if (v == 'templates') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemplatesPage()));
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'categories', child: Text('カテゴリ編集')),
                    const PopupMenuItem(value: 'templates', child: Text('テンプレート')),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
                // logout now integrated into the account dialog
              ],
            ),
            body: _pages[_currentIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(icon: Icon(Icons.edit), label: '入力'),
                NavigationDestination(icon: Icon(Icons.list), label: '一覧'),
                NavigationDestination(icon: Icon(Icons.pie_chart), label: '集計'),
              ],
            ),
          );
        },
      ),
    );
  }
}
