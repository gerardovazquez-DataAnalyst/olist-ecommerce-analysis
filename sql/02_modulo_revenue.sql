-- Pregunta de negocio:"¿Cuántos pedidos hay por cada status y cuál es el predominante?"
select order_status, 
count(*) as total_orders
from raw.orders
group by order_status
order by total_orders desc;

--Pregunta de negocio: "¿Cuál es el revenue total de Olist considerando solo pedidos entregados?"

# se usa tabla de order_payments y la columna payment_value porque contiene pago total del cliente

select 
sum(op.payment_value) as total_revenue
from raw.orders as o 
left join raw.order_payments as op
on op.order_id=o.order_id
where o.order_status = 'delivered';

# la tabla order_items y la columna price solo considera el precio del articulo antes de impuestos o metodo de pagos

select 
sum(oi.price) as total_revenue_using_price
from raw.orders as o 
left join raw.order_items as oi
on oi.order_id=o.order_id
where o.order_status = 'delivered';



-- Verificación de calidad de datos Pregunta: ¿Cuántas órdenes delivered NO tienen registro en order_payments?

select
count(*) as missing_revenue
from raw.orders as o
left join raw.order_payments as op
on op.order_id=o.order_id
where o.order_status = 'delivered'
and op.payment_value is null;

-- Dato crudo: 1 registro NULL
      ↓
Métrica: 0.001% de órdenes sin pago
      ↓
Insight: Calidad de datos prácticamente perfecta
      ↓
Decisión: Podemos confiar en el revenue calculado
-- 

-- REVENUEW MENSUAL Pregunta de negocio: "¿Cómo creció el revenue mes a mes en Olist?"
select
date_trunc('month', o.order_purchase_timestamp::TIMESTAMP) as month,
round(sum(op.payment_value):: numeric, 2) as revenue_per_month
from raw.orders as o
left join raw.order_payments as op
on op.order_id=o.order_id
where o.order_status = 'delivered'
and op.payment_value is not null
group by month
order by revenue_per_month desc;

/* Dato: Pico de revenue en Noviembre 2017
      ↓
Investigación externa: Black Friday + Hot Sale en Brasil
      ↓
Insight: El comportamiento de compra de Olist sigue 
         patrones estacionales del retail brasileño
      ↓
Decisión accionable: Olist debería preparar inventario,
         logística y sellers con anticipación cada Noviembre
         
Conclusión: La caída de Jul-Ago 2018 no es real —
es un artefacto del corte del dataset. */

-- Pregunta de negocio: "¿Qué categorías de producto generan más revenue en Olist?"

select
pct.product_category_name_english as product_category,
round(sum(oi.price)::numeric, 2) as revenue_per_category
from raw.orders as o
left join raw.order_items as oi
on oi.order_id=o.order_id
left join raw.products as p
on p.product_id=oi.product_id
left join raw.product_category_translation as pct
on pct.product_category_name =p.product_category_name 
where o.order_status='delivered'
group by product_category
order by revenue_per_category  desc
limit 3;

-- Pregunta de negocio: "¿health_beauty genera más revenue porque sus productos son más caros o porque vende más unidades en Olist?"

select
pct.product_category_name_english as product_category,
count(*) as total_orders,
round(sum(oi.price)::numeric, 2) as revenue_per_category
from raw.orders as o
left join raw.order_items as oi
on oi.order_id=o.order_id
left join raw.products as p
on p.product_id=oi.product_id
left join raw.product_category_translation as pct
on pct.product_category_name =p.product_category_name 
where o.order_status='delivered'
group by product_category
order by revenue_per_category  desc
limit 3;

/* Verificación de calidad de datos, ¿qué procentaje de productos no tiene nombre en product_category_name
-- ¿En qué posición aparece NULL?
-- ¿Cuánto revenue representa?
-- ¿Cuántas órdenes tiene?*/

select 
count(*) as total_orders,
count(*) filter (where pct.product_category_name_english is null) as total_nulls,
round(count(*) filter (where pct.product_category_name_english is null)*100.0/
count(*), 2) as pct_nulls
from raw.orders as o
left join raw.order_items as oi
on oi.order_id=o.order_id
left join raw.products as p
on p.product_id=oi.product_id
left join raw.product_category_translation as pct
on pct.product_category_name=p.product_category_name
where o.order_status='delivered';

/* Dato: 1.41% de órdenes sin categoría
      ↓
 Métrica: Por debajo del umbral del 2%
      ↓
 Insight: Dataset limpio — los NULLs no distorsionan el análisis
      ↓
 Decisión: Documentar como limitación menor y continuar*/
      
 -- Pregunta de negocio: "¿Las categorías top venden más porque tienen precios altos o porque mueven más volumen?"
select
pct.product_category_name_english as product_category,
round(sum(oi.price)::numeric, 2) as revenue_per_category,
count(distinct o.order_id) as total_orders,
round(sum(oi.price)::numeric/
count(distinct o.order_id), 2) as ticket_promedio,
round(sum(oi.price)::numeric/
count( oi.order_item_id), 2) as ticket_item_promedio
from raw.orders as o
left join raw.order_items as oi
on oi.order_id=o.order_id
left join raw.products as p
on p.product_id=oi.product_id
left join raw.product_category_translation as pct
on pct.product_category_name =p.product_category_name 
where o.order_status='delivered'
and pct.product_category_name_english is not null
group by product_category
order by revenue_per_category desc
limit 10;

/* Perfil 1 — Alto volumen, ticket bajo:
bed_bath_table → 9,272 órdenes / $110 ticket
health_beauty → 8,647 órdenes / $142 ticket
Perfil 2 — Bajo volumen, ticket alto:
watches_gifts → 5,495 órdenes / $212 ticket
cool_stuff → 3,559 órdenes / $171 ticket
Perfil 3 — Balance intermedio:
computers_accessories → 6,530 órdenes / $136 ticket

✅ Razonamiento correcto:
- health_beauty: upselling/cross-selling para subir ticket
- watches_gifts: adquisición de nuevos clientes vía marketing
- bed_bath_table: retención y consistencia operativa

Dato: ticket_promedio $212 vs ticket_item_promedio $199
      ↓
Diferencia mínima ($13) → los clientes compran ~1 ítem por orden
      ↓
Insight: El ticket alto es POR PRECIO DEL PRODUCTO, no por volumen
      ↓
Recomendación confirmada: invertir en adquisición de nuevos clientes
→ cada cliente nuevo que entra, gasta ~$200 en su primera compra

cool_stuff — posición 8 en revenue pero ticket_item_promedio de $164, 
 el segundo más alto del Top 10. Categoría con potencial desaprovechado — 
 *pocas órdenes (3,559) pero productos de alto valor
 
-- Pregunta de negocio:"¿Qué estados de Brasil concentran el mayor revenue y ticket promedio?" */

select
c.customer_state as state,
round(sum(oi.price) :: numeric, 2) as revenue_per_state,
count(distinct o.order_id) as total_orders,
round(sum(oi.price) :: numeric/
count(distinct o.order_id), 2) as ticket_promedio_per_state
from raw.orders o
left join raw.customers c
on c.customer_id = o.customer_id 
left join raw.order_items oi
on oi.order_id = o.order_id 
where o.order_status = 'delivered'
group by state
order by revenue_per_state  desc;

/* Observación 1: SP lidera en revenue con ticket bajo
      ↓
Insight: SP (São Paulo) es el centro económico e industrial 
de Brasil — mayor población, mayor volumen de compras
Estrategia: volumen masivo compensa ticket bajo

Observación 2: CE (Ceará) ticket promedio $171 con poco volumen
      ↓
Insight: Mercado pequeño pero de mayor poder adquisitivo
o categorías premium — oportunidad de crecimiento
Estrategia: expandir presencia en Nordeste

Observación 3: Correlación revenue ~ total_orders
      ↓
Alerta estadística CORRECTA: revenue = precio × órdenes
Son matemáticamente dependientes — no es correlación real

3 de los top 5 son del Sudeste — la región más industrializada y poblada de Brasil.
El e-commerce sigue la concentración económica del país.
*/





















