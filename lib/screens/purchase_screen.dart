import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/purchase_services.dart';

class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscripción Pro'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.purple.shade800,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Consumer<PurchaseService>(
              builder: (context, purchaseService, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(context, purchaseService),
                    const SizedBox(height: 30),
                    if (!purchaseService.isSubscribed)
                      _buildSubscriptionCard(context, purchaseService),
                    const SizedBox(height: 20),
                    _buildRestoreButton(context, purchaseService),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, PurchaseService service) {
    final statusStyle = Theme.of(context).textTheme.headline6?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);
    String statusText;
    String detailText;

    if (service.isSubscribed) {
      statusText = '¡Eres Pro!';
      detailText = 'Disfrutas de firmas ilimitadas.';
    } else {
      statusText = 'Modo Gratuito';
      detailText = 'Te quedan ${service.remainingSignatures} firmas.';
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(statusText, style: statusStyle),
            const SizedBox(height: 8),
            Text(detailText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, PurchaseService service) {
    final product = service.subscriptionProduct;
    if (product == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(product.title, style: Theme.of(context).textTheme.headline5?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 12),
            Text(product.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 20),
            Text(product.price, style: Theme.of(context).textTheme.headline4?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => service.buySubscription(),
              child: const Text('Suscribirse Ahora', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context, PurchaseService service) {
    return TextButton(
      onPressed: () => service.restorePurchases(),
      child: const Text(
        'Restaurar compras anteriores',
        style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
      ),
    );
  }
}
