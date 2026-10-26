import {createClient} from 'npm:@supabase/supabase-js@2';
import {corsHeaders, jsonResponse} from '../_shared/cors.ts';
import {getPublishableKey, getSecretKey} from '../_shared/supabase_keys.ts';

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

  try {
    const body = await request.json();
    const transactionId = String(body.transaction_id ?? '');
    const userClient = createClient(supabaseUrl, anonKey, {
      global: {headers: {Authorization: authorization}},
    });
    const {error: accessError} = await userClient.rpc(
      'assert_account_allowed',
      {p_action_category: 'existing_order_completion'},
    );
    if (accessError) return jsonResponse({error: accessError.message}, 403);
    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const {data: transaction, error} = await userClient
      .from('payment_transactions')
      .select('id,status,xendit_session_id')
      .eq('id', transactionId)
      .single();
    if (error || !transaction) {
      return jsonResponse({error: 'Payment transaction not found.'}, 404);
    }
    if (transaction.status === 'paid') {
      return jsonResponse({error: 'A completed payment cannot be cancelled.'}, 409);
    }
    if (['expired', 'failed', 'cancelled'].includes(transaction.status)) {
      return jsonResponse({status: transaction.status});
    }

    if (transaction.xendit_session_id?.startsWith('ps-')) {
      const cancelResponse = await fetch(
        `https://api.xendit.co/sessions/${transaction.xendit_session_id}/cancel`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
            'Content-Type': 'application/json',
          },
        },
      );
      if (!cancelResponse.ok) {
        return jsonResponse(
          {error: 'Xendit can no longer cancel this session. Check its status.'},
          409,
        );
      }
    }

    const {error: failError} = await adminClient.rpc('fail_xendit_payment', {
      p_transaction_id: transactionId,
      p_status: 'cancelled',
      p_reason: 'Cancelled by buyer',
    });
    if (failError) throw new Error(failError.message);
    return jsonResponse({status: 'cancelled'});
  } catch (error) {
    return jsonResponse(
      {error: error instanceof Error ? error.message : 'Cancellation failed.'},
      400,
    );
  }
});
