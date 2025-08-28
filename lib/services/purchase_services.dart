import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ID único de tu producto de suscripción.
// DEBE ser el mismo que configures en la Play Store y App Store.
const String _kSubscriptionId = 'solofirma_suscripcion_mensual';

// Límite de firmas gratuitas.
const int _kFreeSignaturesLimit = 3;

class PurchaseService with ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Estado de la suscripción del usuario
  DateTime? _subscriptionEndDate;
  bool get isSubscribed {
    if (_subscriptionEndDate == null) return false;
    return DateTime.now().isBefore(_subscriptionEndDate!);
  }

  // Contador de firmas
  int _signatureCount = 0;
  int get signatureCount => _signatureCount;
  int get remainingSignatures => isSubscribed ? 999 : _kFreeSignaturesLimit - _signatureCount; // Usuarios suscritos tienen "infinitas"

  // Productos disponibles en la tienda
  List<ProductDetails> _products = [];
  ProductDetails? get subscriptionProduct => _products.isNotEmpty ? _products.first : null;

  PurchaseService() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Manejar error
      print("Error en el stream de compras: $error");
    });
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSubscriptionStatus();
    final bool available = await _inAppPurchase.isAvailable();
    if (available) {
      await _loadProducts();
      // Siempre verifica compras pasadas al iniciar.
      restorePurchases();
    }
  }

  // Carga el estado de la suscripción desde el almacenamiento local
  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final endDateString = prefs.getString('subscriptionEndDate');
    if (endDateString != null) {
      _subscriptionEndDate = DateTime.tryParse(endDateString);
    }
    _signatureCount = prefs.getInt('signatureCount') ?? 0;
    notifyListeners();
  }

  // Carga los productos definidos en las tiendas
  Future<void> _loadProducts() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({_kSubscriptionId});
    if (response.notFoundIDs.isEmpty) {
      _products = response.productDetails;
    }
    notifyListeners();
  }

  // Inicia el flujo de compra de la suscripción
  Future<void> buySubscription() async {
    if (subscriptionProduct == null) return;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: subscriptionProduct!);
    // El mismo método `buyNonConsumable` se usa para iniciar la compra de suscripciones.
    // La distinción la hace el tipo de producto configurado en la tienda.
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Restaura compras previas
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  // Escucha las actualizaciones del stream de compras
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        
        // Asumiendo una suscripción de 30 días.
        // Para una implementación real, se debería validar el recibo con un backend
        // y obtener la fecha de expiración real de los servidores de Apple/Google.
        await _handleSuccessfulPurchase(const Duration(days: 30));

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
      // Aquí puedes manejar otros estados como .error o .pending
    }
  }

  // Maneja una compra/restauración exitosa
  Future<void> _handleSuccessfulPurchase(Duration subscriptionDuration) async {
    final prefs = await SharedPreferences.getInstance();
    // Si la suscripción ya existe y es válida, la extendemos. Si no, creamos una nueva.
    final currentEndDate = _subscriptionEndDate;
    var newEndDate = (currentEndDate != null && currentEndDate.isAfter(DateTime.now()))
        ? currentEndDate.add(subscriptionDuration)
        : DateTime.now().add(subscriptionDuration);

    await prefs.setString('subscriptionEndDate', newEndDate.toIso8601String());
    _subscriptionEndDate = newEndDate;
    notifyListeners();
  }

  // Verifica si el usuario puede firmar
  bool canUserSign() {
    if (isSubscribed || _signatureCount < _kFreeSignaturesLimit) {
      return true;
    }
    return false;
  }

  // Incrementa el contador de firmas
  Future<void> incrementSignatureCount() async {
    if (isSubscribed) return; // Los usuarios suscritos no tienen contador
    final prefs = await SharedPreferences.getInstance();
    _signatureCount++;
    await prefs.setInt('signatureCount', _signatureCount);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}