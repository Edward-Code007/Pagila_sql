--Lista los nombres y apellidos de todos los actores cuyo apellido empiece con 'W'.
select first_name, last_name from public.actor where last_name Like 'W%';
--Muestra el título de las películas con un rental_rate mayor a 4, ordenadas de mayor a menor.
select * from film where rental_rate > 4 order by rental_rate DESC;
--Lista el nombre completo del cliente junto con la ciudad donde vive.
select CONCAT(first_name,' ',last_name) as Full_Name , a.address, ci.city
from customer c 
Join address a 
using(address_id)
join city ci
using(city_id);
--Muestra el título de cada película junto con el nombre de su categoría.
select f.title , c.name from film f 
join film_category fc using(film_id)
join category c using(category_id);
--¿Cuál es el ingreso total (amount) generado por cada tienda (store)?
select st.store_id, SUM(p.amount) from store st
join staff s using (store_id)
join payment p using (staff_id)
group by st.store_id;
--¿Cuántas películas hay por cada categoría? Ordénalas de mayor a menor cantidad.
select cat."name", count(cat.category_id) as cantidad from film_category fcat 
join category cat using(category_id)
group by cat.category_id 
order by cantidad;
-- Lista los clientes que nunca han hecho un alquiler (rental).
select * from customer c where not exists ( select 1 from rental r where r.customer_id = c.customer_id );
--Muestra las películas cuyo rental_rate sea mayor al promedio de todas las películas.
select f.title  from film f where f.rental_rate > (select Avg(rental_rate) from film);
--Para cada cliente, muestra todos sus pagos junto con un número de fila (ROW_NUMBER()) 
select c.first_name,p.amount,p.payment_date,row_number() over(partition by c.customer_id) from customer c join payment p using(customer_id);
--Calcula el ranking de clientes según el total gastado, usando RANK().
select c.customer_id,c.first_name,sum(p.amount) as total_gastado, rank() over (order by sum(p.amount) desc) as rank 
from customer c
join payment p using(customer_id)
group by c.customer_id order by rank;


select * from rental;


