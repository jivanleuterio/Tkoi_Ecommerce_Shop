const pptxgen = require('pptxgenjs');
const path = require('path');
const fs = require('fs');

const pptx = new pptxgen();
pptx.layout = 'LAYOUT_WIDE';
pptx.author = 'OpenAI Codex';
pptx.company = 'Tkoi';
pptx.subject = 'Tkoi system walkthrough and functional documentation';
pptx.title = 'Tkoi System Walkthrough';
pptx.lang = 'en-US';
pptx.theme = {
  headFontFace: 'Aptos Display',
  bodyFontFace: 'Aptos',
  lang: 'en-US',
};

const C = {
  cream: 'FFF8F0',
  paper: 'FFFFFF',
  navy: '172033',
  muted: '667085',
  line: 'E8DED4',
  orange: 'FF6A16',
  red: 'EF2426',
  teal: '087B8B',
  aqua: '35D3C2',
  paleTeal: 'E8F7F5',
  paleOrange: 'FFF0E4',
  green: '159447',
  yellow: 'F3BD24',
};

const root = __dirname;
const shots = path.join(root, 'assets', 'screenshots');
const logo = path.resolve(root, '..', '..', 'assets', 'images', 'tkoi_logo.png');
const out = path.join(root, 'Tkoi_System_Walkthrough_Final.pptx');

const img = (name) => path.join(shots, name);
const slideNum = () => pptx._slides.length + 1;

function addBg(slide, color = C.cream) {
  slide.background = { color };
  slide.addShape(pptx.ShapeType.ellipse, {
    x: 10.95, y: -0.55, w: 3.1, h: 2.2,
    rotate: 18,
    fill: { color: C.paleOrange, transparency: 25 },
    line: { color: C.paleOrange, transparency: 100 },
  });
  slide.addShape(pptx.ShapeType.ellipse, {
    x: -0.55, y: 5.78, w: 2.5, h: 2.15,
    rotate: 210,
    fill: { color: C.paleTeal, transparency: 18 },
    line: { color: C.paleTeal, transparency: 100 },
  });
}

function addHeader(slide, title, section, subtitle) {
  addBg(slide);
  if (section) {
    slide.addText(section.toUpperCase(), {
      x: 0.72, y: 0.38, w: 3.4, h: 0.24,
      fontFace: 'Aptos', fontSize: 10.5, bold: true,
      color: C.teal, charSpacing: 1.5, margin: 0,
    });
  }
  slide.addText(title, {
    x: 0.70, y: 0.70, w: 11.9, h: 0.55,
    fontFace: 'Aptos Display', fontSize: 29, bold: true,
    color: C.navy, margin: 0, breakLine: false, fit: 'shrink',
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.72, y: 1.28, w: 11.65, h: 0.42,
      fontFace: 'Aptos', fontSize: 14.5, color: C.muted,
      margin: 0, fit: 'shrink',
    });
  }
  slide.addText(String(slideNum()).padStart(2, '0'), {
    x: 12.18, y: 7.04, w: 0.45, h: 0.18,
    fontSize: 9, color: '9A8F86', align: 'right', margin: 0,
  });
}

function addPhone(slide, file, x, y, h = 5.45, opts = {}) {
  const w = h * (465 / 864);
  slide.addShape(pptx.ShapeType.roundRect, {
    x: x - 0.07, y: y - 0.07, w: w + 0.14, h: h + 0.14,
    rectRadius: 0.12,
    fill: { color: opts.frameColor || C.navy },
    line: { color: opts.frameColor || C.navy, transparency: 100 },
    shadow: { type: 'outer', color: '6D6258', blur: 2, angle: 45, distance: 1, opacity: 0.18 },
  });
  slide.addImage({ path: file, x, y, w, h });
  if (opts.label) {
    slide.addText(opts.label, {
      x: x - 0.02, y: y + h + 0.12, w: w + 0.04, h: 0.25,
      fontSize: 10.5, bold: true, color: C.muted, align: 'center', margin: 0,
    });
  }
  return w;
}

function addBullets(slide, bullets, x, y, w, h, options = {}) {
  const runs = [];
  bullets.forEach((b, i) => {
    runs.push({
      text: b,
      options: {
        bullet: { indent: 18 }, hanging: 4,
        breakLine: i < bullets.length - 1,
        paraSpaceAfterPt: options.spaceAfter || 12,
      },
    });
  });
  slide.addText(runs, {
    x, y, w, h,
    fontFace: 'Aptos', fontSize: options.fontSize || 18,
    color: C.navy, breakLine: false,
    margin: 0.05, valign: 'mid', fit: 'shrink',
    bullet: { type: 'bullet' },
  });
}

function addCallout(slide, title, text, x, y, w, color = C.teal) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x, y, w, h: 1.08,
    rectRadius: 0.08,
    fill: { color: color === C.orange ? C.paleOrange : C.paleTeal },
    line: { color, transparency: 55, width: 1 },
  });
  slide.addText(title, {
    x: x + 0.18, y: y + 0.13, w: w - 0.36, h: 0.24,
    fontSize: 13, bold: true, color, margin: 0,
  });
  slide.addText(text, {
    x: x + 0.18, y: y + 0.42, w: w - 0.36, h: 0.48,
    fontSize: 12.5, color: C.navy, margin: 0, fit: 'shrink',
  });
}

function addNotes(slide, sources) {
  void slide;
  void sources;
}

function screenshotSlide({ title, section, subtitle, image, bullets, callout, note }) {
  const slide = pptx.addSlide();
  addHeader(slide, title, section, subtitle);
  addPhone(slide, img(image), 0.88, 1.72, 5.25);
  addBullets(slide, bullets, 4.55, 1.78, 7.55, callout ? 3.65 : 4.85);
  if (callout) addCallout(slide, callout.title, callout.text, 4.55, 5.62, 7.55, callout.color);
  addNotes(slide, [image, note]);
  return slide;
}

function pairSlide({ title, section, subtitle, images, bullets, note }) {
  const slide = pptx.addSlide();
  addHeader(slide, title, section, subtitle);
  addPhone(slide, img(images[0].file), 0.70, 1.76, 4.92, { label: images[0].label });
  addPhone(slide, img(images[1].file), 3.55, 1.76, 4.92, { label: images[1].label });
  addBullets(slide, bullets, 6.55, 1.80, 5.78, 4.95, { fontSize: 16.5, spaceAfter: 9 });
  addNotes(slide, [images[0].file, images[1].file, note]);
  return slide;
}

// 1. Cover
{
  const slide = pptx.addSlide();
  slide.background = { color: C.cream };
  slide.addShape(pptx.ShapeType.ellipse, {
    x: 8.65, y: -0.85, w: 5.6, h: 4.4, rotate: 18,
    fill: { color: C.orange, transparency: 5 }, line: { color: C.orange, transparency: 100 },
  });
  slide.addShape(pptx.ShapeType.ellipse, {
    x: 9.65, y: 3.25, w: 4.25, h: 4.65, rotate: 205,
    fill: { color: C.aqua, transparency: 18 }, line: { color: C.aqua, transparency: 100 },
  });
  if (fs.existsSync(logo)) slide.addImage({ path: logo, x: 0.85, y: 0.65, w: 1.72, h: 1.08, transparency: 0 });
  slide.addText('Tkoi System\nWalkthrough', {
    x: 0.86, y: 2.05, w: 7.65, h: 1.9,
    fontFace: 'Aptos Display', fontSize: 42, bold: true,
    color: C.navy, margin: 0, breakLine: false, fit: 'shrink',
  });
  slide.addText('Screens, workflows, roles, business rules, and technical architecture', {
    x: 0.88, y: 4.18, w: 7.25, h: 0.62,
    fontSize: 19, color: C.muted, margin: 0, fit: 'shrink',
  });
  slide.addText('Functional documentation • 26 October 2026', {
    x: 0.88, y: 6.35, w: 5.5, h: 0.3,
    fontSize: 12, bold: true, color: C.teal, margin: 0,
  });
  addNotes(slide, ['Tkoi source tree', 'assets/images/tkoi_logo.png']);
}

// 2. System map
{
  const slide = pptx.addSlide();
  addHeader(slide, 'Users, sellers, and administrators share one platform', 'System overview', 'Access changes according to account status, verified phone, and admin permissions.');
  const cols = [0.78, 4.48, 8.18];
  const items = [
    { t: 'Buyer', c: C.orange, body: 'Browse fish, search, save favorites, chat, checkout, track orders, request returns, review purchases, and contact support.' },
    { t: 'Seller', c: C.teal, body: 'A verified phone unlocks shop setup, listing management, order fulfillment, earnings, payout accounts, and withdrawals.' },
    { t: 'Administrator', c: C.navy, body: 'Permission-gated tools cover users, tickets, reports, content, orders, finance, audit logs, and the admin team.' },
  ];
  items.forEach((it, i) => {
    slide.addShape(pptx.ShapeType.roundRect, {
      x: cols[i], y: 2.05, w: 3.15, h: 3.75,
      rectRadius: 0.08, fill: { color: 'FFFFFF' },
      line: { color: it.c, transparency: 45, width: 1.4 },
      shadow: { type: 'outer', color: '8B8178', blur: 1, angle: 45, distance: 1, opacity: 0.10 },
    });
    slide.addShape(pptx.ShapeType.ellipse, {
      x: cols[i] + 1.12, y: 2.36, w: 0.9, h: 0.9,
      fill: { color: it.c }, line: { color: it.c, transparency: 100 },
    });
    slide.addText(String(i + 1), {
      x: cols[i] + 1.12, y: 2.54, w: 0.9, h: 0.3,
      fontSize: 20, bold: true, color: 'FFFFFF', align: 'center', margin: 0,
    });
    slide.addText(it.t, {
      x: cols[i] + 0.25, y: 3.50, w: 2.65, h: 0.38,
      fontSize: 23, bold: true, color: it.c, align: 'center', margin: 0,
    });
    slide.addText(it.body, {
      x: cols[i] + 0.30, y: 4.05, w: 2.55, h: 1.35,
      fontSize: 15.2, color: C.navy, align: 'center', valign: 'mid', margin: 0.04, fit: 'shrink',
    });
  });
  addCallout(slide, 'Account controls', 'Active accounts use the marketplace. Suspended accounts retain limited order and support access. Restricted accounts can appeal.', 2.02, 6.22, 9.35, C.orange);
  addNotes(slide, ['lib/screens/auth/auth_gate.dart', 'lib/screens/buyer/main_shell.dart', 'lib/screens/admin/admin_shell.dart']);
}

pairSlide({
  title: 'Sign-in and password recovery', section: 'Authentication',
  subtitle: 'Email authentication connects the user to the correct buyer, seller, restricted, or admin destination.',
  images: [
    { file: '22_login.png', label: 'Sign in' },
    { file: '24_password_recovery.png', label: 'Password recovery' },
  ],
  bullets: [
    'Users sign in with an email address and password.',
    'Password recovery sends a reset link to the registered email.',
    'The authentication gate resolves password recovery events before normal routing.',
    'Account status and admin role determine the first screen after authentication.',
  ],
  note: 'lib/screens/auth/login_screen.dart; lib/screens/auth/forgot_password_screen.dart; lib/screens/auth/auth_gate.dart',
});

screenshotSlide({
  title: 'Account registration', section: 'Authentication',
  subtitle: 'One account supports both buying and selling, while seller access requires an additional phone check.',
  image: '23_registration.png',
  bullets: [
    'Registration collects the user’s name, username, email, phone number, delivery address, and password.',
    'Supabase sends a six-digit email verification code before the account becomes usable.',
    'Password and field validators provide immediate feedback before submission.',
    'A verified phone number is required before creating or managing a fish shop.',
  ],
  callout: { title: 'Related screens', text: 'Email verification, phone verification, password reset, and restricted-account appeal are implemented as separate guarded flows.', color: C.teal },
  note: 'lib/screens/auth/register_screen.dart; verify_email_screen.dart; phone_verification_screen.dart; restricted_account_screen.dart',
});

screenshotSlide({
  title: 'Marketplace home', section: 'Buyer experience',
  subtitle: 'The home screen brings discovery, search, category browsing, cart access, and the primary navigation into one view.',
  image: '01_home.png',
  bullets: [
    'A personalized greeting and local-market indicator establish the user context.',
    'Search and category shortcuts help buyers narrow the catalog quickly.',
    'Featured fish cards show price, ratings, sold count, shop, location, and favorite count.',
    'Persistent navigation links Home, Search, Orders, Sell, and Profile.',
  ],
  callout: { title: 'Cart access', text: 'The bag icon opens the cart from the home, search, and order areas.', color: C.orange },
  note: 'lib/screens/buyer/home_screen.dart; lib/screens/buyer/main_shell.dart',
});

pairSlide({
  title: 'Catalog browsing and search', section: 'Buyer experience',
  subtitle: 'Buyers can scan visual product cards or search by fish name, species, and category.',
  images: [
    { file: '03_catalog.png', label: 'Product catalog' },
    { file: '02_search.png', label: 'Search and filters' },
  ],
  bullets: [
    'Product cards expose availability, stock, price, seller, location, ratings, sales, and favorites.',
    'Search supports listing name, species, or variety.',
    'Category chips provide quick filters for koi, goldfish, betta, guppy, and other types.',
    'Empty states explain the next action instead of leaving a blank screen.',
  ],
  note: 'lib/screens/buyer/home_screen.dart; lib/screens/buyer/search_screen.dart; lib/widgets/product_card_new.dart',
});

pairSlide({
  title: 'Fish details, seller context, and reviews', section: 'Buyer experience',
  subtitle: 'Each listing combines evidence about the fish with the seller identity and buyer feedback.',
  images: [
    { file: '04_product_details.png', label: 'Listing summary' },
    { file: '05_product_reviews.png', label: 'Seller and reviews' },
  ],
  bullets: [
    'The gallery presents listing photos, name, price, species, category, and availability.',
    'Buyer actions include favorite, report, add to cart, and Buy Now when the listing belongs to another seller.',
    'The seller panel links to the shop profile and conversation workflow.',
    'Review filters support all ratings or a selected star score.',
  ],
  note: 'lib/screens/buyer/product_details_screen.dart; lib/widgets/product_reviews_section.dart; lib/widgets/report_button.dart',
});

{
  const slide = pptx.addSlide();
  addHeader(slide, 'Cart, checkout, and payment choices', 'Buyer experience', 'The transaction flow supports shop-level order splitting and both cash and hosted online payment.');
  const steps = [
    ['1', 'Cart', 'Adjust quantities or remove items. Stock-safe database functions validate every change.'],
    ['2', 'Checkout', 'Confirm delivery address and review one order group for each seller.'],
    ['3', 'Payment', 'Choose Cash on Delivery, GCash, Maya, card, BPI, BDO, UnionBank, or QRPh.'],
    ['4', 'Confirmation', 'Pending online orders reserve stock until the verified Xendit result arrives.'],
  ];
  steps.forEach((s, i) => {
    const y = 1.92 + i * 1.2;
    slide.addShape(pptx.ShapeType.ellipse, { x: 0.88, y, w: 0.68, h: 0.68, fill: { color: i < 2 ? C.orange : C.teal }, line: { color: 'FFFFFF', transparency: 100 } });
    slide.addText(s[0], { x: 0.88, y: y + 0.16, w: 0.68, h: 0.25, fontSize: 16, bold: true, color: 'FFFFFF', align: 'center', margin: 0 });
    slide.addText(s[1], { x: 1.80, y: y + 0.02, w: 2.0, h: 0.28, fontSize: 20, bold: true, color: C.navy, margin: 0 });
    slide.addText(s[2], { x: 3.72, y: y - 0.02, w: 7.9, h: 0.62, fontSize: 15.5, color: C.navy, margin: 0, fit: 'shrink' });
    if (i < 3) slide.addShape(pptx.ShapeType.line, { x: 1.22, y: y + 0.72, w: 0, h: 0.44, line: { color: C.line, width: 2 } });
  });
  addCallout(slide, 'Online-payment safety', 'The Flutter client never stores the Xendit secret. Supabase Edge Functions create and cancel payment requests, while a verified webhook updates payment status.', 2.0, 6.32, 9.4, C.teal);
  addNotes(slide, ['lib/screens/buyer/cart_screen.dart', 'checkout_screen.dart', 'payment_method_screen.dart', 'supabase/functions/create-xendit-payment/index.ts']);
}

screenshotSlide({
  title: 'Buyer orders and aftercare', section: 'Buyer experience',
  subtitle: 'Order tabs separate payment, fulfillment, receipt, review, cancellation, and return stages.',
  image: '06_buyer_orders.png',
  bullets: [
    'Filters group orders into All, To pay, To ship, To receive, To review, Completed, Cancelled, and Returns.',
    'Order details show seller, items, payment status, delivery address, and next actions.',
    'Eligible completed purchases can open the review composer with a star rating, comment, and photos.',
    'Return requests follow the configured return window and preserve their review history.',
  ],
  callout: { title: 'Current captured state', text: 'The signed-in seller account had no buyer-side orders, so the slide shows the implemented empty state and filter structure.', color: C.orange },
  note: 'lib/screens/buyer/orders_screen.dart; order_details_screen.dart; review_composer_screen.dart',
});

pairSlide({
  title: 'Profile, favorites, messages, and account tools', section: 'Buyer experience',
  subtitle: 'The profile area acts as the account hub for saved products, conversations, security, support, and personal details.',
  images: [
    { file: '18_profile_actions.png', label: 'Profile tools' },
    { file: '21_favorites.png', label: 'Saved fish' },
  ],
  bullets: [
    'My Orders, Messages, and My Favorites provide quick access to frequent activities.',
    'Account security reports email and phone verification state.',
    'Edit Profile updates identity, contact, delivery information, and the profile image.',
    'Chat supports buyer and seller conversations linked to a product or order context.',
  ],
  note: 'lib/screens/buyer/profile_screen.dart; favorites_screen.dart; chat_inbox_screen.dart; chat_screen.dart; edit_profile_screen.dart',
});

screenshotSlide({
  title: 'Profile identity and verification status', section: 'Buyer experience',
  subtitle: 'The account profile displays the user identity and verified seller eligibility.',
  image: '17_profile.png',
  bullets: [
    'The profile header displays the avatar, full name, and username.',
    'Account details include email, mobile verification status, and delivery address.',
    'Phone verification controls whether the Sell area is available.',
    'Contact details shown here belong to a local demonstration account.',
  ],
  callout: { title: 'Privacy note', text: 'Mask or replace contact details before distributing this deck outside the project team.', color: C.orange },
  note: 'lib/screens/buyer/profile_screen.dart',
});

pairSlide({
  title: 'Help center and ticket submission', section: 'Support',
  subtitle: 'Users can create categorized support cases for marketplace issues, account help, or appeals.',
  images: [
    { file: '19_help_support.png', label: 'Ticket list' },
    { file: '20_create_ticket.png', label: 'New ticket' },
  ],
  bullets: [
    'The support center lists existing tickets and their current status.',
    'A new ticket records category, subject, and a detailed message.',
    'Restricted users can open an appeal with the category and subject preselected.',
    'Administrators can assign, prioritize, reply to, and close support cases.',
  ],
  note: 'lib/screens/buyer/help_support_screen.dart; support_ticket_screen.dart; lib/screens/admin/admin_tickets_screen.dart',
});

screenshotSlide({
  title: 'Seller dashboard and shop performance', section: 'Seller workspace',
  subtitle: 'Verified sellers manage their shop, financial summary, product performance, and daily actions from one workspace.',
  image: '07_seller_dashboard.png',
  bullets: [
    'Shop controls open the public shop or edit seller information.',
    'Earnings summarize available, pending, earned, and withdrawn amounts.',
    'Performance metrics count products, stock, sales, ratings, views, and favorites.',
    'Quick actions connect the dashboard to new listings and seller order management.',
  ],
  callout: { title: 'Shop requirement', text: 'A verified account can create one shop. Existing shop owners enter this dashboard directly.', color: C.teal },
  note: 'lib/screens/seller/seller_dashboard_screen.dart; shop_form_screen.dart',
});

screenshotSlide({
  title: 'Seller inventory', section: 'Seller workspace',
  subtitle: 'Each listing remains editable and exposes its operational status directly in the product list.',
  image: '08_seller_inventory.png',
  bullets: [
    'Inventory rows show the product photo, price, stock, sales, favorites, rating, and status.',
    'The status control switches a listing among Available, Sold out, and Hidden.',
    'The overflow menu opens listing edit and management actions.',
    'Add fish starts a validated listing form with image requirements.',
  ],
  callout: { title: 'Stock visibility', text: 'Sold-out products remain visible to the seller while buyer availability follows the listing status and quantity.', color: C.orange },
  note: 'lib/screens/seller/seller_dashboard_screen.dart; product_form_screen.dart',
});

pairSlide({
  title: 'Fish listing creation', section: 'Seller workspace',
  subtitle: 'The listing form captures product identity, condition, inventory, location, availability, and visual evidence.',
  images: [
    { file: '09_add_listing.png', label: 'Listing identity' },
    { file: '10_listing_fields.png', label: 'Inventory and images' },
  ],
  bullets: [
    'Required details include fish name, species, category, description, price, and quantity.',
    'Optional attributes record size, age, and sex.',
    'Health condition and seller location help buyers evaluate suitability and delivery distance.',
    'At least one fish image is required before the listing can be saved.',
  ],
  note: 'lib/screens/seller/product_form_screen.dart; lib/utils/validators.dart; lib/utils/fish_categories.dart',
});

pairSlide({
  title: 'Seller order queue and order evidence', section: 'Seller workspace',
  subtitle: 'Sellers can filter orders, inspect buyer and item details, and manage fulfillment from a single queue.',
  images: [
    { file: '11_seller_orders.png', label: 'Seller order queue' },
    { file: '12_seller_order_details.png', label: 'Order details' },
  ],
  bullets: [
    'Tabs filter orders by pending, to ship, shipping, completed, cancelled, and return status.',
    'Each order card shows buyer, date, items, payment method, total, and current status.',
    'The detail screen displays item quantities, order total, payment, and delivery information.',
    'Paid Xendit orders follow stricter cancellation rules because automated refunds are not included.',
  ],
  note: 'lib/screens/seller/seller_orders_screen.dart; seller_order_details_screen.dart; README.md',
});

screenshotSlide({
  title: 'Order fulfillment controls', section: 'Seller workspace',
  subtitle: 'The next-action section advances the order while preserving a separate cancellation path.',
  image: '13_order_fulfillment.png',
  bullets: [
    'Pending Cash on Delivery orders can move to Confirmed or be cancelled.',
    'Later stages support shipping updates, delivery confirmation, and completion.',
    'Return requests appear inside the seller order workflow with their reason and status.',
    'Status changes are backed by database rules that protect inventory and payment state.',
  ],
  callout: { title: 'Documentation capture', text: 'No order status was changed while collecting screenshots.', color: C.teal },
  note: 'lib/screens/seller/seller_order_details_screen.dart; seller_orders_screen.dart; lib/services/order_service.dart',
});

screenshotSlide({
  title: 'Seller earnings wallet', section: 'Finance',
  subtitle: 'The wallet separates money that can be withdrawn from pending escrow, lifetime earnings, and completed withdrawals.',
  image: '14_earnings_wallet.png',
  bullets: [
    'Available balance includes released earnings from eligible online payments.',
    'Pending escrow tracks money awaiting release.',
    'The transaction ledger filters earnings, platform fees, and withdrawals.',
    'Cash on Delivery revenue appears in sales analytics because payment goes directly to the seller.',
  ],
  callout: { title: 'Wallet boundary', text: 'Only Xendit-paid orders enter the in-app seller wallet.', color: C.orange },
  note: 'lib/screens/seller/earnings_screen.dart; lib/services/seller_wallet_service.dart',
});

pairSlide({
  title: 'Payout accounts and withdrawals', section: 'Finance',
  subtitle: 'Sellers choose a saved payout destination and submit an amount against their available balance.',
  images: [
    { file: '15_payout_accounts.png', label: 'Payout destinations' },
    { file: '16_withdrawal.png', label: 'Withdrawal request' },
  ],
  bullets: [
    'Payout accounts show the provider, account holder, and masked destination number.',
    'The withdrawal form validates the minimum amount and available balance.',
    'Withdrawal history records status and allows eligible pending requests to be cancelled.',
    'The captured environment uses demo withdrawals and does not transmit real funds.',
  ],
  note: 'lib/screens/seller/payout_accounts_screen.dart; withdrawal_screen.dart; lib/services/seller_payout_service.dart',
});

// Admin modules overview
{
  const slide = pptx.addSlide();
  addHeader(slide, 'Permission-gated admin console', 'Administration', 'The admin shell reveals only the sections allowed by the signed-in role.');
  const modules = [
    ['Dashboard', 'Marketplace metrics, operational queues, and sales trend'],
    ['Users', 'Search accounts, inspect history, suspend, ban, or reactivate'],
    ['Support', 'Assign, prioritize, reply to, and close tickets'],
    ['Reports', 'Review user reports and record resolutions'],
    ['Content', 'Moderate products, shops, reviews, and profile content'],
    ['Orders', 'Search orders and inspect protected delivery details'],
    ['Finance', 'Withdrawals, returns, wallets, fees, and settings'],
    ['Audit', 'Search administrative actions and actor history'],
    ['Team', 'Review role membership and permission coverage'],
  ];
  modules.forEach((m, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.82 + col * 4.15;
    const y = 1.90 + row * 1.55;
    slide.addShape(pptx.ShapeType.roundRect, { x, y, w: 3.68, h: 1.12, rectRadius: 0.06, fill: { color: 'FFFFFF' }, line: { color: i < 3 ? C.orange : C.teal, transparency: 58, width: 1 } });
    slide.addText(m[0], { x: x + 0.18, y: y + 0.14, w: 1.35, h: 0.26, fontSize: 17, bold: true, color: i < 3 ? C.orange : C.teal, margin: 0 });
    slide.addText(m[1], { x: x + 0.18, y: y + 0.47, w: 3.25, h: 0.42, fontSize: 12.4, color: C.navy, margin: 0, fit: 'shrink' });
  });
  addNotes(slide, ['lib/screens/admin/admin_shell.dart', 'lib/models/admin_access.dart']);
}

{
  const slide = pptx.addSlide();
  addHeader(slide, 'Account and content moderation', 'Administration', 'Administrative actions require explicit permissions and produce an auditable history.');
  const left = [
    'Search and filter active, suspended, or banned accounts.',
    'Inspect masked identity, order count, shop data, and moderation history.',
    'Reveal protected contact details through an audited action.',
    'Suspend for a period, ban indefinitely, or reactivate an account.',
  ];
  const right = [
    'Review reported products, shops, reviews, and profile content.',
    'Record a moderation reason and resolution.',
    'Hide or restore content according to the moderator permission set.',
    'Protect privileged admin accounts from unsafe account actions.',
  ];
  slide.addText('USER ACCOUNTS', { x: 0.84, y: 1.82, w: 4.8, h: 0.28, fontSize: 13, bold: true, color: C.orange, charSpacing: 1.2, margin: 0 });
  addBullets(slide, left, 0.84, 2.18, 5.55, 3.65, { fontSize: 17.5 });
  slide.addShape(pptx.ShapeType.line, { x: 6.55, y: 1.95, w: 0, h: 4.55, line: { color: C.line, width: 1.5 } });
  slide.addText('CONTENT AND REPORTS', { x: 6.95, y: 1.82, w: 4.8, h: 0.28, fontSize: 13, bold: true, color: C.teal, charSpacing: 1.2, margin: 0 });
  addBullets(slide, right, 6.95, 2.18, 5.45, 3.65, { fontSize: 17.5 });
  addCallout(slide, 'Public reasons', 'User-facing restriction text stays separate from internal administrative notes.', 2.08, 6.20, 9.25, C.teal);
  addNotes(slide, ['lib/screens/admin/admin_users_screen.dart', 'admin_user_detail_screen.dart', 'admin_reports_screen.dart', 'admin_content_screen.dart']);
}

{
  const slide = pptx.addSlide();
  addHeader(slide, 'Support, finance, audit, and team operations', 'Administration', 'Operational modules connect customer cases with financial controls and role accountability.');
  const rows = [
    ['Support', 'Status, priority, assignment, internal notes, customer replies, and case-linked conversations'],
    ['Finance', 'Withdrawal queue, return decisions, seller wallets, ledger inspection, platform fee, and return-window settings'],
    ['Orders', 'Marketplace-wide order search, detail inspection, and audited address reveal'],
    ['Audit', 'Searchable record of privileged actions, actors, targets, reasons, and timestamps'],
    ['Team', 'Admin role membership and effective permission review'],
  ];
  rows.forEach((r, i) => {
    const y = 1.82 + i * 0.98;
    slide.addText(r[0], { x: 0.88, y: y + 0.10, w: 1.55, h: 0.28, fontSize: 18, bold: true, color: i % 2 ? C.orange : C.teal, margin: 0 });
    slide.addText(r[1], { x: 2.55, y, w: 9.55, h: 0.55, fontSize: 15.5, color: C.navy, margin: 0.02, fit: 'shrink' });
    slide.addShape(pptx.ShapeType.line, { x: 0.88, y: y + 0.72, w: 11.15, h: 0, line: { color: C.line, width: 1 } });
  });
  addCallout(slide, 'Role model', 'The super admin has full access. Other administrative roles receive only the permissions required for their responsibilities.', 1.84, 6.45, 9.65, C.orange);
  addNotes(slide, ['lib/screens/admin/admin_tickets_screen.dart', 'admin_finance_screen.dart', 'admin_orders_screen.dart', 'admin_audit_screen.dart', 'admin_team_screen.dart']);
}

// Architecture
{
  const slide = pptx.addSlide();
  addHeader(slide, 'Application architecture and integrations', 'Technical design', 'Flutter provides the user interface while Supabase and Xendit handle identity, data, storage, and online payments.');
  const boxes = [
    { x: 0.78, y: 2.45, w: 2.45, t: 'Flutter app', d: 'Buyer, seller, admin, authentication, validation, and navigation', c: C.orange },
    { x: 3.75, y: 1.75, w: 2.45, t: 'Supabase Auth', d: 'Email sessions, verification, password recovery, and phone verification', c: C.teal },
    { x: 3.75, y: 3.20, w: 2.45, t: 'Postgres + RLS', d: 'Profiles, shops, products, carts, orders, reviews, chat, wallets, and admin data', c: C.teal },
    { x: 3.75, y: 4.65, w: 2.45, t: 'Storage', d: 'Profile photos, shop logos, product images, and review media', c: C.teal },
    { x: 6.75, y: 2.45, w: 2.45, t: 'Edge Functions', d: 'Create, cancel, simulate, and reconcile Xendit payment requests', c: C.navy },
    { x: 9.75, y: 2.45, w: 2.45, t: 'Xendit', d: 'Hosted test checkout, payment channels, simulation API, and verified webhooks', c: C.orange },
  ];
  boxes.forEach((b) => {
    slide.addShape(pptx.ShapeType.roundRect, { x: b.x, y: b.y, w: b.w, h: 1.03, rectRadius: 0.06, fill: { color: 'FFFFFF' }, line: { color: b.c, transparency: 35, width: 1.4 } });
    slide.addText(b.t, { x: b.x + 0.14, y: b.y + 0.12, w: b.w - 0.28, h: 0.25, fontSize: 17, bold: true, color: b.c, align: 'center', margin: 0 });
    slide.addText(b.d, { x: b.x + 0.13, y: b.y + 0.42, w: b.w - 0.26, h: 0.44, fontSize: 11.5, color: C.navy, align: 'center', margin: 0, fit: 'shrink' });
  });
  [[3.23,2.95,0.46,0],[6.2,2.95,0.48,0],[9.2,2.95,0.48,0]].forEach(a => slide.addShape(pptx.ShapeType.chevron,{x:a[0],y:a[1],w:a[2],h:0.28,fill:{color:C.line},line:{color:C.line,transparency:100}}));
  addCallout(slide, 'Server-side secrets', 'Xendit secret keys and webhook tokens stay in Supabase Edge Function secrets. The Flutter client uses only public Supabase configuration.', 2.0, 6.25, 9.35, C.teal);
  addNotes(slide, ['lib/main.dart', 'lib/services', 'supabase/schema.sql', 'supabase/functions', 'README.md']);
}

{
  const slide = pptx.addSlide();
  addHeader(slide, 'Business rules and safeguards', 'Technical design', 'Database constraints and role checks support safe marketplace behavior.');
  const rules = [
    ['Ordering', 'Cart checkout splits mixed-shop items into one order per seller. Stock is locked, rechecked, and reduced atomically.'],
    ['Seller policy', 'Users cannot buy their own listings. Selling requires a verified phone and one shop per account.'],
    ['Payments', 'Pending online orders reserve stock. Failure, cancellation, or expiry restores that stock.'],
    ['Access control', 'Row Level Security limits records by ownership, participant, and administrative permission.'],
    ['Moderation', 'Account restrictions preserve eligible order and support access while blocking normal marketplace activity.'],
    ['Auditability', 'Protected contact and address reveals are explicit administrative actions recorded in the audit trail.'],
  ];
  rules.forEach((r, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const x = 0.85 + col * 6.18;
    const y = 1.90 + row * 1.47;
    slide.addText(r[0], { x, y, w: 1.65, h: 0.30, fontSize: 18, bold: true, color: col ? C.teal : C.orange, margin: 0 });
    slide.addText(r[1], { x: x + 1.72, y: y - 0.02, w: 4.1, h: 0.78, fontSize: 14.2, color: C.navy, margin: 0, fit: 'shrink' });
    slide.addShape(pptx.ShapeType.line, { x, y: y + 0.94, w: 5.78, h: 0, line: { color: C.line, width: 1 } });
  });
  addCallout(slide, 'Testing and demo modes', 'The repository includes widget tests, SQL integration tests, seeded seller data, a demo admin, and a payment simulator that rejects live Xendit keys.', 2.0, 6.40, 9.35, C.orange);
  addNotes(slide, ['supabase/schema.sql', 'supabase/security_hardening.sql', 'supabase/online_payments.sql', 'test', 'supabase/tests']);
}

// Coverage index
{
  const slide = pptx.addSlide();
  addHeader(slide, 'Functional coverage index', 'Reference', 'Implemented screens and major capabilities covered by this walkthrough.');
  const data = [
    ['Area', 'Screens and functions'],
    ['Authentication', 'Splash, sign in, register, email verification, forgot/reset password, phone verification, restricted account'],
    ['Buyer', 'Home, search, product details, shop details, favorites, cart, checkout, payment method, orders, returns, reviews'],
    ['Communication', 'Chat inbox, conversation, product/order context, support ticket list, ticket detail, ticket creation'],
    ['Seller', 'Shop setup/edit, dashboard, listings, product form, orders, order details, earnings, payout accounts, withdrawals'],
    ['Administration', 'Dashboard, users, account details, tickets, reports, content, orders, finance, audit, team'],
    ['Integrations', 'Supabase Auth, Postgres/RLS, Storage, Edge Functions, Xendit hosted payment and webhook handling'],
  ];
  slide.addTable(data, {
    x: 0.82, y: 1.78, w: 11.65, h: 4.95,
    colW: [2.15, 9.5],
    rowH: 0.68,
    border: { type: 'solid', color: C.line, pt: 1 },
    fill: C.paper, color: C.navy, fontFace: 'Aptos', fontSize: 13.4,
    margin: 0.10, valign: 'mid',
    bold: false,
    autoFit: false,
  });
  addNotes(slide, ['lib/screens', 'lib/services', 'supabase/functions', 'supabase SQL migrations']);
}

{
  const slide = pptx.addSlide();
  addHeader(slide, 'Capture scope and presentation notes', 'Reference', 'The deck combines verified live screens with code-based documentation for protected or state-dependent flows.');
  addBullets(slide, [
    'Live screenshots came from the running Android build using the signed-in Fisherman demonstration account.',
    'The deck did not submit a purchase, change an order status, withdraw money, create a support ticket, or modify marketplace data.',
    'Admin screens are documented from their implemented widgets, services, permission checks, and database migrations because the emulator keyboard blocked a clean account switch during capture.',
    'Some screens require specific data states, such as another seller’s product, a completed order, an open return, or a pending moderation case.',
    'Replace or mask demonstration contact details before sharing the deck outside the project team.',
  ], 1.05, 1.72, 11.15, 4.65, { fontSize: 18, spaceAfter: 13 });
  addCallout(slide, 'Recommended next capture', 'Open the demo admin account and a non-seller buyer account, then append screenshots for admin queues, cart, checkout, payment selection, chat, reviews, and returns.', 1.7, 6.20, 10.0, C.teal);
  addNotes(slide, ['Live capture log', 'Current repository source tree']);
}

// Closing slide
{
  const slide = pptx.addSlide();
  slide.background = { color: C.navy };
  slide.addShape(pptx.ShapeType.ellipse, { x: 8.75, y: -0.8, w: 5.6, h: 4.1, rotate: 18, fill: { color: C.orange, transparency: 8 }, line: { color: C.orange, transparency: 100 } });
  slide.addShape(pptx.ShapeType.ellipse, { x: -1.2, y: 4.6, w: 5.4, h: 4.0, rotate: 205, fill: { color: C.aqua, transparency: 30 }, line: { color: C.aqua, transparency: 100 } });
  if (fs.existsSync(logo)) slide.addImage({ path: logo, x: 0.95, y: 0.78, w: 1.75, h: 1.10 });
  slide.addText('Tkoi connects fish buyers, sellers, and marketplace operations in one role-aware system', {
    x: 1.0, y: 2.25, w: 10.6, h: 1.85,
    fontFace: 'Aptos Display', fontSize: 34, bold: true,
    color: 'FFFFFF', align: 'center', valign: 'mid', margin: 0, fit: 'shrink',
  });
  slide.addText('End of system walkthrough', { x: 4.55, y: 5.08, w: 4.2, h: 0.35, fontSize: 16, color: 'CFEFEB', align: 'center', margin: 0 });
  addNotes(slide, ['Tkoi project']);
}

pptx.writeFile({ fileName: out, compression: false })
  .then(() => console.log(out))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

