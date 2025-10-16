CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity INT NOT NULL CHECK (quantity > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Денормализованный агрегат
CREATE TABLE IF NOT EXISTS sales_report (
  product_id INT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  total_quantity BIGINT NOT NULL DEFAULT 0,
  total_revenue NUMERIC(20,2) NOT NULL DEFAULT 0
);

-- Инициализация отчёта на основе текущих данных
CREATE OR REPLACE FUNCTION init_sales_report()
RETURNS void AS $$
BEGIN
  INSERT INTO sales_report (product_id, product_name, total_quantity, total_revenue)
  SELECT p.id, p.name, COALESCE(SUM(o.quantity),0) AS total_quantity,
         COALESCE(SUM(o.quantity * p.price),0)::NUMERIC(20,2) AS total_revenue
  FROM products p
  LEFT JOIN orders o ON o.product_id = p.id
  GROUP BY p.id, p.name
  ON CONFLICT (product_id) DO UPDATE
  SET product_name = EXCLUDED.product_name,
      total_quantity = EXCLUDED.total_quantity,
      total_revenue = EXCLUDED.total_revenue;
END;
$$ LANGUAGE plpgsql;

-- Триггерная функция поддержки отчёта
CREATE OR REPLACE FUNCTION sales_report_apply()
RETURNS TRIGGER AS $$
DECLARE
  v_product_id INT;
  v_old_qty INT;
  v_new_qty INT;
  v_price NUMERIC(12,2);
BEGIN
  IF TG_TABLE_NAME = 'orders' THEN
    IF TG_OP = 'INSERT' THEN
      v_product_id := NEW.product_id;
      v_new_qty := NEW.quantity;
      SELECT price INTO v_price FROM products WHERE id = v_product_id;
      INSERT INTO sales_report (product_id, product_name, total_quantity, total_revenue)
      VALUES (v_product_id, (SELECT name FROM products WHERE id = v_product_id), v_new_qty, v_new_qty * v_price)
      ON CONFLICT (product_id) DO UPDATE
      SET total_quantity = sales_report.total_quantity + EXCLUDED.total_quantity,
          total_revenue = sales_report.total_revenue + EXCLUDED.total_revenue;
      RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
      v_product_id := NEW.product_id;
      v_old_qty := OLD.quantity;
      v_new_qty := NEW.quantity;
      SELECT price INTO v_price FROM products WHERE id = v_product_id;
      UPDATE sales_report
      SET total_quantity = total_quantity + (v_new_qty - v_old_qty),
          total_revenue = total_revenue + ((v_new_qty - v_old_qty) * v_price)
      WHERE product_id = v_product_id;
      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      v_product_id := OLD.product_id;
      v_old_qty := OLD.quantity;
      SELECT price INTO v_price FROM products WHERE id = v_product_id;
      UPDATE sales_report
      SET total_quantity = total_quantity - v_old_qty,
          total_revenue = total_revenue - (v_old_qty * v_price)
      WHERE product_id = v_product_id;
      RETURN OLD;
    END IF;
  ELSIF TG_TABLE_NAME = 'products' THEN
    IF TG_OP = 'INSERT' THEN
      -- Заводим пустую строку в отчёте
      INSERT INTO sales_report (product_id, product_name, total_quantity, total_revenue)
      VALUES (NEW.id, NEW.name, 0, 0)
      ON CONFLICT (product_id) DO UPDATE SET product_name = EXCLUDED.product_name;
      RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
      -- При смене цены пересчёт revenue делается инкрементально в DML orders; при смене имени правим product_name
      IF NEW.name IS DISTINCT FROM OLD.name THEN
        UPDATE sales_report SET product_name = NEW.name WHERE product_id = NEW.id;
      END IF;
      IF NEW.price IS DISTINCT FROM OLD.price THEN
        -- если поменялась цена, пересчитаем total_revenue на основании текущего количества
        UPDATE sales_report sr
        SET total_revenue = (SELECT COALESCE(SUM(o.quantity),0) * NEW.price FROM orders o WHERE o.product_id = NEW.id)
        WHERE sr.product_id = NEW.id;
      END IF;
      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      DELETE FROM sales_report WHERE product_id = OLD.id;
      RETURN OLD;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггеры на orders
DROP TRIGGER IF EXISTS trg_orders_ins ON orders;
DROP TRIGGER IF EXISTS trg_orders_upd ON orders;
DROP TRIGGER IF EXISTS trg_orders_del ON orders;
CREATE TRIGGER trg_orders_ins AFTER INSERT ON orders FOR EACH ROW EXECUTE FUNCTION sales_report_apply();
CREATE TRIGGER trg_orders_upd AFTER UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION sales_report_apply();
CREATE TRIGGER trg_orders_del AFTER DELETE ON orders FOR EACH ROW EXECUTE FUNCTION sales_report_apply();

-- Триггеры на products
DROP TRIGGER IF EXISTS trg_products_ins ON products;
DROP TRIGGER IF EXISTS trg_products_upd ON products;
DROP TRIGGER IF EXISTS trg_products_del ON products;
CREATE TRIGGER trg_products_ins AFTER INSERT ON products FOR EACH ROW EXECUTE FUNCTION sales_report_apply();
CREATE TRIGGER trg_products_upd AFTER UPDATE ON products FOR EACH ROW EXECUTE FUNCTION sales_report_apply();
CREATE TRIGGER trg_products_del AFTER DELETE ON products FOR EACH ROW EXECUTE FUNCTION sales_report_apply();

-- Первичная инициализация отчёта при пустой базе
SELECT init_sales_report();