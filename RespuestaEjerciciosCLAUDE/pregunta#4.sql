-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 3)
-- Incluye: INSERT, UPDATE, DELETE, transacciones,
-- constraints, y consultas avanzadas
-- IMPORTANTE: envuelve los ejercicios de modificación
-- en BEGIN; ... ROLLBACK; para no dañar tus datos
-- ============================================

-- ----- INSERCIÓN DE REGISTROS (INSERT) -----

-- 27. Inserta un nuevo actor con tu nombre y apellido en la tabla actor.
--     (pista: no especifiques actor_id, deja que la secuencia lo genere)
BEGIN;
INSERT INTO actor (first_name, last_name) VALUES ('EDUARDO', 'GONZALEZ');
ROLLBACK;

SELECT * FROM actor WHERE first_name = 'EDUARDO';

-- 28. Inserta una nueva categoría llamada 'Indie'. Luego, inserta una película
--     nueva y asóciala a esa categoría (necesitarás INSERT en film y en film_category).
BEGIN;
WITH insert_category AS (
    INSERT INTO category ("name") VALUES ('Indie') RETURNING category_id
),
insert_film AS (
    INSERT INTO film (title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, "length", replacement_cost, rating, special_features, fulltext)
    VALUES ('100HorasConFidel', 'Vida de Fidel', 2000, 1, 1, 5, 2.99, 60, 1.0, 'G', '{Deleted Scenes,Behind_Scene}', TO_TSVECTOR('english', 'fidel')) RETURNING film_id
)
INSERT INTO film_category (film_id, category_id)
SELECT film_id, category_id FROM insert_category, insert_film;
ROLLBACK;

-- 29. Inserta 3 actores de un solo golpe usando un único INSERT con múltiples filas.
BEGIN;
INSERT INTO actor (first_name, last_name)
VALUES ('Eduardo', 'Gonzalez'), ('Roymer', 'Yandel'), ('Frank', 'Verazain');
ROLLBACK;

-- 30. Usa INSERT ... SELECT para crear una tabla de respaldo (backup) de todas las
--     películas de categoría 'Horror' en una tabla nueva llamada horror_backup.

CREATE TEMP TABLE horror_backup AS (
    SELECT f.title FROM category c
    JOIN film_category fc USING (category_id)
    JOIN film f USING (film_id)
    WHERE c."name" = 'Horror'
);
DROP TABLE horror_backup;

-- ----- ACTUALIZACIÓN (UPDATE) -----

-- 31. Sube en 1 día el rental_duration de todas las películas cuya duración (length)
--     sea mayor a 120 minutos.
BEGIN;
UPDATE film f SET rental_duration = f.rental_duration + 1
WHERE f.length > 120;
ROLLBACK;
SELECT * FROM film;

-- 32. Usando UPDATE con CASE, ajusta el rental_rate: las películas 'G' suben 10%,
--     las 'PG' suben 5%, y el resto se queda igual (pista: CASE dentro del SET).
BEGIN;
UPDATE film f SET rental_rate =
CASE
    WHEN f.rating = 'G' THEN f.rental_rate + (f.rental_rate * 0.10)
    WHEN f.rating = 'PG' THEN f.rental_rate + (f.rental_rate * 0.05)
END
WHERE f.rating IN ('G', 'PG');
ROLLBACK;

-- 33. Actualiza el email de todos los clientes inactivos (active = 0) agregándoles
--     el sufijo '.inactivo' al final de su email actual (pista: concatenación || ).
BEGIN;
UPDATE customer c SET email = c.email || '.inactivo'
WHERE c.active = 0;
ROLLBACK;

-- ----- ELIMINACIÓN (DELETE) -----

-- 34. Elimina todas las filas de una tabla temporal de respaldo que creaste antes
--     (practica DELETE con y sin WHERE, entendiendo la diferencia con TRUNCATE).
TRUNCATE TABLE horror_backup;
DELETE FROM horror_backup;

-- 35. Elimina los registros de rental que no tienen return_date (rentas nunca
--     devueltas) PERO solo dentro de una transacción que luego harás ROLLBACK
--     (para practicar sin borrar datos reales).
SELECT * FROM rental;
BEGIN;
DELETE FROM rental r WHERE return_date IS NULL;
ROLLBACK;

-- 36. Usando DELETE con subconsulta, elimina de una tabla temporal los actores
--     que no han participado en ninguna película (pista: DELETE ... WHERE NOT EXISTS).
CREATE TEMP TABLE actor_temp AS SELECT * FROM actor;
DELETE FROM actor_temp act
WHERE act.actor_id IN (
    SELECT a.actor_id FROM actor a
    LEFT JOIN film_actor fa USING (actor_id)
    WHERE film_id IS NULL AND a.actor_id = act.actor_id
);
--Respuesta Claude Fable 5
DELETE FROM actor_temp act
WHERE NOT EXISTS (
    SELECT 1 FROM film_actor fa
    WHERE fa.actor_id = act.actor_id
);

-- ----- CONSTRAINTS Y MANEJO DE ERRORES -----

-- 37. Intenta insertar una película con un language_id que no existe (ej: 999) y
--     observa el error de foreign key. Explica qué constraint lo impide.
INSERT INTO film (title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, "length", replacement_cost, rating, special_features, fulltext)
VALUES ('100HorasConFidel', 'Vida de Fidel', 2000, 99, 99, 5, 2.99, 60, 1.0, 'G', '{Deleted Scenes,Behind_Scene}', TO_TSVECTOR('english', 'fidel'));
/*
ERROR:  insert or update on table "film" violates foreign key constraint "film_language_id_fkey"
Key (language_id)=(99) is not present in table "language".

SQL state: 23503
Detail: Key (language_id)=(99) is not present in table "language".
*/

-- 38. Intenta insertar dos categorías con el mismo nombre y observa si hay o no
--     una restricción UNIQUE. Si no la hay, agrégala con ALTER TABLE.
--La columna no tenia restriccion UNIQUE
BEGIN;
INSERT INTO category ("name") VALUES ('Action');
SELECT * FROM category;
ALTER TABLE category ADD CONSTRAINT category_name_unique UNIQUE (name);
ROLLBACK;

-- ----- CONSULTAS AVANZADAS (repaso + nuevo) -----

-- 39. Encuentra la película más rentada de cada categoría (pista: ROW_NUMBER con
--     PARTITION BY categoría, filtrar rn = 1). Combina varios temas ya vistos.
WITH film_cont_by_cat AS (
    SELECT c."name", f.title, c.category_id, COUNT(f.film_id) AS "Cont_Film"
    FROM film f
    JOIN inventory i USING (film_id)
    JOIN rental r USING (inventory_id)
    JOIN film_category fc USING (film_id)
    JOIN category c USING (category_id)
    GROUP BY c.category_id, f.film_id
),
set_ranking AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY fc.category_id ORDER BY "Cont_Film" DESC) AS ranking
    FROM film_cont_by_cat fc
)
SELECT "name", title, "Cont_Film" FROM set_ranking
WHERE "ranking" = 1;

-- 40. Para cada cliente, muestra su primera y última renta (fechas), y cuántos
--     días pasaron entre ambas (pista: MIN/MAX de rental_date, resta de fechas).
WITH max_min_date_rent AS (
    SELECT MAX(r.rental_date) AS "Ultima_Renta",
           MIN(r.rental_date) AS "Primera_Renta"
    FROM customer c
    JOIN rental r USING (customer_id)
    GROUP BY c.customer_id
)
SELECT "Primera_Renta",
       "Ultima_Renta",
       EXTRACT(DAY FROM "Ultima_Renta" - "Primera_Renta") AS "Diferencia_en_Dias"
FROM max_min_date_rent;

-- 41. Usando GENERATE_SERIES, crea una lista de los 12 meses del año y haz un
--     LEFT JOIN con los ingresos reales por mes, mostrando 0 en los meses sin datos.
WITH generate_month AS (SELECT GENERATE_SERIES(1, 12) AS "Mes")
SELECT "Mes", COALESCE(SUM(p.amount), 0) AS "Ingreso_Total" FROM generate_month gm
LEFT JOIN payment p ON gm."Mes" = EXTRACT(MONTH FROM p.payment_date)
GROUP BY "Mes"
ORDER BY "Mes";

-- 42. Lista las 5 categorías que más ingresos generan, con el total y el porcentaje
--     acumulado (running total de porcentaje, pista: SUM() OVER con ORDER BY).
WITH sum_total_by_cat AS (
    SELECT c."name", SUM(p.amount) AS "Total_x_Cat" FROM category c
    JOIN film_category fc USING (category_id)
    JOIN inventory i USING (film_id)
    JOIN rental r USING (inventory_id)
    JOIN payment p USING (rental_id)
    GROUP BY c.category_id
),
sum_total AS (
    SELECT *, SUM("Total_x_Cat") OVER () AS "Total" FROM sum_total_by_cat
),
with_percent AS (
    SELECT "name", "Total_x_Cat", ROUND(("Total_x_Cat" / "Total" * 100), 2) AS "Porcentaje_del_Total" FROM sum_total
)
SELECT *, SUM("Porcentaje_del_Total") OVER (ORDER BY "Porcentaje_del_Total" DESC) AS "Acumulado" FROM with_percent
LIMIT 5;
