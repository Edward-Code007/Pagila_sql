-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 2)
-- Nivel: intermedio-avanzado
-- ============================================

-- ----- AGREGADOS AVANZADOS (string_agg, array_agg, FILTER) -----

-- 13. Para cada película, muestra su título y la lista de todos sus actores
--     concatenados en una sola columna separados por comas (pista: string_agg).
SELECT f.title, STRING_AGG(a.first_name || ' ' || a.last_name, ', ')
FROM film f
JOIN film_actor fa USING (film_id)
JOIN actor a USING (actor_id)
GROUP BY f.title
ORDER BY f.title;

-- 14. Para cada categoría, muestra cuántas películas tiene en total y, en columnas
--     separadas, cuántas son de rental_rate 0.99, 2.99 y 4.99 respectivamente
--     (pista: count(*) FILTER (WHERE ...)).
SELECT c."name",
       COUNT(*) AS "Cantidad",
       COUNT(*) FILTER (WHERE f.rental_rate = 0.99) AS "Cantidad Rate 0.99",
       COUNT(*) FILTER (WHERE f.rental_rate = 2.99) AS "Cantidad Rate 2.99",
       COUNT(*) FILTER (WHERE f.rental_rate = 4.99) AS "Cantidad Rate 4.99"
FROM category c
JOIN film_category fc USING (category_id)
JOIN film f USING (film_id)
GROUP BY c.category_id;

-- 15. Muestra el nombre de cada cliente junto con un array de todos los film_id
--     que ha rentado (pista: array_agg). Limita a los primeros 10 clientes.
SELECT c.customer_id, c.first_name, ARRAY_AGG(i.film_id) AS "Peliculas Rentadas"
FROM customer c
JOIN rental r USING (customer_id)
JOIN inventory i USING (inventory_id)
GROUP BY c.customer_id, c.first_name
LIMIT 10;

-- ----- ESTADÍSTICAS / PERCENTILES -----

-- 16. Calcula la mediana, el percentil 25 y el percentil 75 del monto (amount)
--     de los pagos (pista: percentile_cont WITHIN GROUP).
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.amount) AS "Mediana",
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY p.amount) AS "Percentil 25",
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY p.amount) AS "Percentil 75"
FROM payment p;

-- 17. Para cada tienda, calcula el promedio y la desviación estándar (stddev)
--     del total gastado por sus clientes.
EXPLAIN ANALYZE
WITH gato_total_clientes AS (
    SELECT s.store_id, c.customer_id, SUM(p.amount) AS "Total"
    FROM store s
    JOIN customer c USING (store_id)
    JOIN payment p USING (customer_id)
    GROUP BY s.store_id, c.customer_id
)
SELECT store_id,
       AVG(gt."Total") AS "Promedio",
       STDDEV(gt."Total") AS "Standard_Dev"
FROM gato_total_clientes gt
GROUP BY store_id;

-- ----- WINDOW FUNCTIONS (acumulados y comparaciones) -----

-- 18. Para cada pago de cada cliente, muestra el total acumulado (running total)
--     de lo que ha gastado hasta ese pago, ordenado por fecha
--     (pista: SUM(...) OVER (PARTITION BY ... ORDER BY ...))
SELECT p.customer_id,
       SUM(p.amount) OVER (PARTITION BY p.customer_id ORDER BY p.payment_date)
FROM payment p;

-- 19. Muestra los 3 meses con mayor ingreso, junto con qué porcentaje representan
--     del ingreso total de todo el año (pista: window sin PARTITION para el total).
WITH month_year_amount AS (
    SELECT EXTRACT(MONTH FROM p.payment_date) AS "Month",
           EXTRACT(YEAR FROM p.payment_date) AS "Anio",
           p.amount AS "Monto"
    FROM payment p
),
month_year_tmount AS (
    SELECT my."Month", my."Anio",
           SUM(my."Monto") AS "Monto_Total"
    FROM month_year_amount my
    GROUP BY my."Month", my."Anio"
)
SELECT *,
       ROUND((tm."Monto_Total" / SUM(tm."Monto_Total") OVER (PARTITION BY tm."Anio")) * 100, 3) AS "%_del_Total"
FROM month_year_tmount tm
ORDER BY tm."Monto_Total" DESC
LIMIT 3;

-- 20. Para cada categoría, lista sus películas ordenadas por rental_rate y muestra
--     la diferencia entre cada película y la más cara de su categoría
--     (pista: FIRST_VALUE o MAX() OVER (PARTITION BY ...)).
SELECT fc.category_id, f.rental_rate,
       MAX(f.rental_rate) OVER (PARTITION BY fc.category_id) - f.rental_rate AS "Dif_rate"
FROM film f
JOIN film_category fc USING (film_id)
ORDER BY fc.category_id, f.rental_rate DESC;

-- ----- SUBCONSULTAS Y EXISTS -----

-- 21. Encuentra los actores que han trabajado en películas de TODAS las categorías
--     que existen (pista: comparar count distinto de categorías por actor contra
--     el total de categorías).
WITH count_movies AS (
    SELECT a.actor_id,
           COUNT(DISTINCT fc.category_id) AS "Cat_Actuadas"
    FROM actor a
    JOIN film_actor fa USING (actor_id)
    JOIN film_category fc USING (film_id)
    GROUP BY a.actor_id
)
SELECT cm.actor_id FROM count_movies cm
WHERE cm."Cat_Actuadas" = (SELECT COUNT(*) FROM category c);

-- 22. Lista los clientes que han rentado al menos una película de categoría "Horror"
--     pero NUNCA una de categoría "Comedy" (pista: EXISTS + NOT EXISTS).
SELECT DISTINCT c.customer_id, c.first_name
FROM customer c
WHERE EXISTS (
    SELECT 1
    FROM rental r
    JOIN inventory i USING (inventory_id)
    JOIN film_category fc USING (film_id)
    JOIN category cat USING (category_id)
    WHERE r.customer_id = c.customer_id AND cat.name = 'Horror'
)
AND NOT EXISTS (
    SELECT 1
    FROM rental r
    JOIN inventory i USING (inventory_id)
    JOIN film_category fc USING (film_id)
    JOIN category cat USING (category_id)
    WHERE r.customer_id = c.customer_id AND cat.name = 'Comedy'
);

-- ----- MODIFICACIÓN DE DATOS (UPDATE / INSERT con lógica) -----

-- 23. Crea una columna nueva "categoria_precio" en una tabla temporal o CTE que
--     clasifique cada película como 'Barata' (<2), 'Media' (2-4) o 'Cara' (>4)
--     según su rental_rate (pista: CASE WHEN).
CREATE TEMP TABLE categoria_precio AS
SELECT f.title,
       CASE
           WHEN f.rental_rate < 2 THEN 'Barata'
           WHEN f.rental_rate <= 4 THEN 'Media'
           ELSE 'Cara'
       END AS "Categoria_Precio"
FROM film f;

SELECT * FROM categoria_precio;
DROP TABLE categoria_precio;

-- 24. Usando UPDATE con FROM, sube un 5% el rental_rate únicamente de las películas
--     que pertenecen a la categoría "Sci-Fi" (recuerda probar primero con un SELECT).
SELECT f.rental_rate
FROM film f
JOIN film_category fc USING (film_id)
JOIN category c USING (category_id)
WHERE c."name" = 'Sci-Fi';

BEGIN;
UPDATE film f
SET rental_rate = rental_rate + (rental_rate * 0.05)
FROM film_category fc
JOIN category c USING (category_id)
WHERE f.film_id = fc.film_id AND c."name" = 'Sci-Fi';
ROLLBACK;

-- ----- JOINS Y AUTO-RELACIÓN / COMBINADOS -----

-- 25. Muestra pares de películas que comparten exactamente el mismo rental_rate
--     y la misma duración (length), sin repetir el par invertido
--      (pista: self-join con f1.film_id < f2.film_id).
SELECT f1.title, f2.title, f1.length
FROM film f1
JOIN film f2 ON f1.rental_rate = f2.rental_rate
AND f1.length = f2.length
AND f1.film_id < f2.film_id;

-- 26. Lista las películas que tienen más copias en la tienda 1 que en la tienda 2
--     (pista: contar inventory por store_id y comparar, puede usar FILTER o pivot).
CREATE TEMP TABLE cont_movie_store1 AS (
    SELECT i.store_id, i.film_id, COUNT(*) AS "Cont"
    FROM inventory i
    WHERE i.store_id = 1
    GROUP BY i.store_id, i.film_id
);
CREATE TEMP TABLE cont_movie_store2 AS (
    SELECT i.store_id, i.film_id, COUNT(*) AS "Cont"
    FROM inventory i
    WHERE i.store_id = 2
    GROUP BY i.store_id, i.film_id
);
SELECT s1.film_id, s1."Cont" AS "Cont_S1", COALESCE(s2."Cont", 0) AS "Cont_S2"
FROM cont_movie_store1 s1
LEFT JOIN cont_movie_store2 s2
ON s1.film_id = s2.film_id
WHERE s1."Cont" > COALESCE(s2."Cont", 0);
