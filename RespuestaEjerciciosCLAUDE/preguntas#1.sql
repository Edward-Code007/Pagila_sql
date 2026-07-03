-- Lista los nombres y apellidos de todos los actores cuyo apellido empiece con 'W'.
SELECT first_name, last_name
FROM public.actor
WHERE last_name LIKE 'W%';

-- Muestra el título de las películas con un rental_rate mayor a 4, ordenadas de mayor a menor.
SELECT *
FROM film
WHERE rental_rate > 4
ORDER BY rental_rate DESC;

-- Lista el nombre completo del cliente junto con la ciudad donde vive.
SELECT CONCAT(first_name, ' ', last_name) AS full_name, a.address, ci.city
FROM customer c
JOIN address a USING (address_id)
JOIN city ci USING (city_id);

-- Muestra el título de cada película junto con el nombre de su categoría.
SELECT f.title, c.name
FROM film f
JOIN film_category fc USING (film_id)
JOIN category c USING (category_id);

-- ¿Cuál es el ingreso total (amount) generado por cada tienda (store)?
SELECT st.store_id, SUM(p.amount)
FROM store st
JOIN staff s USING (store_id)
JOIN payment p USING (staff_id)
GROUP BY st.store_id;

-- ¿Cuántas películas hay por cada categoría? Ordénalas de mayor a menor cantidad.
SELECT cat."name", COUNT(cat.category_id) AS cantidad
FROM film_category fcat
JOIN category cat USING (category_id)
GROUP BY cat.category_id
ORDER BY cantidad;

-- Lista los clientes que nunca han hecho un alquiler (rental).
SELECT *
FROM customer c
WHERE NOT EXISTS (SELECT 1 FROM rental r WHERE r.customer_id = c.customer_id);

-- Muestra las películas cuyo rental_rate sea mayor al promedio de todas las películas.
SELECT f.title
FROM film f
WHERE f.rental_rate > (SELECT AVG(rental_rate) FROM film);

-- Para cada cliente, muestra todos sus pagos junto con un número de fila (ROW_NUMBER())
SELECT c.first_name, p.amount, p.payment_date,
       ROW_NUMBER() OVER (PARTITION BY c.customer_id)
FROM customer c
JOIN payment p USING (customer_id);

-- Calcula el ranking de clientes según el total gastado, usando RANK().
SELECT c.customer_id, c.first_name, SUM(p.amount) AS total_gastado,
       RANK() OVER (ORDER BY SUM(p.amount) DESC) AS rank
FROM customer c
JOIN payment p USING (customer_id)
GROUP BY c.customer_id
ORDER BY rank;

SELECT * FROM rental;
