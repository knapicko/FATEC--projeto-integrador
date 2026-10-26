class StripeConfig {
  StripeConfig._();

  // Chave publicável: pode ser usada no cliente para Elements/SDK de cartão.
  // Informe em tempo de execução com:
  // flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
  static const publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );
}
