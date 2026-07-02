-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 2)
-- Nivel: intermedio-avanzado
-- ============================================

-- ----- AGREGADOS AVANZADOS (string_agg, array_agg, FILTER) -----

-- 13. Para cada película, muestra su título y la lista de todos sus actores
--     concatenados en una sola columna separados por comas (pista: string_agg).
select f.title, string_agg(a.first_name || ' ' || a.last_name,', ') from film f
join film_actor fa using(film_id)
join actor a using(actor_id)
group by f.title 
order by f.title;

-- 14. Para cada categoría, muestra cuántas películas tiene en total y, en columnas
--     separadas, cuántas son de rental_rate 0.99, 2.99 y 4.99 respectivamente
--     (pista: count(*) FILTER (WHERE ...)).
select c."name" , 
count(*) as "Cantidad" ,
count(*) filter (where f.rental_rate = 0.99) as "Cantidad Rate 0.99",
count(*) filter (where f.rental_rate = 2.99) as "Cantidad Rate 2.99",
count(*) filter (where f.rental_rate = 4.99) as "Cantidad Rate 4.99"
from category c
join film_category fc using(category_id)
join film f using(film_id)
group by c.category_id;

-- 15. Muestra el nombre de cada cliente junto con un array de todos los film_id
--     que ha rentado (pista: array_agg). Limita a los primeros 10 clientes.
select c.customer_id,c.first_name,array_agg(i.film_id) as "Peliculas Rentadas" from customer c
join rental r using(customer_id)
join inventory i using(inventory_id)
group by c.customer_id,c.first_name
limit 10;

-- ----- ESTADÍSTICAS / PERCENTILES -----

-- 16. Calcula la mediana, el percentil 25 y el percentil 75 del monto (amount)
--     de los pagos (pista: percentile_cont WITHIN GROUP).
select 
percentile_cont(0.5) within group(order by p.amount) as "Mediana", 
percentile_cont(0.25) within group(order by p.amount) as "Percentil 25", 
percentile_cont(0.75) within group(order by p.amount) as "Percentil 75"
from payment p;

-- 17. Para cada tienda, calcula el promedio y la desviación estándar (stddev)
--     del total gastado por sus clientes.
explain analyze
with gato_total_clientes as (
select s.store_id,c.customer_id , sum(p.amount) as "Total"
from store s 
join customer c using(store_id)
join payment p using(customer_id)
group by s.store_id,c.customer_id)
select store_id,
avg(gt."Total") as "Promedio",
stddev(gt."Total") as "Standard_Dev"
from gato_total_clientes gt
group by store_id;

-- ----- WINDOW FUNCTIONS (acumulados y comparaciones) -----

-- 18. Para cada pago de cada cliente, muestra el total acumulado (running total)
--     de lo que ha gastado hasta ese pago, ordenado por fecha
--     (pista: SUM(...) OVER (PARTITION BY ... ORDER BY ...))
select p.customer_id,
sum(p.amount) over (partition by p.customer_id order by p.payment_date)
from payment p;

-- 19. Muestra los 3 meses con mayor ingreso, junto con qué porcentaje representan
--     del ingreso total de todo el año (pista: window sin PARTITION para el total).
with month_year_amount as 
(select extract(month from p.payment_date) as "Month", 
extract(year from p.payment_date) as "Anio" , p.amount as "Monto"
from payment  p ),
month_year_TMount as (
select my."Month", my."Anio",
sum(my."Monto") as "Monto_Total"
from month_year_amount my
group by my."Month",my."Anio"
)
select *, round((tm."Monto_Total"/sum(tm."Monto_Total") over (partition by tm."Anio")) * 100,3) as "%_del_Total" from month_year_TMount tm
order by tm."Monto_Total" desc
limit 3;

-- 20. Para cada categoría, lista sus películas ordenadas por rental_rate y muestra
--     la diferencia entre cada película y la más cara de su categoría
--     (pista: FIRST_VALUE o MAX() OVER (PARTITION BY ...)).
select fc.category_id,f.rental_rate,
max(f.rental_rate) over(partition by fc.category_id) - f.rental_rate as "Dif_rate"
from film f
join film_category fc using(film_id)
order by fc.category_id, f.rental_rate desc;


-- ----- SUBCONSULTAS Y EXISTS -----

-- 21. Encuentra los actores que han trabajado en películas de TODAS las categorías
--     que existen (pista: comparar count distinto de categorías por actor contra
--     el total de categorías).
with Count_Movies as(
select a.actor_id,
count(distinct fc.category_id) as "Cat_Actuadas"
from actor a
join film_actor fa using(actor_id)
join film_category fc using(film_id)
group by a.actor_id
)
select cm.actor_id from Count_Movies cm 
where cm."Cat_Actuadas" = (select count(*) from category c);

-- 22. Lista los clientes que han rentado al menos una película de categoría "Horror"
--     pero NUNCA una de categoría "Comedy" (pista: EXISTS + NOT EXISTS).
select distinct c.customer_id, c.first_name
from customer c
where exists (
    select 1
    from rental r
    join inventory i using(inventory_id)
    join film_category fc using(film_id)
    join category cat using(category_id)
    where r.customer_id = c.customer_id and cat.name = 'Horror'
)
and not exists (
    select 1
    from rental r
    join inventory i using(inventory_id)
    join film_category fc using(film_id)
    join category cat using(category_id)
    where r.customer_id = c.customer_id and cat.name = 'Comedy'
);
-- ----- MODIFICACIÓN DE DATOS (UPDATE / INSERT con lógica) -----

-- 23. Crea una columna nueva "categoria_precio" en una tabla temporal o CTE que
--     clasifique cada película como 'Barata' (<2), 'Media' (2-4) o 'Cara' (>4)
--     según su rental_rate (pista: CASE WHEN).
create temp table categoria_precio as
select f.title,
case 
when f.rental_rate < 2 then 'Barata'
when f.rental_rate <= 4 then 'Media'
else 'Cara'
end as "Categoria_Precio"
from film f;

select * from categoria_precio;
drop table categoria_precio;

-- 24. Usando UPDATE con FROM, sube un 5% el rental_rate únicamente de las películas
--     que pertenecen a la categoría "Sci-Fi" (recuerda probar primero con un SELECT).
select f.rental_rate from film f
join film_category fc using(film_id)
join category c using(category_id)
where c."name" = 'Sci-Fi';

begin;
update film f 
set rental_rate = rental_rate+(rental_rate*0.05)
from film_category fc 
join category c using(category_id)
where f.film_id = fc.film_id and c."name" = 'Sci-Fi';

rollback;
------- JOINS Y AUTO-RELACIÓN / COMBINADOS -----

-- 25. Muestra pares de películas que comparten exactamente el mismo rental_rate
--     y la misma duración (length), sin repetir el par invertido
--      (pista: self-join con f1.film_id < f2.film_id).
select f1.title, f2.title, f1.length from film f1
join film f2 on f1.rental_rate = f2.rental_rate 
and f1.length = f2.length 
and f1.film_id < f2.film_id;

-- 26. Lista las películas que tienen más copias en la tienda 1 que en la tienda 2
--     (pista: contar inventory por store_id y comparar, puede usar FILTER o pivot).
	create temp table cont_movie_store1 as (
	select i.store_id,i.film_id,count(*) as "Cont" from inventory i
	where i.store_id = 1
	group by i.store_id,i.film_id
	);
	create temp table cont_movie_store2 as (
	select i.store_id,i.film_id,count(*) as "Cont" from inventory i
	where i.store_id = 2
	group by i.store_id,i.film_id
	);
	select s1.film_id, s1."Cont" as "Cont_S1",Coalesce(s2."Cont",0) as "Cont_S2"
	from cont_movie_store1 s1
	left join cont_movie_store2 s2 
	on s1.film_id = s2.film_id
	where s1."Cont" > coalesce(s2."Cont",0);


