// QR Scanner Screen using mobile_scanner
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scan_result_limited_screen.dart';
import 'scan_result_full_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanning = true;
  bool _hasScanned = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (!_isScanning || _hasScanned) return;
    
    final String? code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    // Validate UUID format
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    if (!uuidRegex.hasMatch(code)) {
      _showError('Invalid QR code');
      // Resume scanning after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _hasScanned = false);
      return;
    }

    setState(() {
      _hasScanned = true;
      _isScanning = false;
    });

    // Check if user is a verified doctor
    final user = Supabase.instance.client.auth.currentUser;
    bool isVerifiedDoctor = false;
    
    if (user != null) {
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('role, verification_status')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profileResponse != null) {
          final role = profileResponse['role'] as String;
          final status = profileResponse['verification_status'] as String;
          isVerifiedDoctor = role == 'doctor' && status == 'verified';
        }
      } catch (e) {
        // If error, treat as guest
        isVerifiedDoctor = false;
      }
    }

    if (!mounted) return;

    // Navigate to appropriate result screen
    if (isVerifiedDoctor) {
      context.go('/scan-result/full/$code');
    } else {
      context.go('/scan-result/limited/$code');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _scannerController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/welcome'),
        ),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: _flashOn ? 'Turn off flashlight' : 'Turn on flashlight',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleScan,
          ),
          // Scan Frame Overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Position the QR code within the frame',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Scanning indicator
          if (!_hasScanned)
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scanning...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}