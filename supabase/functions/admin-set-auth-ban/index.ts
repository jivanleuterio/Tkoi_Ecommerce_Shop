import {createClient} from 'npm:@supabase/supabase-js@2';
import {corsHeaders, jsonResponse} from '../_shared/cors.ts';
import {getPublishableKey, getSecretKey} from '../_shared/supabase_keys.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return jsonResponse({error: 'Method not allowed.'}, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = getPublishableKey();
  const secretKey = getSecretKey();
  const authorization = request.headers.get('Authorization');
  if (!supabaseUrl || !publishableKey || !secretKey) {
    return jsonResponse({error: 'Admin Auth moderation is not configured.'}, 503);
  }
  if (!authorization) return jsonResponse({error: 'Please sign in again.'}, 401);

  try {
    const body = await request.json();
    const targetUserId = String(body.user_id ?? '');
    const status = String(body.status ?? '');
    const restrictedUntil = body.restricted_until
      ? new Date(String(body.restricted_until))
      : null;
    if (!/^[0-9a-f-]{36}$/i.test(targetUserId)) {
      return jsonResponse({error: 'Invalid user.'}, 400);
    }
    if (!['active', 'suspended', 'banned'].includes(status)) {
      return jsonResponse({error: 'Invalid account status.'}, 400);
    }

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: {headers: {Authorization: authorization}},
    });
    const {data: authData, error: authError} = await userClient.auth.getUser();
    if (authError || !authData.user) return jsonResponse({error: 'Please sign in again.'}, 401);
    const {data: allowed, error: permissionError} = await userClient.rpc(
      'has_admin_permission',
      {p_permission: 'users.suspend'},
    );
    if (permissionError || allowed !== true) {
      return jsonResponse({error: 'You do not have permission to moderate accounts.'}, 403);
    }
    const {data: actionable, error: targetError} = await userClient.rpc(
      'admin_target_is_actionable',
      {p_target_user: targetUserId},
    );
    if (targetError || actionable !== true) {
      return jsonResponse({error: 'You cannot alter yourself or another admin account.'}, 403);
    }

    let banDuration = 'none';
    if (status === 'banned') banDuration = '876000h';
    if (status === 'suspended') {
      const until = restrictedUntil?.getTime() ?? Date.now() + 24 * 60 * 60 * 1000;
      const hours = Math.max(1, Math.ceil((until - Date.now()) / 3600000));
      banDuration = `${hours}h`;
    }
    const adminClient = createClient(supabaseUrl, secretKey, {
      auth: {autoRefreshToken: false, persistSession: false},
    });
    const {error} = await adminClient.auth.admin.updateUserById(targetUserId, {
      ban_duration: banDuration,
    });
    if (error) throw error;

    return jsonResponse({
      updated: true,
      warning:
        'Existing access tokens cannot always be revoked immediately. Database account controls remain the immediate enforcement layer.',
    });
  } catch (error) {
    return jsonResponse(
      {error: error instanceof Error ? error.message : 'Auth ban update failed.'},
      400,
    );
  }
});
