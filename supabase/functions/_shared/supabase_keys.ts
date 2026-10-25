function keyFromCollection(name: string): string | undefined {
  const raw = Deno.env.get(name);
  if (!raw) return undefined;
  try {
    const keys = JSON.parse(raw) as Record<string, string>;
    return keys.default ?? Object.values(keys)[0];
  } catch {
    return undefined;
  }
}

export function getPublishableKey(): string | undefined {
  return Deno.env.get('SUPABASE_ANON_KEY') ??
    keyFromCollection('SUPABASE_PUBLISHABLE_KEYS');
}

export function getSecretKey(): string | undefined {
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
    keyFromCollection('SUPABASE_SECRET_KEYS');
}
