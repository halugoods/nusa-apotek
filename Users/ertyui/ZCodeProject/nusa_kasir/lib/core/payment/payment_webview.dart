import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/activation/activation_screen.dart';

/// Full-screen WebView for Midtrans payment.
/// Intercepts URL redirects to detect payment success/failure.
///
/// Expected URL patterns:
///   - nusa://payment-success?order_id=... → close WebView, verify, activate
///   - nusa://payment-failed?order_id=...   → show error, go back
///   - nusa://payment-pending?order_id=...  → show pending, go back
class PaymentWebView extends ConsumerStatefulWidget {
  final String paymentUrl;
  final String googleId;

  const PaymentWebView({
    required this.paymentUrl,
    required this.googleId,
    super.key,
  });

  @override
  ConsumerState<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends ConsumerState<PaymentWebView> {
  WebViewController? _controller;
  bool _loading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _loading = true);
          },
          onPageFinished: (url) {
            setState(() => _loading = false);
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100.0);
          },
          onNavigationRequest: (request) {
            // Intercept custom URL scheme for payment results
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            if (uri.scheme == 'nusa' && uri.host == 'payment-success') {
              _handleSuccess(uri);
              return NavigationDecision.prevent;
            }

            if (uri.scheme == 'nusa' && uri.host == 'payment-failed') {
              _handleFailed(uri);
              return NavigationDecision.prevent;
            }

            if (uri.scheme == 'nusa' && uri.host == 'payment-pending') {
              _handlePending(uri);
              return NavigationDecision.prevent;
            }

            // Allow Midtrans domains, block external navigation attempts
            if (!uri.host.contains('midtrans.com') &&
                !uri.host.contains('vercel.app') &&
                !uri.host.contains('supabase.co') &&
                request.url != widget.paymentUrl) {
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handleSuccess(Uri uri) async {
    final key = uri.queryParameters['key'];

    if (key != null && key.isNotEmpty) {
      // The edge function already generated the key — activate it locally
      try {
        final repo = ref.read(activationRepoProvider);
        final result = await repo.activate(key, widget.googleId);
        if (result.ok && mounted) {
          context.go('/login');
          return;
        }
      } catch (_) {}
    }

    // Fallback: navigate to activation screen which will check cloud license
    if (mounted) {
      context.go('/activation');
    }
  }

  void _handleFailed(Uri uri) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran gagal. Silakan coba lagi.'),
          backgroundColor: NusaConfig.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  void _handlePending(Uri uri) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran menunggu konfirmasi. Cek aplikasi nanti.'),
          backgroundColor: NusaConfig.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NusaConfig.backgroundColor,
      appBar: AppBar(
        title: Text('Pembayaran'),
        centerTitle: true,
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: _loading
            ? PreferredSize(
                preferredSize: Size(double.infinity, 3),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : null,
      ),
      body: _controller != null ? WebViewWidget(controller: _controller!) : SizedBox.shrink(),
    );
  }
}
