---
trigger: always_on
---

-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  name text NOT NULL,
  phone text,
  address text,
  customer_level text NOT NULL DEFAULT 'ecer'::text CHECK (customer_level = ANY (ARRAY['ecer'::text, 'grosir'::text, 'agen'::text, 'vip'::text])),
  total_belanja numeric NOT NULL DEFAULT 0,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (id),
  CONSTRAINT customers_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.product_prices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  price_type text NOT NULL CHECK (price_type = ANY (ARRAY['qty_based'::text, 'customer_level'::text])),
  min_qty integer NOT NULL DEFAULT 1 CHECK (min_qty >= 1),
  customer_level text CHECK ((customer_level = ANY (ARRAY['ecer'::text, 'grosir'::text, 'agen'::text, 'vip'::text])) OR customer_level IS NULL),
  harga_jual numeric NOT NULL CHECK (harga_jual >= 0::numeric),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT product_prices_pkey PRIMARY KEY (id),
  CONSTRAINT product_prices_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT product_prices_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id)
);
CREATE TABLE public.product_units (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  unit_name text NOT NULL,
  conversion_to_base numeric NOT NULL DEFAULT 1 CHECK (conversion_to_base > 0::numeric),
  is_base_unit boolean NOT NULL DEFAULT false,
  is_purchasable boolean NOT NULL DEFAULT true,
  is_sellable boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT product_units_pkey PRIMARY KEY (id),
  CONSTRAINT product_units_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  name text NOT NULL,
  sku text,
  barcode text,
  base_unit text NOT NULL,
  current_stock numeric NOT NULL DEFAULT 0,
  stock_alert_qty numeric DEFAULT 0,
  harga_modal_terakhir numeric NOT NULL DEFAULT 0,
  harga_jual_min numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  image_url text,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  store_name text NOT NULL,
  phone text,
  subscription_plan text NOT NULL DEFAULT 'free'::text CHECK (subscription_plan = ANY (ARRAY['free'::text, 'basic'::text, 'pro'::text])),
  trial_ends_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.stock_mutations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL,
  unit_id uuid,
  mutation_type text NOT NULL CHECK (mutation_type = ANY (ARRAY['purchase'::text, 'sale'::text, 'return_in'::text, 'return_out'::text, 'adjustment'::text, 'opening'::text])),
  qty_in_base numeric NOT NULL,
  unit_name_snapshot text NOT NULL,
  qty_original numeric NOT NULL,
  harga_modal_lama numeric,
  harga_modal_baru numeric NOT NULL,
  supplier_name text,
  invoice_ref text,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT stock_mutations_pkey PRIMARY KEY (id),
  CONSTRAINT stock_mutations_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id),
  CONSTRAINT stock_mutations_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT stock_mutations_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id)
);
CREATE TABLE public.transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  product_id uuid NOT NULL,
  unit_id uuid,
  product_name_snapshot text NOT NULL,
  unit_name_snapshot text NOT NULL,
  qty numeric NOT NULL CHECK (qty > 0::numeric),
  qty_in_base numeric NOT NULL,
  harga_modal_aktual numeric NOT NULL,
  harga_jual_aktual numeric NOT NULL,
  harga_acuan_sistem numeric NOT NULL,
  is_price_overridden boolean NOT NULL DEFAULT false,
  price_override_reason text,
  subtotal numeric DEFAULT (qty * harga_jual_aktual),
  profit_subtotal numeric DEFAULT (qty_in_base * (harga_jual_aktual - harga_modal_aktual)),
  CONSTRAINT transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id),
  CONSTRAINT transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT transaction_items_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  customer_id uuid,
  invoice_no text NOT NULL,
  total_amount numeric NOT NULL DEFAULT 0,
  discount_amount numeric NOT NULL DEFAULT 0,
  amount_paid numeric NOT NULL DEFAULT 0,
  change_amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash'::text CHECK (payment_method = ANY (ARRAY['cash'::text, 'transfer'::text, 'qris'::text, 'credit'::text])),
  status text NOT NULL DEFAULT 'completed'::text CHECK (status = ANY (ARRAY['completed'::text, 'voided'::text, 'pending'::text])),
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id),
  CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id)
);
