/*Distribución de Review Scores
Pregunta de negocio:"¿Cómo se distribuye la satisfacción de los clientes de Olist?"*/

select
review_score,
count(*) as total_reviews,
round(count(*)*100.0/sum(count(*)) over(), 2) as pct
from raw.reviews r
left join raw.orders o
on o.order_id=r.order_id
where o.order_status='delivered'
group by review_score
order by review_score desc;

/* 
Dato:
  Score 5 → 57.78%
  Score 4 → 19.29%
  Score 1 → 11.51%  ← preocupante
  Score 2 →  3.18%
      ↓
Satisfechos (4-5★): 77.07% ✅
Insatisfechos (1-2★): 14.69% ⚠️
      ↓
Insight: 1 de cada 7 clientes tuvo mala experiencia
El score 1 supera al score 2 — clientes tan 
insatisfechos que van al extremo, sin término medio
      ↓
Pregunta correcta: ¿qué patrón tienen esos 14,575
clientes insatisfechos?
*/

/*Sellers con Peor Reputación
Pregunta de negocio:"¿Qué sellers concentran las peores calificaciones?"*/

select 
s.seller_id,
round(avg(r.review_score)::numeric, 2) as avg_score,
count(*) as total_reviews,
round(count(*) filter(where r.review_score <= 2)*100.0/count(*), 2) as pct_negativas
from raw.orders o
left join raw.order_items oi
on oi.order_id=o.order_id
left join raw.sellers s
on s.seller_id=oi.seller_id
left join raw.reviews r
on r.order_id=o.order_id
where s.seller_id is not null
and o.order_status= 'delivered'
group by s.seller_id
having count(*) >= 30
order by avg_score
limit 10;
/*
 "Suspender Seller #5 por mayor daño absoluto a clientes,
pero investigar Seller #1 en paralelo — 
un seller donde 2 de cada 3 clientes queda insatisfecho es un riesgo de reputación sistémico."*/

/*Categorías con Mayor Insatisfacción
Pregunta de negocio: "¿Qué categorías de producto generan más insatisfacción?"*/

select 
pct.product_category_name_english as product_category,
round(avg(r.review_score), 2) as avg_review_score,
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
having count(*) > 50
order by avg_review_score
limit 10;

/*
Dato Módulo 1: bed_bath_table = #3 en revenue, 9,272 órdenes
Dato Módulo 3: bed_bath_table = #6 en insatisfacción, 18.11% negativas
      ↓
Insight cruzado: categoría de alto volumen + satisfacción
media-baja = riesgo de erosión de revenue
      ↓
Recomendación: auditar sellers de bed_bath_table,
revisar tiempos de entrega específicos de la categoría
y calidad del producto — antes de que el problema
escale y afecte su posición en revenue
*/