# Snack Overflow — Cloudflare Pages static version

## 1. Supabase
Create a Supabase project. In SQL Editor run `sql/setup.sql` and then `sql/seed.sql` **once**. In Authentication > Users, create your admin user; copy their UUID. In SQL Editor run `insert into public.admins(user_id) values ('YOUR_ADMIN_USER_UUID');`. Disable public user signup. Configure auth rate limits/CAPTCHA before launch.

## 2. Cloudflare Pages
Push the CONTENTS of this folder to a private GitHub repository (package.json must be in the repository root). Cloudflare Dashboard > Workers & Pages > Create > Pages > Connect to Git. Choose **Next.js (Static HTML Export)**. Build command `npm run build`; output folder `out`. Add build environment variables `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` from Supabase Project Settings > API. Never use the secret/service_role key. Deploy and test the `*.pages.dev` address first.

## 3. GoDaddy domain
In Cloudflare Pages > Custom domains, add `snackoverflow.in` and follow the Cloudflare-specific instructions. For apex domains Cloudflare may require moving authoritative DNS/nameservers from GoDaddy to Cloudflare; copy existing DNS records first, especially MX/TXT email records. Do NOT change DNS before the preview is tested.

## Functionality
Public catalogue loads from Supabase with RLS; admin login uses Supabase Auth, with product CRUD and image upload restricted to user IDs in `public.admins`; order requests are created through a database RPC which recalculates prices server-side, then opens WhatsApp. Orders are **requests**, not confirmed purchases; delivery is quoted separately. Stock is not reserved/deducted automatically.

## Local test
Install Node.js 22+, copy `.env.example` to `.env.local`, enter public Supabase URL/key, run `npm install` and `npm run build`. A successful build creates `out/`. For development run `npm run dev`.

## Security and production notes
Public anonymous order submission may be abused; use Supabase API rate limits and CAPTCHA / abuse controls before public launch. Avoid collecting unnecessary personal data. Review privacy policy, terms, product descriptions, shipping and returns before taking orders. Existing seed SQL should only be run once. The included photos are actual uploaded product photos. Check stock, pricing and product labels before launch.
