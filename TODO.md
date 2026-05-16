Done in code
- Created seller storefront page at /seller/<store_id>.
- Added My Orders page at /my-orders with delivered-order review actions.
- Redesigned search page with compact filters and seller links.
- Replaced rider dashboard product view with delivery queue, pickup, and delivered/proof flow.
- Hardened logout by clearing local session first and using local Supabase sign-out.
- Registration phone fields now show +63 prefix and accept hand-entered 9xxxxxxxxx numbers.
- Signup now persists zip code from the location API instead of the old city map.
- Login no longer defaults unknown account rows into buyer route, avoiding the unauthorized buyer warning.
- Checkout now shows fee/discount breakdown and coupon apply.
- Admin dashboard has a Coupons tab.

Database done
- supabase_app_updates.sql was applied to project zsctswdvoknmdsimqrvr.
- Verified old order_items_order_id_product_id_key is gone.
- Verified order_items_order_product_variant_unique exists.
- Verified product_review and discount_coupon tables exist.
- Verified orders.discount_code and orders.discount_amount exist.

Latest done
- Seller registration now requires/upload business permit documents.
- Rider registration now uploads license/vehicle documents instead of text notes.
- Uploaded application document filenames now include seller/rider, document type, account id, and timestamp.
- Application documents accept PDF, PNG, JPG/JPEG, WEBP; image picker uses reduced quality/size.
- Admin application detail dialogs are wider and can show uploaded image documents or signed PDF links.
- Seller orders can only move Processing, Ready for Pickup, or Cancelled.
- Ready-for-pickup orders show a pickup code for rider scan/entry.
- Rider pickup requires the pickup code and moves the order to In Transit.
- Rider delivery requires an uploaded proof photo plus optional note/call note.
- Seller can open delivery proof images from orders.
- Address add/edit/signup/login paths now geocode through the location API and save coordinates.
- ZIP/postal code is now read from the geocoding API when available.
- Checkout calculates delivery distance with geocoding/OSRM and charges max(10 PHP, 10 PHP per km).
- Applied supabase_documents_delivery_updates.sql and verified columns/buckets/policies.
