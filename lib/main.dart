// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- För SystemChrome
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/providers/auth_providers.dart';
import 'core/providers/theme_providers.dart';
import 'widgets/main_scaffold.dart';
import 'auth/login_page.dart';
import 'auth/handle_invite_page.dart';
import 'core/deep_links/deep_link_handler.dart';
import 'firebase_options.dart';

// Ditt tema
import 'core/theme/theme.dart';

/// Din Firestore‑provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'region1',
  );
});

final rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'callup_channel',
      channelName: 'Kallelser',
      channelDescription: 'Notiser med Ja/Nej',
      importance: NotificationImportance.High,
      channelShowBadge: true,
    ),
  ], debug: true);
  _showCallupNotification(message);
}

@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction action) async {
  final callupId = action.payload?['callupId'];
  if (callupId == null) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'region1',
  );
  final newStatus =
      action.buttonKeyPressed == 'ACCEPT' ? 'accepted' : 'declined';
  await firestore.collection('callups').doc(callupId).update({
    'status': newStatus,
    'respondedAt': Timestamp.now(),
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sätt statusfältet transparent + mörka ikoner
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('sv_SE', null);

  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'callup_channel',
      channelName: 'Kallelser',
      channelDescription: 'Notiser med Ja/Nej',
      importance: NotificationImportance.High,
      channelShowBadge: true,
    ),
  ], debug: true);

  if (!await AwesomeNotifications().isNotificationAllowed()) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(child: DeepLinkHandler(child: MessagingInitializer())),
  );
}

class MessagingInitializer extends ConsumerStatefulWidget {
  const MessagingInitializer({Key? key}) : super(key: key);

  @override
  ConsumerState<MessagingInitializer> createState() =>
      _MessagingInitializerState();
}

class _MessagingInitializerState extends ConsumerState<MessagingInitializer> {
  @override
  void initState() {
    super.initState();
    _initFcmToken();
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
    FirebaseMessaging.onMessage.listen(_showCallupNotification);
  }

  Future<void> _initFcmToken() async {
    final auth = ref.read(authNotifierProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final auth = ref.read(authNotifierProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final db = ref.read(firestoreProvider);

    final batch = db.batch();
    final query =
        await db.collection('users').where('fcmToken', isEqualTo: token).get();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'fcmToken': FieldValue.delete()});
    }
    final myRef = db.collection('users').doc(uid);
    batch.set(myRef, {'fcmToken': token}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return const TeamZoneApp();
  }
}

class TeamZoneApp extends ConsumerWidget {
  const TeamZoneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final themeMode = ref.watch(themeModeProvider);

    // Välj vilken sida som ska visas först
    final Widget home;
    if (auth.isInitializing ||
        (auth.currentUser != null && session.uid.isEmpty)) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (auth.currentUser != null) {
      home = const MainScaffold();
    } else {
      home = const LoginPage();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TeamZone',
      navigatorKey: rootNavigatorKey,
      themeMode: themeMode,

      // Använd dina teman
      theme: TeamZoneTheme.lightTheme,
      darkTheme: TeamZoneTheme.darkTheme,

      // Här lägger vi på bakgrundsfärg bakom statusfältet OCH padding innanför
      builder: (context, child) {
        return Container(
          color: Theme.of(context).colorScheme.background,
          child: SafeArea(child: child!),
        );
      },

      home: home,
      onGenerateRoute: (settings) {
        if (settings.name == '/handle-invite') {
          final code = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => HandleInvitePage(inviteCode: code),
          );
        }
        return null;
      },
    );
  }
}

void _showCallupNotification(RemoteMessage message) {
  final data = message.data;
  final callupId = data['callupId'];
  if (callupId == null) return;

  final eventType = data['eventType'] ?? '';
  final eventDate = data['eventDate'] ?? '';
  final eventTime = data['eventTime'] ?? '';
  final opponent = data['opponent'] ?? '';
  final homeOrAway = data['homeOrAway'] ?? '';
  final area = data['area'] ?? '';
  final pitch = data['pitch'] ?? '';

  final title = 'Du är kallad till $eventType';
  final body =
      (eventType == 'Match')
          ? '$eventDate $eventTime – $opponent ($homeOrAway)'
          : '$eventDate $eventTime – $area/$pitch';

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channelKey: 'callup_channel',
      title: title,
      body: body,
      payload: {'callupId': callupId},
      notificationLayout: NotificationLayout.Default,
    ),
    actionButtons: [
      NotificationActionButton(key: 'ACCEPT', label: 'Ja, jag deltar'),
      NotificationActionButton(key: 'DECLINE', label: 'Nej, jag deltar inte'),
    ],
  );
}
