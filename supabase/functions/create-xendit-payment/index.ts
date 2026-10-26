import {createClient} from 'npm:@supabase/supabase-js@2';
import {corsHeaders, jsonResponse} from '../_shared/cors.ts';
import {getPublishableKey, getSecretKey} from '../_shared/supabase_keys.ts';

type CheckoutBody = {
  delivery_address?: string;
  payment_channel?: string;
  test_simulator?: boolean;
  product_id?: string;
  quantity?: number;
};

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

  const authorization = request.headers.get('Authorization');
  if (!authorization) return jsonResponse({error: 'Please sign in again.'}, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: {headers: {Authorization: authorization}},
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  let transactionId: string | null = null;

  try {
    const {data: authData, error: authError} = await userClient.auth.getUser();
    if (authError || !authData.user) {
      return jsonResponse({error: 'Please sign in again.'}, 401);
    }
    const {error: accessError} = await userClient.rpc(
      'assert_account_allowed',
      {p_action_category: 'commerce'},
    );
    if (accessError) return jsonResponse({error: accessError.message}, 403);

    const body = (await request.json()) as CheckoutBody;
    const deliveryAddress = body.delivery_address?.trim() ?? '';
    const paymentChannel = body.payment_channel ?? '';
    const useTestSimulator = body.test_simulator === true;
    const supportedChannels = [
      'GCASH',
      'PAYMAYA',
      'CARDS',
      'BPI_ONLINE_BANKING',
      'BDO_ONLINE_BANKING',
      'UNIONBANK_ONLINE_BANKING',
      'QRPH',
    ];
    if (deliveryAddress.length < 10 || deliveryAddress.length > 300) {
      return jsonResponse({error: 'Enter a valid delivery address.'}, 400);
    }
    if (!supportedChannels.includes(paymentChannel)) {
      return jsonResponse({error: 'Choose a supported payment method.'}, 400);
    }
    if (useTestSimulator && !xenditSecretKey.startsWith('xnd_development_')) {
      return jsonResponse(
        {error: 'The one-tap simulator is available only in Xendit Test Mode.'},
        403,
      );
    }

    const rpcName = body.product_id
      ? 'prepare_xendit_buy_now'
      : 'prepare_xendit_cart';
    const rpcParams = body.product_id
      ? {
          p_product_id: body.product_id,
          p_quantity: body.quantity ?? 1,
          p_delivery_address: deliveryAddress,
          p_payment_channel: paymentChannel,
        }
      : {
          p_delivery_address: deliveryAddress,
          p_payment_channel: paymentChannel,
        };
    const {data: prepared, error: prepareError} = await userClient.rpc(
      rpcName,
      rpcParams,
    );
    if (prepareError) throw new Error(prepareError.message);

    transactionId = String(prepared.transaction_id);
    const amount = Number(prepared.amount);
    const {data: profile, error: profileError} = await userClient
      .from('profiles')
      .select('full_name,email,mobile_number')
      .eq('id', authData.user.id)
      .single();
    if (profileError) throw new Error(profileError.message);

    const safeName = String(profile.full_name)
      .replace(/[^A-Za-z0-9 ]/g, '')
      .trim();
    const nameParts = safeName.split(/\s+/);
    const givenNames = nameParts.shift() || 'Tkoi';
    const surname = nameParts.join(' ') || 'Customer';
    const rawMobile = String(profile.mobile_number ?? '').replace(/\s+/g, '');
    const mobileNumber = rawMobile.startsWith('09')
      ? `+63${rawMobile.substring(1)}`
      : rawMobile;
    const returnBase = `${supabaseUrl}/functions/v1/xendit-payment-return`;
    const referenceId = `tkoi_${transactionId}`;
    const customerReferenceId = `customer${transactionId.replaceAll('-', '')}`;

    if (useTestSimulator) {
      const requestResponse = await fetch(
        'https://api.xendit.co/v3/payment_requests',
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
            'Content-Type': 'application/json',
            'api-version': '2024-11-11',
          },
          body: JSON.stringify({
            reference_id: referenceId,
            type: 'PAY',
            country: 'PH',
            currency: 'PHP',
            request_amount: amount,
            capture_method: 'AUTOMATIC',
            channel_code: 'QRPH',
            channel_properties: {},
            description: `Tkoi ${paymentChannel} classroom test payment`,
            metadata: {
              tkoi_transaction_id: transactionId,
              selected_channel: paymentChannel,
            },
          }),
        },
      );
      const requestData = await requestResponse.json();
      if (!requestResponse.ok || !requestData.payment_request_id) {
        throw new Error(
          requestData.message ?? 'Xendit could not create the test payment.',
        );
      }

      const {error: testRequestError} = await adminClient.rpc(
        'set_xendit_session',
        {
          p_transaction_id: transactionId,
          p_session_id: requestData.payment_request_id,
          p_checkout_url:
            `${returnBase}?transaction_id=${transactionId}&result=success`,
          p_expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
        },
      );
      if (testRequestError) throw new Error(testRequestError.message);

      return jsonResponse({
        transaction_id: transactionId,
        test_mode: true,
      });
    }

    const xenditResponse = await fetch('https://api.xendit.co/sessions', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        reference_id: referenceId,
        session_type: 'PAY',
        mode: 'PAYMENT_LINK',
        amount,
        currency: 'PHP',
        country: 'PH',
        locale: 'en',
        description: 'Tkoi fish marketplace order',
        allowed_payment_channels: [paymentChannel],
        customer: {
          reference_id: customerReferenceId,
          type: 'INDIVIDUAL',
          email: profile.email,
          mobile_number: mobileNumber,
          individual_detail: {
            given_names: givenNames,
            surname,
          },
        },
        success_return_url:
          `${returnBase}?transaction_id=${transactionId}&result=success`,
        cancel_return_url:
          `${returnBase}?transaction_id=${transactionId}&result=cancel`,
        metadata: {
          tkoi_transaction_id: transactionId,
          payment_channel: paymentChannel,
        },
      }),
    });
    const xenditData = await xenditResponse.json();
    if (!xenditResponse.ok) {
      throw new Error(
        xenditData.message ?? 'Xendit could not create the payment session.',
      );
    }

    const {error: sessionError} = await adminClient.rpc(
      'set_xendit_session',
      {
        p_transaction_id: transactionId,
        p_session_id: xenditData.payment_session_id,
        p_checkout_url: xenditData.payment_link_url,
        p_expires_at: xenditData.expires_at,
      },
    );
    if (sessionError) throw new Error(sessionError.message);

    return jsonResponse({
      transaction_id: transactionId,
      checkout_url: xenditData.payment_link_url,
    });
  } catch (error) {
    if (transactionId) {
      await adminClient.rpc('fail_xendit_payment', {
        p_transaction_id: transactionId,
        p_status: 'failed',
        p_reason: error instanceof Error ? error.message : 'Setup failed',
      });
    }
    return jsonResponse(
      {error: error instanceof Error ? error.message : 'Payment setup failed.'},
      400,
    );
  }
});
