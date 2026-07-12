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
create or replace function contar_palabras_titulos(nombre_cat text)
returns int
language plpgsql as
$$
declare
cantidad_palabras int := 0;
fila record;
begin
for fila in select title from 
 (select f.title from category c
join film_category fc using(category_id)
join film f using(film_id)
where c."name" = nombre_cat) loop
 cantidad_palabras := cantidad_palabras + array_length(string_to_array(fila.title, ' '), 1);
end loop;
return cantidad_palabras;
end;
$$
select contar_palabras_titulos('Horror');
-- 63. Crea un procedimiento `resetear_precios(nombre_cat text)` que recorra
--     las películas de una categoría e imprima con RAISE NOTICE cada una junto
--     con su rental_rate antes de resetearlo a 2.99. Usa el mismo patrón FOR-LOOP.
create or replace procedure resetear_precios(nombr_cat text)
language plpgsql as
$$
declare
fila record;
begin
for fila in (select film_id,rental_rate,title from film f
join film_category fc using(film_id)
join category c using(category_id)
where c."name" = nombr_cat) loop
	raise notice 'Estado Filme antes del cambio: Title: % , Rental_Rate: %', fila.title,fila.rental_rate;
	update film set rental_rate = 2.99 where film_id = fila.film_id;
end loop;
end;
$$
-- ----- JSON / JSONB (TEMA NUEVO) -----

-- 64. Verifica el tipo de la columna 'settings' en la tabla store — probablemente
--     no exista. En cambio, crea una tabla temporal `cliente_metadata` con:
--     (customer_id int PRIMARY KEY, datos jsonb).
--     Inserta 3 filas con estructuras JSON como:
--     '{"telefono": "555-1234", "preferencias": {"idioma": "es", "notificar": true}, "tags": ["premium", "activo"]}'
select * from store;
create temp table cliente_metadata(customer_id int primary key,datos jsonb);
insert into cliente_metadata values(2,
'{"idioma": "es", 
"notificar": true, 
"tags": ["premium", "activo"],
"settings": {
	"dark_mode": false,
	"accept_cookies": true
}
}');
select * from cliente_metadata;

-- 65. Sobre la tabla `cliente_metadata` del ejercicio 64, prueba los operadores
--     básicos de JSONB:
--     - `datos -> 'telefono'`      (devuelve JSONB)
--     - `datos ->> 'telefono'`     (devuelve TEXT)
--     - `datos -> 'preferencias' -> 'idioma'` (navegación anidada)
--     - `datos -> 'tags' -> 0`     (índice de array)
--     Anota la diferencia entre `->` y `->>`.
select datos -> 'idioma' from cliente_metadata where customer_id = 2;
select datos -> 'settings' from cliente_metadata  where customer_id = 2; --Modo JSONB
select datos ->> 'settings' from cliente_metadata  where customer_id = 2; --Modo Text
select datos #> '{settings,dark_mode}' from  cliente_metadata  where customer_id = 2; --Modo JSONB
select datos -> 'tags' ->> 0 from  cliente_metadata  where customer_id = 2; --Array POS
select * from cliente_metadata where datos ? 'settings';

-- 66. Consulta la tabla `cliente_metadata` filtrando por contenido JSON.
--     Encuentra los clientes cuyo JSON contiene `{"preferencias": {"idioma": "es"}}`
--     usando el operador `@>` (contiene). Anota también el uso del operador `?`
--     para verificar si existe una clave: `datos ? 'telefono'`.
select * from cliente_metadata where datos @> '{"settings":{"dark_mode" : false}}';

select * from cliente_metadata where datos ? 'tags';
select * from cliente_metadata where datos ?| array['tags','notificar'];
select * from cliente_metadata where datos ?& array['tags','notificar'];

-- 67. Crea una función `agregar_tag_cliente(id_cliente int, nuevo_tag text)`
--     que modifique el array `tags` dentro del JSON de un cliente, agregando
--     un nuevo tag al final. Usa `jsonb_set` y el operador de concatenación `||`.
--     Prueba: SELECT agregar_tag_cliente(1, 'nuevo_tag');
create or replace function agregar_tag_cliente(id_cliente int,nuevo_tag text)
returns void
language plpgsql as 
$$
declare
begin
if not exists(select 1 from cliente_metadata cm 
where cm.customer_id = id_cliente) then
	raise exception 'Cliente con id % no existe' , id_cliente;
else 
	update cliente_metadata set datos = jsonb_set(
	datos,
	'{tags}',
	coalesce((datos -> 'tags'),'[]'::jsonb) || to_jsonb(ARRAY[nuevo_tag]))
	where customer_id = id_cliente;
end if;
raise notice 'Operacion completada con Exito';
end;
$$
select agregar_tag_cliente(2,'ELTANKE');

-- 68. Crea una función `stats_cliente_json(id_cliente int)` que devuelva las
--     estadísticas del cliente COMO JSON: 
--     {"customer_id": 1, "nombre": "MARY", "total_rentas": 33, "total_gastado": 118.68}
--     Usa la función `jsonb_build_object('key', value, ...)`.
create or replace function stats_cliente_json(id_cliente int)
returns json
language plpgsql as
$$
declare
json_to_return json;
begin

select jsonb_build_object('nombre',first_name,'customer_id', customer_id) into json_to_return 
from customer c 
where c.customer_id = id_cliente;
return json_to_return;
end;
$$
select stats_cliente_json(2);
-- ----- TRIGGERS AVANZADOS -----

-- 69. Crea una tabla `auditoria_precios` con:
--     (id serial PK, film_id int, cambio jsonb, fecha timestamp default now())
--     donde `cambio` guardará el before/after como JSON. Ejemplo del contenido:
--     {"antes": {"rental_rate": 2.99, "rental_duration": 5}, 
--      "despues": {"rental_rate": 3.29, "rental_duration": 6}}
--     Crea un trigger AFTER UPDATE ON film que registre estos cambios usando
--     `jsonb_build_object`. Combina PL/pgSQL + JSON.
create temp table auditoria_precios(id serial Primary Key, film_id int,cambio jsonb, fecha timestamp default now());
drop table auditoria_precios;
create or replace function f_registrar_cambios()
returns trigger
language plpgsql as
$$
declare
base_json jsonb;
begin
base_json := jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
insert into auditoria_precios(film_id,cambio)
values(new.film_id,base_json);
return new;
end;
$$

create or replace trigger tr_auditoria_precios
after update of rental_rate,rental_duration on film
for each row
execute function f_registrar_cambios();

update film set title = title || ' ' where film_id = 1;
select * from auditoria_precios;
drop trigger tr_audit_films_updates on film;
-- 70. Modifica el trigger del ejercicio 69 para que use `WHEN (OLD.rental_rate 
--     IS DISTINCT FROM NEW.rental_rate)` — que solo se dispare cuando el precio
--     realmente cambie, ignorando UPDATEs que tocan otras columnas.

create or replace trigger tr_auditoria_precios
after update on film 
for each row
when (old.rental_rate is distinct from new.rental_rate)
execute function f_registrar_cambios();

-- 71. Crea un trigger BEFORE INSERT ON rental que, si el customer_id pertenece
--     a un cliente con 'active = 0' (inactivo), rechace la renta con
--     RAISE EXCEPTION. Además, si el cliente tiene 10+ rentas sin devolver
--     (return_date IS NULL), también rechazar. Combina múltiples validaciones.
create or replace function f_check_customer()
returns trigger
language plpgsql as 
$$
declare
id_cliente int := new.customer_id;
begin
if exists(select 1 from customer c where c.customer_id = id_cliente and c.active = 0) then
	raise exception 'Usuario Inactivo'; 
end if;
if 10 <= (select count(*) from customer c
join rental r using(customer_id)
where r.return_date is null) then
	raise exception 'Devuelva Primero las anteriores Rentadas';
end if;
return new;
end;
$$

create or replace trigger tr_check_customer
before insert on rental
for each row
execute function f_check_customer();

-- ----- MANEJO DE ERRORES ESPECÍFICOS -----

-- 72. Reescribe la función `insertar_actor_seguro` del ejercicio 56 para que
--     capture errores ESPECÍFICOS por nombre en vez de solo WHEN OTHERS:
--     - WHEN unique_violation THEN devuelve -1
--     - WHEN not_null_violation THEN devuelve -2
--     - WHEN OTHERS THEN devuelve NULL (fallback)
--     Practica el manejo diferenciado según tipo de error.

create or replace function f_insertar_actor_seguro(nombre text,apellido text)
returns int
language plpgsql as
$$
declare
new_id int;
begin
if  nombre is  null or
	apellido is  null or
	length(trim(nombre)) = 0 or
	length(trim(apellido)) = 0
then
	raise exception  'Nombre o Apellidos null o vacios';
end if;
	insert into actor(first_name,last_name)
			   values(nombre,apellido) 
			   returning actor_id into new_id;
return new_id;
exception 
	when unique_violation then
		raise notice 'Se intento insertar un valor ya existente en una columna unique: Err: %',SQLERRM;
	when not_null_violation then
		raise notice 'Se intento asignar null a una columna not null: Err: % ', SQLERRM;
	when others then
		raise notice 'Fallo Insert: %', SQLERRM;
		-- raise; funciona como re-throw;
		return null;
end;
$$

-- 73. Crea un procedimiento `transferir_categoria(id_film int, nombre_nueva_cat text)`
--     que cambie la categoría de una película. Use un bloque BEGIN...EXCEPTION
--     que si algo falla (categoría inexistente, película inexistente), haga
--     RAISE NOTICE con el error y NO propague la excepción al caller.
create or replace procedure p_transferir_categoria(id_film int,nombre_nueva_cat text)
language plpgsql as
$$
declare
id_category int;
begin
	select c.category_id into id_category from category c where c."name" = nombre_nueva_cat;
	if not exists(select 1 from film where film_id = id_film) 
	then
		raise exception 'Pelicula no Existe' using errcode = 'CUH01';
	end if;
	if id_category is null 
	then
		raise exception 'Categoria no Existe' using errcode = 'CUH02';
	end if;
	update film_category fc 
	set category_id = id_category 
	where film_id = id_film;

	exception
		when SQLSTATE 'CUH01' then
			raise notice 'error: %', SQLERRM;
		when SQLSTATE 'CUH02' then
			raise notice 'error: %', SQLERRM; 
end;
$$
begin;
call p_transferir_categoria(1,'Diaz Canel Singao');
select film_id,"name" from film
join film_category using(film_id)
join category using(category_id)
order by film_id;
rollback;
-- ----- CONSULTA Y LIMPIEZA -----

-- 74. Consulta el pg_catalog para listar tus triggers activos:
--     SELECT trigger_name, event_manipulation, event_object_table
--     FROM information_schema.triggers
--     WHERE trigger_schema = 'public'
--     ORDER BY event_object_table;
--     Identifica cuáles son tuyos y cuáles son originales de Pagila.
select * from information_schema.triggers;

-- 75. Limpia todos los objetos creados en esta tanda con DROP correspondientes.
--     Verifica con \df y consultando information_schema.triggers.