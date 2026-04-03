# VISTA DE REVENUE MENSUAL

create or replace view raw.v_revenue_mensual as
select
date_trunc('month', o.order_purchase_timestamp::TIMESTAMP) as month,
round(sum(op.payment_value):: numeric, 2) as revenue_per_month
from raw.orders as o
left join raw.order_payments as op
on op.order_id=o.order_id
where o.order_status = 'delivered'
and op.payment_value is not null
group by month;

# VISTA DE REVENUE POR CATEGORIA

create or replace view raw.v_revenue_categoria as
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
group by product_category;

# VISTA DE REVENUE POR ESTADO

create or replace view raw.v_revenue_estado as
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
group by state;

# VISTA DE ENTREGAS POR ESTADO

create or replace view raw.v_entregas_estado as
with tiempos_entrega as(
select 
c.customer_state,
extract(day from(nullif(o.order_delivered_customer_date, '')::timestamp - nullif(o.order_purchase_timestamp, '')::timestamp)) as delivery_days,
extract(day from(nullif(o.order_delivered_customer_date, '')::timestamp - nullif(o.order_estimated_delivery_date, '')::timestamp)) as delay_days
from raw.orders o
left join raw.customers c
on c.customer_id=o.customer_id
where o.order_status = 'delivered'
), 
entrega_a_tiempo as (
select
customer_state,
delivery_days,
delay_days,
case when delay_days < 0 then 'a tiempo' else 'tarde' end as tipo_entrega
from tiempos_entrega
)
select 
customer_state,
round(avg(delivery_days)::numeric, 2) as avg_delivery_days,
round(avg(delay_days)::numeric, 2) as avg_delay_days,
round(count(*) filter(where tipo_entrega = 'a tiempo')*100.0/
count(*), 2) as pct_on_time,
count(*) as total_orders
from entrega_a_tiempo
group by customer_state
having count(*) > 100;

# VISTA SATISFACCION CATEGORIA

create or replace view raw.v_satisfaccion_categoria as
select 
pct.product_category_name_english as product_category,
round(avg(r.review_score)::numeric, 2) as avg_review_score,
count(*) as total_reviews,
round(count(*) filter (where r.review_score <= 2)*100.0/count(*), 2) as pct_negativas
from raw.orders o
left join raw.order_items oi
on oi.order_id=o.order_id
left join raw.products p
on p.product_id=oi.product_id
left join raw.product_category_translation pct
on pct.product_category_name=p.product_category_name
left join raw.reviews r
on r.order_id=o.order_id
where pct.product_category_name is not null
and o.order_status = 'delivered'
group by product_category
having count(*) > 50;

