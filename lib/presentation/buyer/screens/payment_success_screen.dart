import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String orderId;
  final double orderTotal;
  final Map<String, dynamic>? orderData;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    required this.orderTotal,
    this.orderData,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  // Tracks whether cart clear API call is done
  bool _cartCleared = false;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();

    // ── Clear cart immediately on screen load ──────────
    // We do this as soon as PaymentSuccessScreen mounts so
    // the API call has maximum time to complete before the
    // user taps "Back to Home". We update _cartCleared so
    // _goHome() knows it can skip a second call.
    _clearCartNow();
  }

  Future<void> _clearCartNow() async {
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  CLEAR CART — on payment success');
    debugPrint('╚══════════════════════════════════════╝');

    try {
      final result = await AuthService.instance.clearCartApi();
      debugPrint(
          '🛒 [PaymentSuccess] cart clear: success=${result.success}');
      if (mounted) setState(() => _cartCleared = true);
    } catch (e) {
      debugPrint('🛒 [PaymentSuccess] cart clear error (non-fatal): $e');
      if (mounted) setState(() => _cartCleared = true);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String get _shortOrderId {
    if (widget.orderId.length > 8) {
      return widget.orderId.substring(0, 8).toUpperCase();
    }
    return widget.orderId.toUpperCase();
  }

  Map<String, dynamic> get _orderMap {
    final base = Map<String, dynamic>.from(widget.orderData ?? {});
    if (widget.orderId.isNotEmpty) {
      base['id']          = widget.orderId;
      base['orderId']     = widget.orderId;
      base['orderNumber'] = widget.orderId;
    }
    return base;
  }

  void _goToTracking() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(order: _orderMap)),
    );
  }

  // ══════════════════════════════════════════════════════
  //  GO HOME
  //
  //  FIX: Cart was showing stale items because:
  //  1. clearCartApi() was fire-and-forget — navigation
  //     happened before the API responded.
  //  2. CartScreen rendered from cached state on arrival.
  //
  //  Solution:
  //  - If cart clear already finished (_cartCleared=true),
  //    navigate immediately.
  //  - If still in progress, show a brief loader and await
  //    it (max 3s timeout so UX never hangs).
  //  - Navigate to BuyerMainScreen with reloadCart=true so
  //    CartScreen.reload() is called right on arrival,
  //    guaranteeing fresh empty state even if clear API
  //    was slow.
  // ══════════════════════════════════════════════════════
  Future<void> _goHome() async {
    // If cart clear hasn't finished yet, wait up to 3 seconds
    if (!_cartCleared) {
      debugPrint('🛒 [GoHome] Cart clear still in progress — waiting...');

      // Show brief loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            SizedBox(
              width:  16,
              height: 16,
              child:  CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Finalising order...'),
          ]),
          duration: Duration(seconds: 3),
          backgroundColor: AppColors.primary,
        ));
      }

      // Wait up to 3 seconds for cart clear to finish
      for (int i = 0; i < 30 && !_cartCleared; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint(
          '🛒 [GoHome] Done waiting. cartCleared=$_cartCleared');
    }

    if (!mounted) return;

    // Dismiss any snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    debugPrint('🛒 [GoHome] Navigating to BuyerMainScreen '
        'with reloadCart=true');

    // Navigate to BuyerMainScreen — pass reloadCart flag so
    // CartScreen.reload() fires immediately on arrival.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => const BuyerMainScreen(reloadCart: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),

              // ── Animated success circle ──────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width:  120,
                  height: 120,
                  decoration: BoxDecoration(
                    color:  AppColors.success.withOpacity(0.12),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: AppColors.success, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size:  64,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ────────────────────────────────
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your payment of £${widget.orderTotal.toStringAsFixed(2)} has been\nprocessed successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color:    AppColors.textSecondary,
                  height:   1.5,
                ),
              ),
              const SizedBox(height: 32),

              // ── Order details card ───────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:       Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(children: [
                  _DetailRow('Order ID',
                      widget.orderId.isNotEmpty
                          ? '#$_shortOrderId'
                          : '—'),
                  const Divider(height: 20),
                  _DetailRow('Amount Paid',
                      '£${widget.orderTotal.toStringAsFixed(2)}'),
                  const Divider(height: 20),
                  _DetailRow('Status', 'Confirmed',
                      valueColor: AppColors.success),
                  const Divider(height: 20),
                  _DetailRow('Payment', 'Stripe  •  Secure'),
                ]),
              ),
              const SizedBox(height: 28),

              // ── What's next card ─────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(children: [
                  const Row(children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text("What's next?",
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.primary,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  _NextStep(
                      '1', 'Your supplier is processing the order.'),
                  const SizedBox(height: 8),
                  _NextStep(
                      '2', 'A driver will be assigned for delivery.'),
                  const SizedBox(height: 8),
                  _NextStep(
                      '3', 'Track your order in real-time below.'),
                ]),
              ),
              const SizedBox(height: 32),

              // ── Track Order ──────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _goToTracking,
                  icon:  const Icon(Icons.local_shipping_outlined),
                  label: const Text(
                    'Track My Order',
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Back to Home ─────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon:  const Icon(Icons.home_outlined),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:  const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Detail row ─────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w600,
              color:      valueColor ?? AppColors.textPrimary,
            )),
      ]);
}

// ── Next step row ───────────────────────────────────────────
class _NextStep extends StatelessWidget {
  final String step, text;
  const _NextStep(this.step, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width:     22,
          height:    22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: Text(step,
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.bold,
                color:      AppColors.white,
              )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
        ),
      ]);
}