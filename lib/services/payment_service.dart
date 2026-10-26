import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/online_payment.dart';
import 'cart_service.dart';

class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<OnlinePayment> createXenditPayment({
    required String deliveryAddress,
    required String paymentChannel,
    bool testSimulator = false,
    String? buyNowProductId,
    int quantity = 1,
  }) async {
    final body = <String, dynamic>{
      'delivery_address': deliveryAddress.trim(),
      'payment_channel': paymentChannel,
      'test_simulator': testSimulator,
    };
    if (buyNowProductId != null) {
      body['product_id'] = buyNowProductId;
      body['quantity'] = quantity;
    }
    try {
      final response = await _client.functions.invoke(
        'create-xendit-payment',
        body: body,
      );
      final payment = OnlinePayment.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (buyNowProductId == null) CartService.notifyChanged();
      return payment;
    } on FunctionsHttpException catch (error) {
      if (error.status == 404) {
        throw Exception(
          'Online payment setup is incomplete. Deploy the '
          'create-xendit-payment Supabase Edge Function first.',
        );
      }
      throw Exception(_messageFrom(error.details));
    } on FunctionsRelayException {
      throw Exception(
        'Online payment setup is incomplete. Deploy the '
        'create-xendit-payment Supabase Edge Function first.',
      );
    } on FunctionsFetchException {
      throw Exception(
        'Could not reach the online payment server. Check your internet '
        'connection and Supabase Edge Function deployment.',
      );
    }
  }

  Future<String> getStatus(String transactionId) async {
    final data = await _client
        .from('payment_transactions')
        .select('status')
        .eq('id', transactionId)
        .single();
    return data['status'] as String? ?? 'pending';
  }

  Future<String?> getCheckoutUrl(String transactionId) async {
    final data = await _client
        .from('payment_transactions')
        .select('checkout_url')
        .eq('id', transactionId)
        .single();
    return data['checkout_url'] as String?;
  }

  Future<String> simulateTestPayment(String transactionId) async {
    try {
      final response = await _client.functions.invoke(
        'simulate-xendit-payment',
        body: {'transaction_id': transactionId},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['status'] as String? ?? 'pending';
    } on FunctionsHttpException catch (error) {
      throw Exception(_messageFrom(error.details));
    } on FunctionsRelayException {
      throw Exception('The Xendit test simulator is not deployed yet.');
    } on FunctionsFetchException {
      throw Exception(
        'Could not reach the Xendit test simulator. Check your connection.',
      );
    }
  }

  Future<void> cancel(String transactionId) async {
    try {
      await _client.functions.invoke(
        'cancel-xendit-payment',
        body: {'transaction_id': transactionId},
      );
    } on FunctionsHttpException catch (error) {
      throw Exception(_messageFrom(error.details));
    }
  }

  String _messageFrom(dynamic data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['error'] is String) {
          return decoded['error'] as String;
        }
      } catch (_) {
        // The server did not return JSON, so use the safe message below.
      }
    }
    return 'The online payment service is unavailable. Please try again.';
  }
}
