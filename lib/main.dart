import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIMode(SystemUiMode.immersiveSticky); // Sembunyikan status & nav bar
  runApp(const SafeBrowserApp());
}

// ==========================================
// STATE MANAGEMENT RUNTIME (In-Memory Only)
// ==========================================
class AppRuntimeState {
  static String? oneTimePassword;
}

// ==========================================
// METHOD CHANNEL
// ==========================================
class NativeService {
  static const platform = MethodChannel('com.safebrowser/kiosk');

  static Future<bool> checkEmulator() async {
    try {
      return await platform.invokeMethod('checkEmulator');
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkAccessibility() async {
    try {
      return await platform.invokeMethod('checkAccessibilityPermission');
    } catch (e) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {}
  }

  static Future<void> startKiosk() async {
    try {
      await platform.invokeMethod('startKiosk');
    } catch (e) {}
  }

  static Future<void> stopKiosk() async {
    try {
      await platform.invokeMethod('stopKiosk');
    } catch (e) {}
  }
}

// ==========================================
// ROOT WIDGET
// ==========================================
class SafeBrowserApp extends StatelessWidget {
  const SafeBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.light),
      home: const InitializationScreen(),
    );
  }
}

// ==========================================
// 1. INITIALIZATION & EMULATOR CHECK
// ==========================================
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    bool isEmulator = await NativeService.checkEmulator();
    await Future.delayed(const Duration(seconds: 1)); // Jeda tampilan splash

    if (!mounted) return;

    if (isEmulator) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BlockScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PasswordSetupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ==========================================
// EMULATOR BLOCK SCREEN
// ==========================================
class BlockScreen extends StatelessWidget {
  const BlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            const Text('Emulator Terdeteksi!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Aplikasi tidak dapat dijalankan di lingkungan virtual.', style: TextStyle(color: Colors.red.shade100)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => SystemNavigator.pop(), // Tutup paksa
              child: const Text('Tutup Aplikasi'),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. PASSWORD SETUP SCREEN
// ==========================================
class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();
  String? _error;

  void _savePassword() {
    if (_pwdController.text.isEmpty || _confirmPwdController.text.isEmpty) {
      setState(() => _error = "Password tidak boleh kosong");
      return;
    }
    if (_pwdController.text != _confirmPwdController.text) {
      setState(() => _error = "Password tidak cocok");
      return;
    }

    // Simpan di Runtime State (Memori saja)
    AppRuntimeState.oneTimePassword = _pwdController.text;
    
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PermissionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Keamanan'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Buat Password Sekali Pakai (One-Time Password)', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(controller: _pwdController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _confirmPwdController, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi Password', border: OutlineInputBorder())),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _savePassword, child: const Text('Simpan & Lanjutkan'))
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. PERMISSION SCREEN
// ==========================================
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isChecking = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    checkPermission();
  }

  Future<void> checkPermission() async {
    bool hasPermission = await NativeService.checkAccessibility();
    setState(() {
      _hasPermission = hasPermission;
      _isChecking = false;
    });

    if (hasPermission) {
      _startKioskAndNavigate();
    }
  }

  Future<void> _startKioskAndNavigate() async {
    await NativeService.startKiosk();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BrowserScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izin Aksesibilitas'), automaticallyImplyLeading: false),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Untuk mengaktifkan Kiosk Mode, izinkan Accessibility Service pada pengaturan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await NativeService.openAccessibilitySettings();
                    },
                    child: const Text('Buka Pengaturan Aksesibilitas'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: checkPermission,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Saya Sudah Mengaktifkan Izin'),
                  )
                ],
              ),
            ),
    );
  }
}

// ==========================================
// 4. BROWSER SCREEN & EXIT LOGIC
// ==========================================
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  final TextEditingController _urlController = TextEditingController(text: 'https://www.google.com');

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_urlController.text));
  }

  void _loadUrl() {
    String input = _urlController.text.trim();
    if (input.isNotEmpty) {
      if (!input.startsWith('http')) input = 'https://www.google.com/search?q=$input';
      _controller.loadRequest(Uri.parse(input));
    }
  }

  void _showExitDialog() {
    final TextEditingController exitPwdController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Keluar Aplikasi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan One-Time Password untuk keluar.'),
                  TextField(
                    controller: exitPwdController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (exitPwdController.text == AppRuntimeState.oneTimePassword) {
                      Navigator.pop(context); // Tutup dialog
                      await NativeService.stopKiosk(); // Lepas kunci & tutup aplikasi
                    } else {
                      setStateDialog(() => error = "Password Salah!");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Keluar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Cegah tombol back Android
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // AppBar Custom
              Container(
                color: Colors.blueGrey.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari atau masukkan URL',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.blueGrey.shade800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _loadUrl(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () => _controller.reload(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                      onPressed: _showExitDialog,
                    ),
                  ],
                ),
              ),
              // WebView
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}