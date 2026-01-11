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
import 'data/entry_provider.dart';
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

          // AppBar switches to selection-mode bar when list selection is active
          final selectionMode = ref.watch(listSelectionModeProvider);
          final selectedCount = ref.watch(listSelectedEntryIdsProvider).length;

          final normalAppBar = AppBar(key: const ValueKey('normalAppBar'),
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
          );

          final selectionAppBar = AppBar(key: const ValueKey('selectionAppBar'),
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () { ref.read(listSelectionModeProvider.notifier).state = false; ref.read(listSelectedEntryIdsProvider.notifier).state = <String>{}; }),
            title: Text('$selectedCount 件選択'),
            actions: [
              IconButton(icon: const Icon(Icons.select_all), tooltip: '全選択', onPressed: () { final visible = ref.read(listVisibleEntryIdsProvider); ref.read(listSelectedEntryIdsProvider.notifier).state = Set<String>.from(visible); }),
              IconButton(icon: const Icon(Icons.deselect), tooltip: '全解除', onPressed: () { ref.read(listSelectedEntryIdsProvider.notifier).state = <String>{}; }),
              IconButton(icon: const Icon(Icons.delete_forever), tooltip: '選択項目を削除', onPressed: selectedCount == 0 ? null : () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('削除確認'), content: Text('選択した $selectedCount 件を削除してもよいですか？'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),]));
                if (ok != true) return;
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) {
                  appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('未認証ユーザーです')));
                  return;
                }
                final repo = ref.read(entryRepositoryProvider);
                final errors = <String>[];
                final ids = List<String>.from(ref.read(listSelectedEntryIdsProvider));
                for (final id in ids) {
                  try {
                    await repo.deleteEntry(userId: uid, entryId: id);
                  } catch (e) {
                    errors.add(id);
                  }
                }
                // clear selection
                ref.read(listSelectedEntryIdsProvider.notifier).state = <String>{};
                ref.read(listSelectionModeProvider.notifier).state = false;
                if (errors.isEmpty) {
                  appScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('選択した項目を削除しました')));
                } else {
                  appScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('一部の削除に失敗しました (${errors.length} 件)')));
                }
              }),
              const SizedBox(width: 8),
            ],
          );

          final appBarWidget = PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: selectionMode ? selectionAppBar : normalAppBar,
            ),
          );
          return Scaffold(
            appBar: appBarWidget,


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
