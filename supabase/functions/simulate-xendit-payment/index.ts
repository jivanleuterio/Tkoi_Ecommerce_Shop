import {createClient} from 'npm:@supabase/supabase-js@2';
import {corsHeaders, jsonResponse} from '../_shared/cors.ts';
import {getPublishableKey, getSecretKey} from '../_shared/supabase_keys.ts';

const apiVersion = '2024-11-11';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', {headers: corsHeaders});
  }
  if (request.method !== 'POST') {
    return jsonResponse({error: 'Method not allowed.'}, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = getPublishableKey();
  const serviceRoleKey = getSecretKey();
  const xenditSecretKey = Deno.env.get('XENDIT_SECRET_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !xenditSecretKey) {
    return jsonResponse({error: 'Online payment is not configured yet.'}, 503);
  }
  if (!xenditSecretKey.startsWith('xnd_development_')) {
    return jsonResponse(
      {error: 'Test payment simulation is disabled outside Xendit Test Mode.'},
      403,
    );
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization) return jsonResponse({error: 'Please sign in again.'}, 401);

  const xenditHeaders = {
    Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
    'Content-Type': 'application/json',
    'api-version': apiVersion,
  };

  try {
    const body = await request.json();
    const transactionId = String(body.transaction_id ?? '');
    const userClient = createClient(supabaseUrl, anonKey, {
      global: {headers: {Authorization: authorization}},
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const {data: authData, error: authError} = await userClient.auth.getUser();
    if (authError || !authData.user) {
      return jsonResponse({error: 'Please sign in again.'}, 401);
    }
    const {error: accessError} = await userClient.rpc(
      'assert_account_allowed',
      {p_action_category: 'commerce'},
    );
    if (accessError) return jsonResponse({error: accessError.message}, 403);

    const {data: transaction, error: transactionError} = await userClient
      .from('payment_transactions')
      .select('id,buyer_id,amount,currency,status,xendit_session_id')
      .eq('id', transactionId)
      .single();
    if (transactionError || !transaction || transaction.buyer_id !== authData.user.id) {
      return jsonResponse({error: 'Payment transaction not found.'}, 404);
    }
    if (transaction.status === 'paid') return jsonResponse({status: 'paid'});
    if (['expired', 'failed', 'cancelled'].includes(transaction.status)) {
      return jsonResponse({status: transaction.status});
    }

    const paymentRequestId = String(transaction.xendit_session_id ?? '');
    if (!paymentRequestId.startsWith('pr-')) {
      return jsonResponse(
        {error: 'Use Xendit Demo Payment to run the one-tap simulation.'},
        409,
      );
    }

    const loadPaymentRequest = async () => {
      const response = await fetch(
        `https://api.xendit.co/v3/payment_requests/${paymentRequestId}`,
        {headers: xenditHeaders},
      );
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? 'Could not check the Xendit test payment.');
      }
      return data;
    };

    const completeIfReady = async (paymentRequest: Record<string, unknown>) => {
      const expectedReference = `tkoi_${transactionId}`;
      if (
        paymentRequest.reference_id !== expectedReference ||
        paymentRequest.currency !== 'PHP' ||
        Number(paymentRequest.request_amount) !== Number(transaction.amount)
      ) {
        throw new Error('Xendit test payment verification failed.');
      }
      if (paymentRequest.status !== 'SUCCEEDED') return false;

      const latestPayment = paymentRequest.latest_payment as
        | Record<string, unknown>
        | undefined;
      const paymentId = String(
        paymentRequest.latest_payment_id ??
          latestPayment?.payment_id ??
          paymentRequestId,
      );
      const {error} = await adminClient.rpc('complete_xendit_payment', {
        p_transaction_id: transactionId,
        p_session_id: paymentRequestId,
        p_payment_id: paymentId,
        p_amount: Number(transaction.amount),
        p_currency: 'PHP',
      });
      if (error) throw new Error(error.message);
      return true;
    };

    let paymentRequest = await loadPaymentRequest();
    if (await completeIfReady(paymentRequest)) {
      return jsonResponse({status: 'paid'});
    }

    const simulateResponse = await fetch(
      `https://api.xendit.co/v3/payment_requests/${paymentRequestId}/simulate`,
      {
        method: 'POST',
        headers: xenditHeaders,
        body: JSON.stringify({amount: Number(transaction.amount)}),
      },
    );
    const simulateData = await simulateResponse.json();
    if (!simulateResponse.ok) {
      throw new Error(
        simulateData.message ?? 'Xendit could not simulate the test payment.',
      );
    }

    for (let attempt = 0; attempt < 16; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 500));
      paymentRequest = await loadPaymentRequest();
      if (await completeIfReady(paymentRequest)) {
        return jsonResponse({status: 'paid'});
      }
      if (['FAILED', 'EXPIRED', 'CANCELED'].includes(paymentRequest.status)) {
        const failedStatus = paymentRequest.status === 'EXPIRED'
          ? 'expired'
          : paymentRequest.status === 'CANCELED'
          ? 'cancelled'
          : 'failed';
        await adminClient.rpc('fail_xendit_payment', {
          p_transaction_id: transactionId,
          p_status: failedStatus,
          p_reason: `Xendit test payment ${failedStatus}`,
        });
        return jsonResponse({status: failedStatus});
      }
    }

    return jsonResponse({status: 'pending'});
  } catch (error) {
    return jsonResponse(
      {error: error instanceof Error ? error.message : 'Test payment failed.'},
      400,
    );
  }
});
