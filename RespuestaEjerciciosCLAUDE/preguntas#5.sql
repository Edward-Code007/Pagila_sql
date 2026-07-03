-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 4)
-- Tema principal: ÍNDICES Y OPTIMIZACIÓN
-- Herramientas: EXPLAIN, EXPLAIN ANALYZE, CREATE INDEX
-- IMPORTANTE: los índices creados quedan permanentes
--             a menos que uses DROP INDEX
-- ============================================

-- ----- DIAGNÓSTICO CON EXPLAIN -----

-- 43. Ejecuta EXPLAIN sobre una consulta que filtre customer por last_name = 'SMITH'.
--     Identifica en el plan: ¿qué tipo de scan usa? ¿tiene índice o hace Seq Scan?
--     Anota el costo estimado y el número estimado de filas.


-- 44. Compara EXPLAIN vs EXPLAIN ANALYZE sobre la misma consulta del ejercicio 43.
--     Observa la diferencia entre las filas estimadas y las filas reales,
--     y anota el tiempo real de ejecución (Execution Time).


-- 45. Ejecuta EXPLAIN ANALYZE sobre una consulta que haga JOIN de customer,
--     rental y payment filtrando por un customer_id específico. Identifica
--     qué tipos de JOIN eligió el planner (Hash Join, Nested Loop, Merge Join)
--     y por qué crees que eligió cada uno.


-- ----- CREACIÓN DE ÍNDICES B-TREE -----

-- 46. Crea un índice B-tree simple sobre customer.last_name. Antes y después,
--     ejecuta EXPLAIN ANALYZE sobre una búsqueda por apellido y compara
--     el tipo de scan (Seq Scan → Index Scan) y el tiempo de ejecución.


-- 47. Crea un índice compuesto sobre (customer.store_id, customer.active).
--     Prueba tres consultas: (a) filtrando por ambas columnas, (b) solo
--     store_id, (c) solo active. ¿En cuáles se usa el índice? Explica por qué
--     (pista: el orden de las columnas importa — regla del "prefijo izquierdo").


-- 48. Crea un índice parcial (partial index) que solo incluya customer.email
--     de los clientes activos (active = 1). Compara el tamaño del índice
--     parcial vs un índice completo sobre email con la consulta:
--     SELECT pg_size_pretty(pg_relation_size('nombre_del_indice'));


-- ----- SARGABILITY (funciones sobre columnas indexadas) -----

-- 49. Con el índice de last_name creado en el 46, prueba EXPLAIN sobre:
--     (a) WHERE last_name = 'SMITH'
--     (b) WHERE LOWER(last_name) = 'smith'
--     (c) WHERE last_name LIKE 'SMI%'
--     (d) WHERE last_name LIKE '%MITH'
--     Identifica cuáles usan el índice y cuáles NO (y por qué).


-- 50. Crea un índice funcional (expression index) sobre LOWER(last_name)
--     para que la búsqueda case-insensitive del ejercicio 49-b sí use índice.
--     Verifica con EXPLAIN que ahora sí lo usa.


-- ----- ÍNDICES GIN PARA BÚSQUEDA AVANZADA -----

-- 51. La tabla film ya tiene una columna 'fulltext' de tipo tsvector.
--     Ejecuta EXPLAIN sobre: SELECT * FROM film WHERE fulltext @@ to_tsquery('astronaut')
--     ¿Usa índice? Si no, crea un índice GIN sobre esa columna y compara.


-- 52. Crea un índice GIN sobre la columna array film.special_features y prueba
--     una consulta: WHERE 'Trailers' = ANY(special_features). Compara antes y
--     después del índice.


-- ----- OPTIMIZACIÓN DE CONSULTAS REALES -----

-- 53. Toma tu query del ejercicio 39 (película más rentada por categoría) y
--     ejecuta EXPLAIN ANALYZE. Identifica el nodo más costoso. ¿Podrías
--     agregar algún índice que ayude? Prueba tu hipótesis y mide la mejora.


-- 54. Escribe DOS versiones de la misma consulta: "clientes que han rentado
--     películas de la categoría 'Horror'":
--     Versión A: usando JOIN a category
--     Versión B: usando WHERE customer_id IN (subconsulta con Horror)
--     Compara los planes de EXPLAIN ANALYZE. ¿Cuál es más eficiente y por qué?


-- 55. Considera esta consulta con función sobre columna:
--     WHERE EXTRACT(YEAR FROM payment_date) = 2022
--     Reescríbela de forma SARGable (usando rangos de fecha) y compara los
--     planes. ¿Cuál permite usar índices? (pista: BETWEEN o >= AND <)


-- ----- MANTENIMIENTO Y ESTADÍSTICAS -----

-- 56. Ejecuta ANALYZE sobre la tabla customer y luego consulta
--     pg_stats para ver las estadísticas que el planner usa:
--     SELECT * FROM pg_stats WHERE tablename = 'customer';
--     Explica qué campos como n_distinct y most_common_vals significan.


-- 57. Lista todos los índices existentes en la tabla film con:
--     SELECT * FROM pg_indexes WHERE tablename = 'film';
--     Identifica cuáles vienen de constraints (PK, FK, UNIQUE) y cuáles
--     fueron creados manualmente por ti en los ejercicios anteriores.


-- ----- LIMPIEZA -----

-- 58. Elimina los índices que creaste en esta tanda usando DROP INDEX,
--     dejando la base como estaba (excepto los índices originales de Pagila).
--     Verifica con \d nombre_tabla que solo queden los originales.