-- chequeo de tablas extistentes ---

--identificar clientes únicos y su ubicación.
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'customers';

-- representa la orden principal del ecommerce.
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'orders';

-- una orden puede tener múltiples productos
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'order_items';

--cómo se pagó cada orden
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'order_payments';

-- atributos de cada producto
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'products';

-- identificar vendedores del marketplace
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'sellers';

-- opiniones de clientes
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'reviews';

-- mapear ubicación geográfica
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'geolocation';

-- traducir categorías de portugués a inglés
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
and table_name = 'product_category_translation';

--visualizar todas las tablas
select table_name
from information_schema.tables
where table_schema = 'raw';

--revisión de número de filas de cada tabla
select count(*) from raw.orders;
select count(*) from raw.order_items;
select count(*) from raw.order_payments;
select count(*) from raw.reviews;






X