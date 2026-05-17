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
- Rider registration now includes API-driven location selection.
- Uploaded application document filenames now include seller/rider, document type, account id, and timestamp.
- Application documents accept PDF, PNG, JPG/JPEG, WEBP; image picker uses reduced quality/size.
- Admin application detail dialogs are wider and can show uploaded image documents or signed PDF links.
- Seller orders can only move Processing, Ready for Pickup, or Cancelled.
- Ready-for-pickup orders show a pickup code for rider scan/entry.
- Rider pickup requires the pickup code and moves the order to In Transit.
- Rider delivery requires an uploaded proof photo plus optional note/call note.
- Seller can open delivery proof images from orders.
- Address add/edit/signup/login paths now geocode through the location API and save coordinates.
- Address manager now uses API-driven province/city/barangay dropdowns instead of manual location text entry.
- Seller/rider registration addresses are saved to the address table after submission/login sync and on approval if missing.
- Seller order status controls are buttons; seller changes lock after rider pickup/In Transit.
- Rider delivery queue can see unassigned Ready for Pickup orders, addresses, and order items through rider-specific RLS.
- Rider delivery cards now show actual order total separately from delivery/rider fee.
- My Orders now displays the linked delivery address and order creation verifies the selected address belongs to the buyer.
- Koishi/Koi-shy Business is set to Pila, Laguna; Rin Kaenbyou is set to Santa Cruz, Laguna.
- ZIP/postal code is now read from the geocoding API when available.
- Checkout calculates delivery distance with geocoding/OSRM and charges max(10 PHP, 10 PHP per km).
- Buyer dashboard product cards now use real product review averages/counts and default unrated products to 0 stars.
- Search results now use the image, product name, seller, price, stars, and review-count row layout.
- Admin dashboard money metrics now show commission from successful orders instead of gross order totals.
- Applied supabase_documents_delivery_updates.sql and verified columns/buckets/policies.

To do
- Build proper landing dashboards for seller (count of sales, orders) and rider (count of delivers).
-
- Add new formatting of math/deduction for shared countable product (eg. egg), there's the default that all products currently using (eg the sizes are separate in stock), mode 2 is where the stock is shared across sizes (eg. it counts by 10, 20, 50, 100, etc..) where the default is 10 and has stock of 100, ordering one 10 and ordering one 50 will deduct 60 in stock.
- Redesign Seller shopfront
- In seller dashboard > Orders, there should be a box below the nav where you toggle between states (eg Processing, Ready to pickup, in transit, delivered, cancelled)
- Buyer account, receipt system
- Seller account, add size to default (weird that it doesn't have it)
