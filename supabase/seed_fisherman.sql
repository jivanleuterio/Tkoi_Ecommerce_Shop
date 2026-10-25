-- Tkoi sample seller and catalog
-- First create and auto-confirm this user in Authentication > Users:
-- Email: fisherman.tkoi.demo@gmail.com
-- Password: Fisherman123!

do $$
declare
  fisherman_id uuid;
  fisherman_shop_id uuid;
begin
  select id into fisherman_id
  from auth.users
  where lower(email) = 'fisherman.tkoi.demo@gmail.com'
  limit 1;

  if fisherman_id is null then
    raise exception 'Create fisherman.tkoi.demo@gmail.com in Authentication > Users first.';
  end if;

  -- This is a classroom demo account, so the seed marks its sample number as
  -- verified. Real users must complete the SMS code inside the Tkoi app.
  update auth.users
  set phone = '+639123456789',
      phone_confirmed_at = coalesce(phone_confirmed_at, now()),
      updated_at = now()
  where id = fisherman_id;

  insert into public.profiles (
    id, full_name, username, email, mobile_number, address
  ) values (
    fisherman_id,
    'Fisherman',
    'fisherman',
    'fisherman.tkoi.demo@gmail.com',
    '+639123456789',
    'General Santos City, Philippines'
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    username = excluded.username,
    email = excluded.email,
    mobile_number = excluded.mobile_number,
    address = excluded.address;

  insert into public.shops (
    owner_id, name, owner_name, description,
    contact_number, email, location
  ) values (
    fisherman_id,
    'Fisherman',
    'Fisherman',
    'A sample Tkoi shop offering healthy freshwater and marine fish.',
    '+639123456789',
    'fisherman.tkoi.demo@gmail.com',
    'General Santos City, Philippines'
  )
  on conflict (owner_id) do update set
    name = excluded.name,
    owner_name = excluded.owner_name,
    description = excluded.description,
    contact_number = excluded.contact_number,
    email = excluded.email,
    location = excluded.location
  returning id into fisherman_shop_id;

  -- Makes this script safe to rerun without duplicating the sample listings.
  delete from public.products where seller_id = fisherman_id;

  insert into public.products (
    shop_id, seller_id, name, species, category, description,
    price, quantity, size, age_months, sex, health_condition,
    seller_location, status
  ) values
    (fisherman_shop_id, fisherman_id, 'Kohaku Koi', 'Cyprinus rubrofuscus', 'Koi',
     'Healthy red and white Kohaku koi, suitable for outdoor ponds.',
     1500.00, 5, '20 cm', 10, 'Unknown', 'Healthy and active',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Ranchu Goldfish', 'Carassius auratus', 'Goldfish',
     'Round-bodied Ranchu goldfish raised in clean, filtered water.',
     650.00, 8, '10 cm', 7, 'Unknown', 'Healthy and feeding well',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Halfmoon Betta', 'Betta splendens', 'Betta',
     'Colorful Halfmoon betta with a wide tail and calm temperament.',
     350.00, 10, '6 cm', 5, 'Male', 'Healthy fins and bright color',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Blue Moscow Guppy', 'Poecilia reticulata', 'Guppy',
     'Metallic blue guppy ideal for planted community aquariums.',
     120.00, 20, '4 cm', 4, 'Male', 'Healthy and active',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Dalmatian Molly', 'Poecilia sphenops', 'Molly',
     'Black and white spotted molly that is beginner friendly.',
     150.00, 15, '6 cm', 5, 'Female', 'Healthy and feeding well',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Electric Blue Acara', 'Andinoacara pulcher', 'Cichlid',
     'Bright blue peaceful cichlid for a medium or large aquarium.',
     700.00, 6, '12 cm', 8, 'Unknown', 'Healthy and quarantined',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Silver Arowana', 'Osteoglossum bicirrhosum', 'Arowana',
     'Juvenile silver arowana for experienced keepers with a large tank.',
     2800.00, 3, '25 cm', 9, 'Unknown', 'Healthy with complete scales',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Corydoras Catfish', 'Corydoras aeneus', 'Catfish',
     'Peaceful bottom-dwelling catfish best kept in a small group.',
     180.00, 18, '5 cm', 5, 'Unknown', 'Healthy barbels and active',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Ocellaris Clownfish', 'Amphiprion ocellaris', 'Marine Fish',
     'Tank-bred clownfish suitable for established saltwater aquariums.',
     1200.00, 4, '7 cm', 8, 'Unknown', 'Healthy and eating pellets',
     'General Santos City', 'available'),
    (fisherman_shop_id, fisherman_id, 'Bala Shark', 'Balantiocheilos melanopterus', 'Other',
     'Active schooling fish that requires a spacious freshwater aquarium.',
     450.00, 7, '10 cm', 6, 'Unknown', 'Healthy and active',
     'General Santos City', 'available');
end $$;
