-- v2.2.43: Online product sync → UPSERT per produk.
-- sync_products edge fn sekarang upsert key (store_id, product_id) —
-- butuh unique constraint + kolom updated_at. Produk non-online TIDAK
-- dihapus lagi (sebelumnya delete-all + insert).

ALTER TABLE online_products
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Unique constraint untuk onConflict("store_id,product_id").
-- Sebelumnya tidak ada → duplicate rows bisa ada; dedupe dulu sebelum
-- menambah constraint.
DELETE FROM online_products a
  USING online_products b
  WHERE a.id > b.id
    AND a.store_id = b.store_id
    AND a.product_id = b.product_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'online_products_store_product_key'
  ) THEN
    ALTER TABLE online_products
      ADD CONSTRAINT online_products_store_product_key
      UNIQUE (store_id, product_id);
  END IF;
END $$;

-- Index pendukung lookup web by store+product (replaces old non-unique idx).
CREATE INDEX IF NOT EXISTS idx_online_products_store_product
  ON online_products(store_id, product_id);
