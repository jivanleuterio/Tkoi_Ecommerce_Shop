import {createClient} from 'npm:@supabase/supabase-js@2';
import {jsonResponse} from '../_shared/cors.ts';
import {getSecretKey} from '../_shared/supabase_keys.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({error: 'Method not allowed.'}, 405);
  }
  const callbackToken = Deno.env.get('XENDIT_WEBHOOK_TOKEN');
  const receivedToken = request.headers.get('x-callback-token');
  if (!callbackToken || receivedToken !== callbackToken) {
    return jsonResponse({error: 'Invalid webhook token.'}, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = getSecretKey();
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({error: 'Server configuration is incomplete.'}, 503);
  }

  try {
    const payload = await request.json();
    const event = String(payload.event ?? '');
    const data = payload.data ?? {};
    const referenceId = String(data.reference_id ?? '');
    const match = /^tkoi_([0-9a-f-]{36})$/i.exec(referenceId);
    // Xendit's dashboard sends a sample reference when "Test & Save" is used.
    // Acknowledge non-Tkoi events after token verification, but never update data.
    if (!match) {
      return jsonResponse({received: true, ignored: true});
    }
    const transactionId = match[1];
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    if (event === 'payment_session.completed' && data.status === 'COMPLETED') {
      const {error} = await adminClient.rpc('complete_xendit_payment', {
        p_transaction_id: transactionId,
        p_session_id: data.payment_session_id,
        p_payment_id: data.payment_id ?? data.latest_payment_request_id ?? '',
        p_amount: data.amount,
        p_currency: data.currency,
      });
      if (error) throw new Error(error.message);
    } else if (event === 'payment_session.expired') {
      const {error} = await adminClient.rpc('fail_xendit_payment', {
        p_transaction_id: transactionId,
        p_status: 'expired',
        p_reason: 'Xendit session expired',
      });
      if (error) throw new Error(error.message);
    } else {
      return jsonResponse({received: true, ignored: true});
    }
    return jsonResponse({received: true});
  } catch (error) {
    return jsonResponse(
      {error: error instanceof Error ? error.message : 'Webhook failed.'},
      400,
    );
  }
});
