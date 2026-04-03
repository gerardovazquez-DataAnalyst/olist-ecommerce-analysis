/*Diagnóstico de Entregas
Pregunta de negocio:

"¿Cuántos días tarda Olist en entregar en promedio y qué tan precisas son sus estimaciones?"*/

with tiempos_entrega as(
select 
extract(day from(nullif(order_delivered_customer_date, '')::timestamp - nullif(order_purchase_timestamp, '')::timestamp)) as delivery_days,
extract(day from(nullif(order_estimated_delivery_date, '')::timestamp - nullif(order_purchase_timestamp, '')::timestamp)) as estimated_days,
extract(day from(nullif(order_delivered_customer_date, '')::timestamp - nullif(order_estimated_delivery_date, '')::timestamp)) as delay_days
from raw.orders 
where order_status = 'delivered'
), 
entrega_a_tiempo as (
select
delivery_days,
estimated_days,
delay_days,
case when delay_days < 0 then 'a tiempo' else 'tarde' end as tipo_entrega
from tiempos_entrega
)
select 
round(avg(delivery_days)::numeric, 2) as avg_delivery_days,
round(avg(estimated_days)::numeric, 2) as avg_estimated_days,
round(avg(delay_days)::numeric, 2) as avg_delay_days,
round(count(*) filter(where tipo_entrega = 'a tiempo')*100.0/
count(*), 2) as pct_on_time,
count(*) filter(where delay_days > 30) as ordenes_super_retrasadas
from entrega_a_tiempo;

/*Olist entrega 11 días ANTES de lo prometido en promedio... pero solo el 90% llega a tiempo. ¿Cómo es posible eso?
Hipótesis:
- El promedio de -10.96 días está sesgado por órdenes 
  que llegaron MUY antes (outliers positivos)
- Pero un grupo de órdenes llega con retrasos severos
  que bajan el pct_on_time a 90.36%
- El promedio "miente" — esconde la distribución real
 */

-- ¿Cuántas órdenes tienen un retraso mayor a 30 días?

/*Dato: 90.36% on-time + avg_delay = -10.96 días
      ↓
Insight: Olist es conservador con sus estimaciones —
promete 23 días y entrega en 12. Estrategia intencional
para "sorprender positivamente" al cliente.
      ↓
Problema real: El 9.64% que llega tarde tiene retrasos
severos — 345 órdenes superan los 30 días de retraso.
      ↓
Recomendación: Investigar esas 345 órdenes —
¿son de estados específicos? ¿sellers específicos?
¿categorías específicas?*/


/* Desempeño por Estado
Pregunta de negocio:
"¿Qué estados tienen el peor desempeño de entrega?"*/

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
having count(*) > 100
order by pct_on_time asc;

/*Patrón identificado: Nordeste = problema logístico sistémico
      ↓
Hipótesis AL: outliers de entregas muy tempranas
              sesgan el promedio hacia negativo
              pero el grueso llega tarde
      ↓
Recomendación: Olist debería priorizar infraestructura
logística en Nordeste — especialmente AL, MA, PI*/


/*¿El retraso afecta el review score?
Pregunta de negocio:
"¿Los pedidos que llegan tarde reciben peores calificaciones?"*/

with tiempos_entrega as(
select 
c.customer_state,
r.review_score,
extract(day from(nullif(o.order_delivered_customer_date, '')::timestamp - nullif(o.order_purchase_timestamp, '')::timestamp)) as delivery_days,
extract(day from(nullif(o.order_delivered_customer_date, '')::timestamp - nullif(o.order_estimated_delivery_date, '')::timestamp)) as delay_days
from raw.orders o
left join raw.customers c
on c.customer_id=o.customer_id
left join raw.reviews r 
on r.order_id = o.order_id 
where o.order_status = 'delivered'
), 
entrega_a_tiempo as (
select
customer_state,
review_score,
delivery_days,
delay_days,
case when delay_days < 0 then 'a tiempo' else 'tarde' end as tipo_entrega
from tiempos_entrega
)
select 
tipo_entrega,
round(avg(review_score)::numeric, 2) as avg_review_score,
count(*) as total_orders
from entrega_a_tiempo
group by tipo_entrega;

/*"Los datos muestran que pedidos con retraso reciben en promedio 1.5 puntos menos en review score. 
 Aunque no podemos afirmar causalidad directa, la magnitud de la diferencia justifica investigar 
 y atacar los retrasos como prioridad operativa — especialmente en el Nordeste."*/



