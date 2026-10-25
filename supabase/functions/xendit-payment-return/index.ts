Deno.serve((request) => {
  const url = new URL(request.url);
  const transactionId = url.searchParams.get('transaction_id') ?? '';
  const result = url.searchParams.get('result') === 'cancel'
    ? 'cancel'
    : 'success';
  if (!/^[0-9a-f-]{36}$/i.test(transactionId)) {
    return new Response('Invalid payment reference.', {status: 400});
  }
  const deepLink =
    `io.supabase.tkoi://payment-callback?transaction_id=${transactionId}&result=${result}`;
  // Supabase's default Edge Function domain serves HTML responses as plain
  // text. Redirect directly to the registered Android deep link instead.
  return new Response(null, {
    status: 302,
    headers: {
      Location: deepLink,
      'Cache-Control': 'no-store',
    },
  });
});
