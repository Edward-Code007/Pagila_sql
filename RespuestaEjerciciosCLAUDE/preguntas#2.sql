-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA
-- ============================================

-- 1. Lista las 5 películas más rentadas (por cantidad de veces que aparecen en rental),
--    junto con el conteo.
SELECT f.film_id, f.title, COUNT(*) AS counteo
FROM film f
JOIN inventory i USING (film_id)
JOIN rental r USING (inventory_id)
GROUP BY f.film_id
ORDER BY counteo DESC
LIMIT 5;

-- 2. ¿Cuál es el actor que ha participado en más películas?
--    Muestra su nombre completo y la cantidad.
SELECT a.first_name, a.last_name, COUNT(*) AS "Cantidad"
FROM actor a
JOIN film_actor fa USING (actor_id)
GROUP BY a.actor_id
ORDER BY "Cantidad" DESC
LIMIT 1;

-- 3. Para cada categoría de película, muestra el promedio de rental_rate
--    y el promedio de length (duración).
SELECT c."name" AS "Categoria",
       ROUND(AVG(f.rental_rate), 2) AS "Promedio_Renta",
       ROUND(AVG(f.length), 2) AS "Promedio_Duracion"
FROM category c
JOIN film_category fc USING (category_id)
JOIN film f USING (film_id)
GROUP BY "Categoria";

-- 4. Lista las películas que NUNCA han sido rentadas.
--    (pista: film -> inventory -> rental, una película puede tener varias copias en inventory)
SELECT f.film_id, f.title
FROM film f
WHERE NOT EXISTS (
    SELECT 1 FROM inventory i
    JOIN rental r ON r.inventory_id = i.inventory_id
    WHERE i.film_id = f.film_id
);

-- 5. Muestra los clientes cuyo total gastado está por encima del promedio
--    de gasto de todos los clientes.
SELECT c.first_name, SUM(p.amount) AS "Total"
FROM customer c
JOIN payment p USING (customer_id)
GROUP BY c.customer_id
HAVING SUM(p.amount) > ALL (
    SELECT AVG(p.amount) FROM payment p
    GROUP BY p.customer_id
)
ORDER BY "Total" DESC;

-- 6. Para cada película, muestra su rental_rate junto con el promedio de rental_rate
--    de su categoría, usando AVG() OVER (PARTITION BY ...), sin necesidad de GROUP BY.
SELECT f.rental_rate,
       AVG(f.rental_rate) OVER (PARTITION BY fc.category_id)
FROM film f
JOIN film_category fc USING (film_id);

-- 7. Calcula, para cada pago, la diferencia entre ese pago y el pago anterior
--    del mismo cliente. (pista: LAG())
--EXPLAIN
WITH pagos_con_anterior AS (
    SELECT p.customer_id, p.payment_date, p.amount,
           LAG(p.amount, 1, 0) OVER (PARTITION BY p.customer_id ORDER BY p.payment_date) AS pago_anterior
    FROM payment p
)
SELECT p.customer_id, pago_anterior AS pago_anterior,
       p.amount - pago_anterior AS diferencia
FROM pagos_con_anterior p
ORDER BY p.customer_id;

-- 8. Usa NTILE(4) para dividir a los clientes en 4 grupos (cuartiles)
--    según su gasto total.
WITH totales_cliente AS (
    SELECT c.customer_id, SUM(p.amount) AS total
    FROM customer c
    JOIN payment p USING (customer_id)
    GROUP BY c.customer_id
)
SELECT customer_id, total,
       NTILE(4) OVER (ORDER BY total DESC) AS cuartil
FROM totales_cliente
ORDER BY total DESC;

-- 9. Usando una CTE, calcula el ingreso total por mes (payment_date) y luego,
--    en la consulta principal, muestra solo los meses cuyo ingreso superó los $5000.
WITH ingreso_total_mes AS (
    SELECT EXTRACT(MONTH FROM p.payment_date) AS "Month", SUM(p.amount) AS "Amount"
    FROM payment p
    GROUP BY "Month"
)
SELECT *
FROM (SELECT "Month", "Amount" AS "Total" FROM ingreso_total_mes) AS resumen_agrupado
WHERE "Total" > 5000;

-- 10. Con una CTE, identifica para cada cliente su película más rentada
--     (la que más veces alquiló). Pista: ROW_NUMBER() dentro de la CTE
--     para quedarte solo con el "top 1" por cliente. Resulto Compleja
WITH rentas_por_pelicula AS (
    SELECT c.customer_id, i.film_id, COUNT(*) AS veces
    FROM customer c
    JOIN rental r USING (customer_id)
    JOIN inventory i USING (inventory_id)
    GROUP BY c.customer_id, i.film_id
),
top_pelicula AS (
    SELECT customer_id, film_id, veces,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY veces DESC) AS rn
    FROM rentas_por_pelicula
)
SELECT customer_id, film_id, veces
FROM top_pelicula
WHERE rn = 1;

-- 11. Lista el Top 3 de clientes que más han gastado POR TIENDA (store).
--     Pista: RANK() o ROW_NUMBER() con PARTITION BY store_id, luego filtrar por posición.
WITH gastos_total AS (
    SELECT c.customer_id, c.store_id, SUM(p.amount) AS "Total"
    FROM customer c
    JOIN payment p USING (customer_id)
    GROUP BY c.store_id, c.customer_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY gt.store_id ORDER BY gt."Total" DESC) AS "Ranking"
    FROM gastos_total AS gt
)
SELECT * FROM ranked AS r WHERE r."Ranking" <= 3;

-- 12. Encuentra las películas que están en el catálogo (film) pero que tienen
--     0 copias disponibles actualmente en inventory para rentar.
--     (No es lo mismo que el ejercicio 4: aquí es sobre stock físico, no historial)
WITH copia_estado AS (
    SELECT i.inventory_id, i.film_id,
           EXISTS (
               SELECT 1 FROM rental r
               WHERE r.inventory_id = i.inventory_id
               AND r.return_date IS NULL
           ) AS ocupada
    FROM inventory i
)
SELECT f.film_id, f.title
FROM film f
JOIN copia_estado ce ON ce.film_id = f.film_id
GROUP BY f.film_id, f.title
HAVING BOOL_AND(ce.ocupada)
ORDER BY f.film_id;

SELECT *
FROM inventory i
JOIN film f USING (film_id)
JOIN store s USING (store_id)
JOIN rental r USING (inventory_id)
WHERE f.film_id = 1;

-- Marcar como no devueltas todas las rentas de las copias de la película 1
UPDATE rental
SET return_date = NULL
WHERE inventory_id IN (SELECT inventory_id FROM inventory WHERE film_id = 1);
