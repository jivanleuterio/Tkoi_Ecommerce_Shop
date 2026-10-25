# Tkoi

Tkoi is a beginner-friendly Flutter and Supabase marketplace where every user
can buy fish and create one shop to sell fish.

## Supabase setup (required once)

The original project used a small Xendit demo table. The new schema uses UUIDs
and different fields, so `supabase/schema.sql` resets the marketplace
tables. Back up any old product or order rows you want to keep.

1. Open your Supabase project at https://supabase.com/dashboard.
2. Select **SQL Editor** and click **New query**.
3. Open `supabase/schema.sql` from this project and copy all of it.
4. Paste it into the SQL Editor and click **Run**.
5. Open `supabase/security_hardening.sql`, copy it into a new SQL query, and
   click **Run**. This enforces validation and verified-phone seller policies in
   the database, including projects that already ran the original schema.
6. Open **Authentication → Providers → Email** and make sure Email is enabled.
7. Keep **Confirm email** enabled. Set **Email OTP length** to `6`, set
   **Email OTP expiration** to `3600` seconds, and save the provider settings.
8. Open **Authentication → Emails → Templates →
   Confirm signup**. Replace the message with the OTP template shown below.
9. Open **Authentication → URL Configuration**. Under **Redirect URLs**, add
   `io.supabase.tkoi://reset-callback` so APK password-reset links return to Tkoi.
10. Open **Storage**. Confirm these public buckets now exist:
   `profile-pictures`, `shop-logos`, and `product-images`.

Use this **Confirm signup** email template so registration sends a code instead
of a confirmation button:

```html
<h2>Verify your Tkoi account</h2>
<p>Enter this six-digit code in the Tkoi app:</p>
<h1>{{ .Token }}</h1>
<p>This code expires shortly. Ignore this email if you did not register.</p>
```

Use exactly `{{ .Token }}` in the template. Do not display `{{ .TokenHash }}`
or `{{ .ConfirmationURL }}` as the code. After changing the OTP length, request
a new code in Tkoi; an older eight-digit email code cannot be shortened or
reused.

The SQL creates tables, indexes, profile triggers, stock-safe ordering functions,
Row Level Security policies, buckets, and storage policies. Never put a Supabase
service-role key in this app. The existing publishable key in
`lib/config/app_config.dart` is the correct client-side key.

### Existing project: cart and Buy Now update

If you already ran `schema.sql` before the cart fix, do not reset the database.
Run only this small migration:

1. Open **Supabase → SQL Editor → New query**.
2. Open `supabase/cart_transactions_fix.sql` in VS Code and copy all its text.
3. Paste it into Supabase and click **Run**.
4. Fully stop and rerun the Flutter app.

This preserves accounts, shops, fish, carts, and orders. It removes a circular
Row Level Security check and installs atomic **Add to cart** and **Buy now**
database functions.

## Run the app

```powershell
flutter pub get
flutter run
```

For a clean rerun:

```powershell
flutter clean
flutter pub get
flutter run
```

## Phone verification for sellers

Tkoi signs users in by email, but blocks the Sell area until their phone number
has been verified with a six-digit Supabase `phone_change` OTP. Real SMS delivery
requires enabling Phone under **Authentication → Sign In / Providers** and
configuring a supported SMS provider. Supabase does not deliver real SMS by
itself. For classroom development without SMS costs, use a Supabase test phone
number/test OTP if that option is available in your project, or use the already
verified Fisherman demo account below.

## Ordering behavior

Checkout supports Cash on Delivery and Xendit hosted online payment. A cart
containing fish from multiple shops is split into one order per shop. The
database locks and rechecks stock, rejects purchases of the buyer's own listing,
prevents negative stock, and reduces stock in the same transaction.

Buyers first choose a visible method: GCash, Maya, credit/debit card, BPI, BDO,
UnionBank, or QRPh. While `useXenditTestSimulator` is enabled, every online
choice creates a QRPh Payment Request in Xendit Test Mode and completes it
through Xendit's official simulation API after the buyer taps **Proceed to
Xendit**. The selected method is still saved on the order, but no real card,
bank, or mobile details are requested. The server automatically rejects the
simulator if a live Xendit key is used.

## Enable Xendit online payments

Start with **Xendit Test Mode**. Never paste a Xendit secret key into Flutter,
`app_config.dart`, source control, or a screenshot.

### 1. Update the database

1. Open **Supabase → SQL Editor → New query**.
2. Copy all of `supabase/online_payments.sql` into the editor. It is safe to run
   this file again when updating an existing Tkoi database.
3. Click **Run**. This migration preserves existing accounts and orders.

### 2. Create the Xendit test credentials

1. In Xendit Test Mode, open **Settings → Developers → API Keys**.
2. Create a secret API key with only the required money-in/write permission.
3. Open **Settings → Webhooks** and copy the webhook verification token.

Test Mode normally exposes its test channels. Before Live Mode, activate every
channel you want to show under **Xendit → Payment Channels**. If a selected
channel is not activated, Xendit will reject that checkout instead of silently
switching to another method.

### 3. Store secrets in Supabase

1. Open **Supabase → Edge Functions → Secrets**.
2. Add `XENDIT_SECRET_KEY` with the Xendit test secret key.
3. Add `XENDIT_WEBHOOK_TOKEN` with the Xendit webhook token.
4. Save. Supabase already provides its URL and server-side service key to Edge
   Functions; do not create or expose a service-role key in Flutter.

### 4. Deploy the Edge Functions

From the project folder in the VS Code terminal, run:

```powershell
npx supabase login
npx supabase link --project-ref kofbuodhxfjhvzbdorve
npx supabase functions deploy create-xendit-payment --use-api
npx supabase functions deploy cancel-xendit-payment --use-api
npx supabase functions deploy xendit-webhook --no-verify-jwt --use-api
npx supabase functions deploy xendit-payment-return --no-verify-jwt --use-api
```

`supabase/config.toml` also records which public functions do not require a
user JWT.

### 5. Configure the Xendit webhooks

In **Xendit → Settings → Webhooks**, use this URL for both **Payment Session –
Completed** and **Payment Session – Expired**:

```text
https://kofbuodhxfjhvzbdorve.supabase.co/functions/v1/xendit-webhook
```

Click **Test & Save** for each webhook. A payment is marked paid only after this
verified webhook arrives. The seller cannot process an unpaid Xendit order.

If Tkoi says that online payment setup is incomplete, rerun
`supabase/online_payments.sql`, redeploy `create-xendit-payment`, and confirm
that both Supabase secrets exist. Restarting Flutter alone cannot install the
server-side payment service.

### Online payment lifecycle

Tkoi reserves stock and creates pending orders, then opens Xendit's hosted
checkout. A completed webhook marks every related order paid. A failed,
cancelled, or expired session cancels those orders and restores stock. Automated
refunds are not included yet, so sellers cannot cancel a paid Xendit order from
the app.

## Optional Fisherman sample account

Create and auto-confirm `fisherman.tkoi.demo@gmail.com` in **Authentication → Users**
with password `Fisherman123!`. Then run `supabase/seed_fisherman.sql` in the SQL
Editor. This creates the Fisherman shop, marks its sample number as verified,
and adds one listing for every fish category.
