import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double orderTotal;
  final Map<String, dynamic>? orderData;
  final String? deliveryAddressId;
  final String? specialInstructions;
  final String? discountCode;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.orderTotal,
    this.orderData,
    this.deliveryAddressId,
    this.specialInstructions,
    this.discountCode,
  });
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _savedCards     = [];
  String?                    _selectedCardId;
  bool                       _isLoadingCards = true;
  bool                       _isProcessing   = false;

  bool _saveNewCard  = false;
  bool _isPayingNew  = false;
  bool _isSavingCard = false; // ← new: tracks card-save in progress

  // ── Resolved orderId ────────────────────────────────
  String get _resolvedOrderId {
    if (widget.orderId.isNotEmpty) return widget.orderId;
    final d = widget.orderData;
    if (d == null) return '';
    for (final k in [
      'orderId', 'OrderId', 'id', 'Id',
      'orderNumber', 'OrderNumber'
    ]) {
      final v = d[k];
      if (v != null && v.toString().isNotEmpty && v.toString() != 'null') {
        debugPrint('💳 [PaymentScreen] orderId from orderData.$k: $v');
        return v.toString();
      }
    }
    final order = d['order'];
    if (order is Map<String, dynamic>) {
      for (final k in ['id', 'orderId', 'orderNumber']) {
        final v = order[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }
    final orders = d['orders'];
    if (orders is List &&
        orders.isNotEmpty &&
        orders.first is Map<String, dynamic>) {
      final first = orders.first as Map<String, dynamic>;
      for (final k in ['id', 'orderId', 'orderNumber']) {
        final v = first[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }
    debugPrint(
        '❌ [PaymentScreen] orderId empty. orderData keys: ${d.keys.toList()}');
    return '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    debugPrint('💳 [PaymentScreen] init — orderId="${_resolvedOrderId}"');
    _loadSavedCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() => _isLoadingCards = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  GET SAVED CARDS — loading...');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.getSavedCards();
    if (!mounted) return;

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  GET SAVED CARDS — result');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  count   : ${result.data?.length ?? 0}');
    debugPrint('║  message : ${result.message}');
    debugPrint('╚══════════════════════════════════════╝');

    if (result.success) {
      final cards =
          (result.data ?? []).whereType<Map<String, dynamic>>().toList();
      setState(() {
        _savedCards     = cards;
        _isLoadingCards = false;
        if (cards.isNotEmpty) {
          final def = cards.firstWhere(
            (c) => c['isDefault'] == true,
            orElse: () => cards.first,
          );
          _selectedCardId = (def['id'] ?? def['cardId'])?.toString();
          debugPrint('💳 [Cards] Auto-selected card: $_selectedCardId');
        }
      });
    } else {
      setState(() => _isLoadingCards = false);
    }
  }

  // ── Pay with saved card ────────────────────────────────
  Future<void> _payWithSavedCard() async {
    if (_selectedCardId == null) {
      _snack('Please select a card.', isError: true);
      return;
    }

    String oid = _resolvedOrderId;

    // If orderId empty — place order first then pay
    if (oid.isEmpty) {
      if (widget.deliveryAddressId == null) {
        _snack('Delivery address missing. Please go back.',
            isError: true);
        return;
      }
      setState(() => _isProcessing = true);
      debugPrint('🛒 [PayWithSavedCard] Placing order first...');
      final orderResult = await AuthService.instance.checkout(
        deliveryAddressId:   widget.deliveryAddressId!,
        billingAddressId:    widget.deliveryAddressId!,
        specialInstructions: widget.specialInstructions ?? '',
        discountCode:        widget.discountCode,
      );
      if (!mounted) return;
      if (!orderResult.success || orderResult.data == null) {
        setState(() => _isProcessing = false);
        _snack(orderResult.message ?? 'Order placement failed.',
            isError: true);
        return;
      }
      final data   = orderResult.data!;
      final orders = data['orders'];
      if (orders is List && orders.isNotEmpty) {
        oid = orders.first['orderId']?.toString() ?? '';
      }
      if (oid.isEmpty) oid = data['orderId']?.toString() ?? '';
      debugPrint('🛒 [PayWithSavedCard] Order placed! orderId: $oid');
      if (oid.isEmpty) {
        setState(() => _isProcessing = false);
        _snack('Order placed but ID missing. Contact support.',
            isError: true);
        return;
      }
    } else {
      setState(() => _isProcessing = true);
    }

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  PAY WITH SAVED CARD');
    debugPrint('║  orderId : $oid');
    debugPrint('║  cardId  : $_selectedCardId');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.payWithSavedCard(
        orderId: oid, cardId: _selectedCardId!);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  PAY WITH SAVED CARD — result');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  message : ${result.message}');
    debugPrint('║  data    : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (result.success) {
      final status = (result.data?['status'] ??
              result.data?['paymentStatus'] ??
              '')
          .toString()
          .toLowerCase();
      final ok = status == 'succeeded' ||
          status == 'completed' ||
          status == 'paid' ||
          result.data != null;
      if (ok) {
        _navigateToSuccess(oid);
      } else {
        _snack(
            'Payment declined: ${result.data?['message'] ?? 'Unknown error'}',
            isError: true);
      }
    } else {
      _snack(result.message ?? 'Payment failed. Please try again.',
          isError: true);
    }
  }

  // ── Pay with new card via Stripe PaymentSheet ──────────
  Future<void> _payWithNewCard() async {
    String oid = _resolvedOrderId;

    // If orderId empty — place order first then pay
    if (oid.isEmpty) {
      if (widget.deliveryAddressId == null) {
        _snack('Delivery address missing. Please go back.',
            isError: true);
        return;
      }
      setState(() => _isPayingNew = true);
      debugPrint('🛒 [PayWithNewCard] Placing order first...');
      final orderResult = await AuthService.instance.checkout(
        deliveryAddressId:   widget.deliveryAddressId!,
        billingAddressId:    widget.deliveryAddressId!,
        specialInstructions: widget.specialInstructions ?? '',
        discountCode:        widget.discountCode,
      );
      if (!mounted) return;
      if (!orderResult.success || orderResult.data == null) {
        setState(() => _isPayingNew = false);
        _snack(orderResult.message ?? 'Order placement failed.',
            isError: true);
        return;
      }
      // Extract orderId
      final data   = orderResult.data!;
      final orders = data['orders'];
      if (orders is List && orders.isNotEmpty) {
        oid = orders.first['orderId']?.toString() ?? '';
      }
      if (oid.isEmpty) oid = data['orderId']?.toString() ?? '';
      debugPrint('🛒 [PayWithNewCard] Order placed! orderId: $oid');
      if (oid.isEmpty) {
        setState(() => _isPayingNew = false);
        _snack('Order placed but ID missing. Contact support.',
            isError: true);
        return;
      }
    } else {
      setState(() => _isPayingNew = true);
    }

    setState(() => _isPayingNew = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  PAY WITH NEW CARD');
    debugPrint('║  orderId     : $oid');
    debugPrint('║  saveNewCard : $_saveNewCard');
    debugPrint('╚══════════════════════════════════════╝');

    // Step 1: Create PaymentIntent
    final intentResult =
        await AuthService.instance.createPaymentIntent(orderId: oid);
    if (!mounted) return;

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  CREATE PAYMENT INTENT — result');
    debugPrint('║  success : ${intentResult.success}');
    debugPrint('║  message : ${intentResult.message}');
    debugPrint('║  data    : ${intentResult.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!intentResult.success) {
      setState(() => _isPayingNew = false);
      _snack(intentResult.message ?? 'Could not initialise payment.',
          isError: true);
      return;
    }

    final clientSecret =
        intentResult.data?['clientSecret']?.toString() ??
        intentResult.data?['client_secret']?.toString() ??
        intentResult.data?['data']?['clientSecret']?.toString();

    debugPrint(
        '💳 [Intent] clientSecret prefix: '
        '${clientSecret != null && clientSecret.length > 25 ? clientSecret.substring(0, 25) : clientSecret}...');

    if (clientSecret == null || clientSecret.isEmpty) {
      setState(() => _isPayingNew = false);
      _snack('Invalid payment session. Please try again.', isError: true);
      return;
    }

    // Step 2: Init Stripe sheet
    try {
      debugPrint('💳 [Stripe] Initialising payment sheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName:       'Nepta Solutions',
          style:                     ThemeMode.light,
        ),
      );
      debugPrint('💳 [Stripe] Payment sheet initialised — presenting...');

      // Step 3: Present
      await Stripe.instance.presentPaymentSheet();

      if (!mounted) return;
      setState(() => _isPayingNew = false);
      debugPrint('💳 [Stripe] ✅ Payment sheet completed successfully');

      // Step 4: Optionally save card
      if (_saveNewCard) {
        await _saveCardAfterPayment(clientSecret);
      } else {
        debugPrint('💳 [SaveCard] Toggle is OFF — skipping card save');
      }

      _navigateToSuccess(oid);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isPayingNew = false);
      debugPrint(
          '❌ [Stripe] StripeException code=${e.error.code} '
          'msg=${e.error.localizedMessage}');
      if (e.error.code != FailureCode.Canceled) {
        _snack(
            e.error.localizedMessage ??
                e.error.message ??
                'Payment failed.',
            isError: true);
      } else {
        debugPrint('💳 [Stripe] User cancelled payment sheet — no action');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPayingNew = false);
      debugPrint('❌ [Stripe] Unexpected error: $e');
      _snack('An unexpected error occurred. Please try again.',
          isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  SAVE CARD AFTER PAYMENT
  //
  //  FIX: The backend /api/payments/cards/save expects a
  //  PaymentMethod ID (pm_xxx), NOT a PaymentIntent ID (pi_xxx).
  //
  //  After presentPaymentSheet() succeeds we use the Stripe SDK
  //  to retrieve the PaymentIntent and read its
  //  payment_method field — that gives us the real pm_xxx ID.
  //
  //  If Stripe SDK retrieval fails we fall back to sending the
  //  pi_xxx and let the backend decide — some backends handle
  //  this server-side.
  // ══════════════════════════════════════════════════════
  Future<void> _saveCardAfterPayment(String clientSecret) async {
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  SAVE CARD — toggle was ON');
    debugPrint('║  clientSecret prefix: '
        '${clientSecret.length > 25 ? clientSecret.substring(0, 25) : clientSecret}...');
    debugPrint('╚══════════════════════════════════════╝');

    setState(() => _isSavingCard = true);
    _snack('Saving your card...');

    // ── Step 1: Retrieve the actual PaymentMethod ID (pm_xxx) ──
    String? paymentMethodId;

    try {
      debugPrint('💳 [SaveCard] Retrieving PaymentIntent to get pm_xxx...');

      // Stripe SDK: retrieve the PaymentIntent using clientSecret
      final paymentIntent =
          await Stripe.instance.retrievePaymentIntent(clientSecret);

      debugPrint(
          '💳 [SaveCard] PI status   : ${paymentIntent.status}');
      debugPrint(
          '💳 [SaveCard] paymentMethodId from PI: '
          '${paymentIntent.paymentMethodId}');

      paymentMethodId = paymentIntent.paymentMethodId;
    } catch (e) {
      debugPrint(
          '⚠️  [SaveCard] Could not retrieve PI from Stripe SDK: $e');
      // If SDK call fails, we cannot get pm_xxx — abort gracefully
    }

    // ── Step 2: Validate we have a pm_xxx ──────────────────────
    if (paymentMethodId == null ||
        paymentMethodId.isEmpty ||
        !paymentMethodId.startsWith('pm_')) {
      debugPrint(
          '❌ [SaveCard] No valid pm_xxx found '
          '(got: "$paymentMethodId") — cannot save card');

      if (mounted) {
        setState(() => _isSavingCard = false);
        _snack(
            'Payment succeeded but card could not be saved '
            '(no PaymentMethod ID returned by Stripe).',
            isError: false);
      }
      return;
    }

    // ── Step 3: Call backend save-card endpoint ────────────────
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  SAVE CARD REQUEST');
    debugPrint('║  paymentMethodId: $paymentMethodId');
    debugPrint('║  setAsDefault   : false');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.saveCard(
      paymentMethodId: paymentMethodId,
      setAsDefault:    false,
    );

    if (!mounted) return;
    setState(() => _isSavingCard = false);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  SAVE CARD RESPONSE');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  message : ${result.message}');
    debugPrint('║  data    : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (result.success) {
      debugPrint('💳 [SaveCard] ✅ Card saved successfully');
      _snack('Card saved for future payments! ✓');
      await _loadSavedCards(); // refresh saved cards list
    } else {
      debugPrint('❌ [SaveCard] Failed: ${result.message}');
      _snack(
          'Payment succeeded but card could not be saved: '
          '${result.message}',
          isError: true);
    }
  }
  Future<void> _navigateToSuccess(String oid) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          orderId:    oid,
          orderTotal: widget.orderTotal,
          orderData:  widget.orderData,
        ),
      ),
    );
  }
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration:        const Duration(seconds: 4),
    ));
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final oid = _resolvedOrderId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       AppColors.white,
          labelColor:           AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.credit_card), text: 'Saved Cards'),
            Tab(icon: Icon(Icons.add_card),    text: 'New Card'),
          ],
        ),
      ),
      body: Column(children: [
        _OrderBanner(total: widget.orderTotal, orderId: oid),


        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SavedCardsTab(
                savedCards:     _savedCards,
                isLoading:      _isLoadingCards,
                selectedCardId: _selectedCardId,
                isProcessing:   _isProcessing,
                orderTotal:     widget.orderTotal,
                onCardSelected: (id) {
                  debugPrint('💳 [Cards] Card selected: $id');
                  setState(() => _selectedCardId = id);
                },
                onPay:        _payWithSavedCard,
                onAddNewCard: () => _tabController.animateTo(1),
                onRefresh:    _loadSavedCards,
              ),
              _NewCardTab(
                saveCard:      _saveNewCard,
                isPaying:      _isPayingNew,
                isSavingCard:  _isSavingCard,
                orderTotal:    widget.orderTotal,
                onSaveToggle: (v) {
                  debugPrint(
                      '💳 [SaveToggle] Save card toggled → $v');
                  setState(() => _saveNewCard = v);
                },
                onPay: _payWithNewCard,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER BANNER
// ══════════════════════════════════════════════════════════
class _OrderBanner extends StatelessWidget {
  final double total;
  final String orderId;
  const _OrderBanner({required this.total, required this.orderId});

  String get _shortId {
    if (orderId.isEmpty) return 'Order';
    final id = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    return 'Order #${id.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) => Container(
        color:   AppColors.primary,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long,
                color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(_shortId,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.white.withOpacity(0.8))),
            Text('Total: £${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
              Icon(Icons.lock, size: 12, color: AppColors.white),
              SizedBox(width: 4),
              Text('Secure',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.white)),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  SAVED CARDS TAB
// ══════════════════════════════════════════════════════════
class _SavedCardsTab extends StatelessWidget {
  final List<Map<String, dynamic>> savedCards;
  final bool    isLoading;
  final String? selectedCardId;
  final bool    isProcessing;
  final double  orderTotal;
  final ValueChanged<String> onCardSelected;
  final VoidCallback         onPay, onAddNewCard, onRefresh;

  const _SavedCardsTab({
    required this.savedCards,
    required this.isLoading,
    required this.selectedCardId,
    required this.isProcessing,
    required this.orderTotal,
    required this.onCardSelected,
    required this.onPay,
    required this.onAddNewCard,
    required this.onRefresh,
  });

  Color _brandColor(String? b) {
    switch ((b ?? '').toLowerCase()) {
      case 'visa':       return const Color(0xFF1A1F71);
      case 'mastercard': return const Color(0xFFEB001B);
      case 'amex':       return const Color(0xFF016FD0);
      case 'discover':   return const Color(0xFFFF6600);
      default:           return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading your cards...',
              style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }

    if (savedCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle),
              child: const Icon(Icons.credit_card_off_outlined,
                  size: 52, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('No saved cards',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'Add a new card to pay quickly next time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddNewCard,
              icon:  const Icon(Icons.add_card),
              label: const Text('Use New Card'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14)),
            ),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        const Text('Choose a card to pay with',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        ...savedCards.map((card) {
          final cardId   = (card['id'] ?? card['cardId'])?.toString() ?? '';
          final last4    = card['last4']?.toString() ?? '••••';
          final brand    = card['brand']?.toString() ?? 'Card';
          final expMonth = card['expMonth']?.toString() ?? '';
          final expYear  = card['expYear']?.toString() ?? '';
          final isDef    = card['isDefault'] == true;
          final isSel    = cardId == selectedCardId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => onCardSelected(cardId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.primary.withOpacity(0.06)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSel
                          ? AppColors.primary
                          : AppColors.border,
                      width: isSel ? 2 : 1),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: AppColors.primary
                                  .withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(children: [
                  Icon(Icons.credit_card,
                      color: _brandColor(brand), size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text(
                          '${brand[0].toUpperCase()}'
                          '${brand.substring(1)} •••• $last4',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        if (isDef) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success
                                  .withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: const Text('Default',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        AppColors.success)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        (expMonth.isNotEmpty &&
                                expYear.isNotEmpty)
                            ? 'Expires $expMonth/$expYear'
                            : 'Saved card',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ]),
                  ),
                  Radio<String>(
                    value:       cardId,
                    groupValue:  selectedCardId,
                    onChanged:   (v) => onCardSelected(v!),
                    activeColor: AppColors.primary,
                  ),
                ]),
              ),
            ),
          );
        }),

        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onAddNewCard,
          icon:  const Icon(Icons.add_card, size: 18),
          label: const Text('Use a different card'),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isProcessing ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: isProcessing
                ? const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color:       AppColors.white,
                            strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Processing payment...',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ])
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 18),
                      const SizedBox(width: 10),
                      Text(
                          'Pay  £${orderTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ]),
          ),
        ),
        const SizedBox(height: 12),
        const _SecureNote(),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NEW CARD TAB
//
//  CHANGE 1: Removed the "Amount to pay" container.
//  CHANGE 2: Added isSavingCard indicator so user sees
//            feedback when card-save API is in progress.
//  CHANGE 3: Save card toggle now logs to console.
// ══════════════════════════════════════════════════════════
class _NewCardTab extends StatelessWidget {
  final bool     saveCard;
  final bool     isPaying;
  final bool     isSavingCard; // ← NEW
  final double   orderTotal;
  final ValueChanged<bool> onSaveToggle;
  final VoidCallback       onPay;

  const _NewCardTab({
    required this.saveCard,
    required this.isPaying,
    required this.isSavingCard,
    required this.orderTotal,
    required this.onSaveToggle,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

        // ── Stripe info card ──────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Row(children: [
              Icon(Icons.contactless,
                  color: AppColors.white, size: 26),
              SizedBox(width: 12),
              Text('Secure Card Payment',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white)),
            ]),
            const SizedBox(height: 12),
            Text(
              'You\'ll be taken to Stripe\'s secure payment sheet. '
              'Your card details are encrypted end-to-end and never '
              'touch our servers.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.white.withOpacity(0.85),
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            const Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
              _CardBadge('VISA'),
              _CardBadge('Mastercard'),
              _CardBadge('Amex'),
              _CardBadge('Apple Pay'),
              _CardBadge('Google Pay'),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Feature rows ──────────────────────────────
        const _FeatureRow(
            Icons.shield_outlined,
            'Encrypted & Secure',
            'Your card details never touch our servers.'),
        const SizedBox(height: 12),
        const _FeatureRow(
            Icons.verified_user_outlined,
            'Powered by Stripe',
            'PCI-DSS Level 1 certified payment provider.'),
        const SizedBox(height: 12),
        const _FeatureRow(
            Icons.replay_outlined,
            'Easy Refunds',
            'Refunds processed within 5–10 business days.'),
        const SizedBox(height: 24),

        // ── Save card toggle ──────────────────────────
        // Shows a spinner inside the tile if card-save is in progress
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Text('Save card for next time',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  // ← spinner while saving
                  if (isSavingCard) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  isSavingCard
                      ? 'Saving your card...'
                      : 'Skip card entry on future orders',
                  style: TextStyle(
                      fontSize: 12,
                      color: isSavingCard
                          ? AppColors.primary
                          : AppColors.textSecondary),
                ),
              ]),
            ),
            Switch(
              value:       saveCard,
              onChanged:   isSavingCard ? null : onSaveToggle,
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Pay button ────────────────────────────────
        // NOTE: "Amount to pay" container has been removed as requested.
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: (isPaying || isSavingCard) ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: isPaying
                ? const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color:       AppColors.white,
                            strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Opening payment...',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ])
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 18),
                      const SizedBox(width: 10),
                      Text(
                          'Pay  £${orderTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ]),
          ),
        ),
        const SizedBox(height: 12),
        const _SecureNote(),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════
class _CardBadge extends StatelessWidget {
  final String label;
  const _CardBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        AppColors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.white)),
      );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   title, subtitle;
  const _FeatureRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ]),
        ),
      ]);
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user,
              size: 14, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text('Powered by Stripe  •  PCI-DSS Compliant',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary)),
        ],
      );
}