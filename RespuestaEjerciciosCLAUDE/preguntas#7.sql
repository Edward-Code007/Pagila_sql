-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 5)
-- Temas: PL/pgSQL avanzado (funciones, procedures, triggers)
--        + JSON/JSONB como tema nuevo
-- IMPORTANTE: los objetos creados persisten en la base.
--             Usa DROP FUNCTION/PROCEDURE/TRIGGER para limpiar.
-- ============================================

-- ----- FUNCIONES CON LÓGICA MÁS COMPLEJA -----

-- 59. Crea una función `dias_desde_ultima_renta(id_cliente int)` que devuelva
--     cuántos días han pasado desde la última renta del cliente. Si el cliente
--     nunca ha rentado, devuelve NULL. Pista: usa `MAX(rental_date)` y una resta
--     con `CURRENT_DATE` que dé un intervalo en días.
create or replace function dias_desde_ultima_renta(id_cliente int)
returns int
language plpgsql as
$$
declare
dias_desde_ultima_renta int;
begin

	select  current_date-max(r.rental_date)::date into dias_desde_ultima_renta
	from rental r
	where r.customer_id = id_cliente;
	return dias_desde_ultima_renta;
end;
$$

-- 60. Crea una función `clasificar_cliente(id_cliente int)` que retorne un texto
--     'VIP', 'Regular', o 'Nuevo' según el total gastado:
--     - VIP si gastó > $150
--     - Regular si gastó entre $50 y $150
--     - Nuevo si gastó < $50 o nunca rentó
--     Combina IF/ELSIF/ELSE con SELECT INTO. Usa el patrón "early exception"
--     si el cliente no existe.
create or replace function clasificar_cliente(id_cliente int)
returns text
language plpgsql as 
$$
declare
cantidad_gastado numeric;
begin
if not exists(
select 1 from customer
where customer_id = id_cliente
) then raise exception 'Cliente conn id % no existe',id_cliente;
end if;
select coalesce(sum(p.amount),0) into cantidad_gastado
from payment p
where customer_id = id_cliente;
if cantidad_gastado > 150 then
	return 'VIP';
elsif cantidad_gastado >= 50 then
	return 'Regular';
else return 'Nuevo';
end if;
end;
$$
select clasificar_cliente(1);

-- 61. Crea una función `estadisticas_categoria(nombre_cat text)` que retorne
--     UNA fila con: (total_peliculas int, total_rentas int, ingreso_total numeric,
--     promedio_rental_rate numeric). Usa RETURNS TABLE con las 4 columnas.
create or replace function estadisticas_categoria(nombre_cat text)
returns table(total_peliculas int,total_rentas int,total_ingreso numeric,promedio_rental_rate numeric)
language plpgsql as
$$
declare
begin
RETURN QUERY
WITH peliculas_cat AS (
    SELECT f.film_id, f.rental_rate FROM film f
    JOIN film_category fc USING(film_id)
    JOIN category c USING(category_id)
    WHERE c.name = nombre_cat
),
rentas_cat AS (
    SELECT r.rental_id FROM rental r
    JOIN inventory i USING(inventory_id)
    WHERE i.film_id IN (SELECT film_id FROM peliculas_cat)
),
ingresos_cat AS (
    SELECT sum(p.amount) AS total FROM payment p
    WHERE p.rental_id IN (SELECT rental_id FROM rentas_cat)
)
SELECT 
    (SELECT count(*)::int FROM peliculas_cat),
    (SELECT count(*)::int FROM rentas_cat),
    (SELECT total FROM ingresos_cat),
    (SELECT avg(rental_rate)::numeric(4,2) FROM peliculas_cat);
end;
$$
select * from estadisticas_categoria('Horror');
-- ----- LOOPS Y CURSORES (nuevo concepto) -----

-- 62. Crea una función `contar_palabras_titulos(nombre_cat text)` que devuelva
--     el total de palabras (contando espacios + 1) en TODOS los títulos de una
--     categoría. Usa un LOOP con FOR ... IN SELECT ... para iterar sobre las
--     filas. Pista: la sintaxis es:
--     FOR fila IN SELECT ... FROM ... LOOP ... END LOOP;


-- 63. Crea un procedimiento `resetear_precios(nombre_cat text)` que recorra
--     las películas de una categoría e imprima con RAISE NOTICE cada una junto
--     con su rental_rate antes de resetearlo a 2.99. Usa el mismo patrón FOR-LOOP.

-- ----- JSON / JSONB (TEMA NUEVO) -----

-- 64. Verifica el tipo de la columna 'settings' en la tabla store — probablemente
--     no exista. En cambio, crea una tabla temporal `cliente_metadata` con:
--     (customer_id int PRIMARY KEY, datos jsonb).
--     Inserta 3 filas con estructuras JSON como:
--     '{"telefono": "555-1234", "preferencias": {"idioma": "es", "notificar": true}, "tags": ["premium", "activo"]}'


-- 65. Sobre la tabla `cliente_metadata` del ejercicio 64, prueba los operadores
--     básicos de JSONB:
--     - `datos -> 'telefono'`      (devuelve JSONB)
--     - `datos ->> 'telefono'`     (devuelve TEXT)
--     - `datos -> 'preferencias' -> 'idioma'` (navegación anidada)
--     - `datos -> 'tags' -> 0`     (índice de array)
--     Anota la diferencia entre `->` y `->>`.


-- 66. Consulta la tabla `cliente_metadata` filtrando por contenido JSON.
--     Encuentra los clientes cuyo JSON contiene `{"preferencias": {"idioma": "es"}}`
--     usando el operador `@>` (contiene). Anota también el uso del operador `?`
--     para verificar si existe una clave: `datos ? 'telefono'`.


-- 67. Crea una función `agregar_tag_cliente(id_cliente int, nuevo_tag text)`
--     que modifique el array `tags` dentro del JSON de un cliente, agregando
--     un nuevo tag al final. Usa `jsonb_set` y el operador de concatenación `||`.
--     Prueba: SELECT agregar_tag_cliente(1, 'nuevo_tag');


-- 68. Crea una función `stats_cliente_json(id_cliente int)` que devuelva las
--     estadísticas del cliente COMO JSON: 
--     {"customer_id": 1, "nombre": "MARY", "total_rentas": 33, "total_gastado": 118.68}
--     Usa la función `jsonb_build_object('key', value, ...)`.


-- ----- TRIGGERS AVANZADOS -----

-- 69. Crea una tabla `auditoria_precios` con:
--     (id serial PK, film_id int, cambio jsonb, fecha timestamp default now())
--     donde `cambio` guardará el before/after como JSON. Ejemplo del contenido:
--     {"antes": {"rental_rate": 2.99, "rental_duration": 5}, 
--      "despues": {"rental_rate": 3.29, "rental_duration": 6}}
--     Crea un trigger AFTER UPDATE ON film que registre estos cambios usando
--     `jsonb_build_object`. Combina PL/pgSQL + JSON.


-- 70. Modifica el trigger del ejercicio 69 para que use `WHEN (OLD.rental_rate 
--     IS DISTINCT FROM NEW.rental_rate)` — que solo se dispare cuando el precio
--     realmente cambie, ignorando UPDATEs que tocan otras columnas.


-- 71. Crea un trigger BEFORE INSERT ON rental que, si el customer_id pertenece
--     a un cliente con 'active = 0' (inactivo), rechace la renta con
--     RAISE EXCEPTION. Además, si el cliente tiene 10+ rentas sin devolver
--     (return_date IS NULL), también rechazar. Combina múltiples validaciones.


-- ----- MANEJO DE ERRORES ESPECÍFICOS -----

-- 72. Reescribe la función `insertar_actor_seguro` del ejercicio 56 para que
--     capture errores ESPECÍFICOS por nombre en vez de solo WHEN OTHERS:
--     - WHEN unique_violation THEN devuelve -1
--     - WHEN not_null_violation THEN devuelve -2
--     - WHEN OTHERS THEN devuelve NULL (fallback)
--     Practica el manejo diferenciado según tipo de error.


-- 73. Crea un procedimiento `transferir_categoria(id_film int, nombre_nueva_cat text)`
--     que cambie la categoría de una película. Use un bloque BEGIN...EXCEPTION
--     que si algo falla (categoría inexistente, película inexistente), haga
--     RAISE NOTICE con el error y NO propague la excepción al caller.

-- ----- CONSULTA Y LIMPIEZA -----

-- 74. Consulta el pg_catalog para listar tus triggers activos:
--     SELECT trigger_name, event_manipulation, event_object_table
--     FROM information_schema.triggers
--     WHERE trigger_schema = 'public'
--     ORDER BY event_object_table;
--     Identifica cuáles son tuyos y cuáles son originales de Pagila.


-- 75. Limpia todos los objetos creados en esta tanda con DROP correspondientes.
--     Verifica con \df y consultando information_schema.triggers.