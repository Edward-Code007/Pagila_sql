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
begin;
insert into actor(first_name,last_name) values('EDUARDO','GONZALEZ');
rollback;

select * from actor where first_name = 'EDUARDO';

-- 28. Inserta una nueva categoría llamada 'Indie'. Luego, inserta una película
--     nueva y asóciala a esa categoría (necesitarás INSERT en film y en film_category).
begin;
with insert_category as(
insert into category("name") values('Indie') returning category_id),
insert_film as(
insert into film(title,description,release_year,language_id,original_language_id,rental_duration,rental_rate,"length",replacement_cost,rating,special_features,fulltext)
values('100HorasConFidel','Vida de Fidel',2000,1,1,5,2.99,60,1.0,'G','{Deleted Scenes,Behind_Scene}',to_tsvector('english','fidel')) returning film_id
)
insert into film_category(film_id,category_id)
select film_id,category_id from insert_category,insert_film;
rollback;


-- 29. Inserta 3 actores de un solo golpe usando un único INSERT con múltiples filas.
begin;
insert into actor(first_name,last_name) 
values('Eduardo','Gonzalez'
),('Roymer','Yandel'),('Frank','Verazain');
rollback;

-- 30. Usa INSERT ... SELECT para crear una tabla de respaldo (backup) de todas las
--     películas de categoría 'Horror' en una tabla nueva llamada horror_backup.

create temp table horror_backup as 
(select f.title from category c 
join film_category fc using(category_id) 
join film f using(film_id) where c."name" = 'Horror'
);
drop table horror_backup;


-- ----- ACTUALIZACIÓN (UPDATE) -----

-- 31. Sube en 1 día el rental_duration de todas las películas cuya duración (length)
--     sea mayor a 120 minutos.


-- 32. Usando UPDATE con CASE, ajusta el rental_rate: las películas 'G' suben 10%,
--     las 'PG' suben 5%, y el resto se queda igual (pista: CASE dentro del SET).


-- 33. Actualiza el email de todos los clientes inactivos (active = 0) agregándoles
--     el sufijo '.inactivo' al final de su email actual (pista: concatenación || ).


-- ----- ELIMINACIÓN (DELETE) -----

-- 34. Elimina todas las filas de una tabla temporal de respaldo que creaste antes
--     (practica DELETE con y sin WHERE, entendiendo la diferencia con TRUNCATE).


-- 35. Elimina los registros de rental que no tienen return_date (rentas nunca
--     devueltas) PERO solo dentro de una transacción que luego harás ROLLBACK
--     (para practicar sin borrar datos reales).


-- 36. Usando DELETE con subconsulta, elimina de una tabla temporal los actores
--     que no han participado en ninguna película (pista: DELETE ... WHERE NOT EXISTS).


-- ----- CONSTRAINTS Y MANEJO DE ERRORES -----

-- 37. Intenta insertar una película con un language_id que no existe (ej: 999) y
--     observa el error de foreign key. Explica qué constraint lo impide.


-- 38. Intenta insertar dos categorías con el mismo nombre y observa si hay o no
--     una restricción UNIQUE. Si no la hay, agrégala con ALTER TABLE.


-- ----- CONSULTAS AVANZADAS (repaso + nuevo) -----

-- 39. Encuentra la película más rentada de cada categoría (pista: ROW_NUMBER con
--     PARTITION BY categoría, filtrar rn = 1). Combina varios temas ya vistos.


-- 40. Para cada cliente, muestra su primera y última renta (fechas), y cuántos
--     días pasaron entre ambas (pista: MIN/MAX de rental_date, resta de fechas).


-- 41. Usando GENERATE_SERIES, crea una lista de los 12 meses del año y haz un
--     LEFT JOIN con los ingresos reales por mes, mostrando 0 en los meses sin datos.


-- 42. Lista las 5 categorías que más ingresos generan, con el total y el porcentaje
--     acumulado (running total de porcentaje, pista: SUM() OVER con ORDER BY).