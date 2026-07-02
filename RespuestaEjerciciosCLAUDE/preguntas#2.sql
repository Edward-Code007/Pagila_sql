-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA
-- ============================================

-- 1. Lista las 5 películas más rentadas (por cantidad de veces que aparecen en rental),
--    junto con el conteo.
select f.film_id,f.title,count(*) as Counteo from film f
join inventory i using(film_id)
join rental r using(inventory_id)
group by f.film_id
order by Counteo desc
limit 5;


-- 2. ¿Cuál es el actor que ha participado en más películas?
--    Muestra su nombre completo y la cantidad.
select a.first_name, a.last_name, count(*) as "Cantidad" from actor a
join film_actor fa using(actor_id)
group by a.actor_id
order by "Cantidad" desc
Limit 1;


-- 3. Para cada categoría de película, muestra el promedio de rental_rate
--    y el promedio de length (duración).
select c."name" as "Categoria",round(avg(f.rental_rate),2) as "Promedio_Renta", round(avg(f.length),2) as "Promedio_Duracion"  from category c 
join film_category fc using(category_id)
join film f using(film_id)
group by "Categoria";

-- 4. Lista las películas que NUNCA han sido rentadas.
--    (pista: film -> inventory -> rental, una película puede tener varias copias en inventory)
select f.film_id, f.title 
from film f
where not exists (
    select 1 from inventory i 
    join rental r on r.inventory_id = i.inventory_id
    where i.film_id = f.film_id
);
-- 5. Muestra los clientes cuyo total gastado está por encima del promedio
--    de gasto de todos los clientes.
select c.first_name, sum(p.amount) as "Total" from customer c
join payment p using(customer_id)
group by c.customer_id
having sum(p.amount) > All (
select avg(p.amount) from payment p
group by p.customer_id
)
order by "Total" desc
;


-- 6. Para cada película, muestra su rental_rate junto con el promedio de rental_rate
--    de su categoría, usando AVG() OVER (PARTITION BY ...), sin necesidad de GROUP BY.
select f.rental_rate, avg(f.rental_rate) 
over (partition by fc.category_id) from film f 
join film_category fc using(film_id);



-- 7. Calcula, para cada pago, la diferencia entre ese pago y el pago anterior
--    del mismo cliente. (pista: LAG())
	--EXPLAIN 
	with pagos_con_anterior AS (
    select p.customer_id, p.payment_date, p.amount,
           lag(p.amount, 1, 0) over(partition by p.customer_id order by p.payment_date) as pago_anterior
    from payment p
)
	select p.customer_id,pago_anterior as pago_anterior,
	p.amount - pago_anterior as diferencia
	from pagos_con_anterior p
	order by p.customer_id;

-- 8. Usa NTILE(4) para dividir a los clientes en 4 grupos (cuartiles)
--    según su gasto total.
	with totales_cliente as (
    select c.customer_id, sum(p.amount) as total
    from customer c
    join payment p using(customer_id)
    group by c.customer_id
)
select customer_id, total,
       ntile(4) over (order by total desc) as cuartil
from totales_cliente
order by total desc;

-- 9. Usando una CTE, calcula el ingreso total por mes (payment_date) y luego,
--    en la consulta principal, muestra solo los meses cuyo ingreso superó los $5000.
with ingreso_total_mes as (
	select extract(month from p.payment_date) as "Month",sum(p.amount) as "Amount"  
	from payment p
	group by "Month"
)
select * from
(select "Month" , "Amount" as "Total" from ingreso_total_mes) as Resumen_Agrupado
where "Total" > 5000;

-- 10. Con una CTE, identifica para cada cliente su película más rentada
--     (la que más veces alquiló). Pista: ROW_NUMBER() dentro de la CTE
--     para quedarte solo con el "top 1" por cliente. Resulto Compleja
with rentas_por_pelicula as (
    select c.customer_id, i.film_id, count(*) as veces
    from customer c
    join rental r using(customer_id)
    join inventory i using(inventory_id)
    group by c.customer_id, i.film_id
),
top_pelicula as (
    select customer_id, film_id, veces,
    row_number() over (partition by customer_id order by veces desc) as rn
    from rentas_por_pelicula
)
select customer_id, film_id, veces
from top_pelicula
where rn = 1;


-- 11. Lista el Top 3 de clientes que más han gastado POR TIENDA (store).
--     Pista: RANK() o ROW_NUMBER() con PARTITION BY store_id, luego filtrar por posición.
	with gastos_total as (
	select c.customer_id, c.store_id, sum(p.amount) as "Total" from customer c
	join payment p using(customer_id)
	group by c.store_id,c.customer_id
	), 
	ranked as (select *, row_number() over (partition by gt.store_id order by gt."Total" desc) as "Ranking"
	from gastos_total as gt)
	select * from ranked as r where r."Ranking" <= 3 ;

-- 12. Encuentra las películas que están en el catálogo (film) pero que tienen
--     0 copias disponibles actualmente en inventory para rentar.
--     (No es lo mismo que el ejercicio 4: aquí es sobre stock físico, no historial)
with copia_estado as (
    select i.inventory_id, i.film_id,
           exists (
               select 1 from rental r
               where r.inventory_id = i.inventory_id
               and r.return_date is null
           ) as ocupada
    from inventory i
)
select f.film_id, f.title
from film f
join copia_estado ce on ce.film_id = f.film_id
group by f.film_id, f.title
having bool_and(ce.ocupada)
order by f.film_id;
 select * from inventory i 
 join film f using(film_id)
 join store s using(store_id)
 join rental r using(inventory_id) where f.film_id = 1;

-- Marcar como no devueltas todas las rentas de las copias de la película 1
UPDATE rental
SET return_date = NULL
WHERE inventory_id IN (SELECT inventory_id FROM inventory WHERE film_id = 1);
