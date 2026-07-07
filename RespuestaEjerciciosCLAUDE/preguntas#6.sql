
-- ============================================
-- EJERCICIOS DE PRÁCTICA - PAGILA (TANDA 4)
-- Tema principal: PL/pgSQL — FUNCIONES, PROCEDIMIENTOS, TRIGGERS
-- IMPORTANTE: los objetos creados (funciones, procedimientos, triggers)
--             persisten en tu base. Usa DROP FUNCTION / DROP PROCEDURE
--             / DROP TRIGGER para limpiar cuando termines si quieres.
-- ============================================

-- ----- FUNCIONES BÁSICAS (FUNCTION) -----

-- 43. Crea una función `precio_con_iva(precio numeric, iva numeric DEFAULT 0.16)`
--     que devuelva el precio con impuesto aplicado. Pruébala con:
--     SELECT precio_con_iva(100), precio_con_iva(100, 0.21);
create or replace function f_precio_con_iva(precio numeric,iva numeric default 0.16)
returns numeric
language plpgsql as 
$$
declare
result numeric;
begin
result := (precio * iva) + precio;
return result;
end;
$$
select precio_con_iva(100,0.20);

-- 44. Crea una función `total_rentas_cliente(id_cliente int)` que reciba un
--     customer_id y devuelva la cantidad total de rentas de ese cliente
--     (usa RETURNS int, un SELECT con COUNT dentro del cuerpo).
create or replace function f_total_rentas_cliente(id_cliente int)
returns int
language plpgsql as
$$
declare
total_rentas int;
begin
select count(*) into total_rentas from rental
where customer_id = id_cliente;
return total_rentas;
end;
$$
select total_rentas_cliente(1);

-- 45. Crea una función `resumen_cliente(id_cliente int)` que devuelva VARIAS
--     columnas: (nombre_completo text, total_rentas int, total_gastado numeric).
--     Pista: usa RETURNS TABLE (...) o RETURNS RECORD, y practica el SELECT
--     que retorna múltiples valores en una fila.
create or replace function f_resumen_cliente(id_cliente int)
returns table(
nombre_completo text,total_rentas int,total_gastado numeric
)
language plpgsql as 
$$
begin
return query
select (c.first_name || ' ' || c.last_name) as nombre_completo,
	   count(*)::int as total_rentas,
	   sum(p.amount) as total_gastado
from customer c
join rental r using(customer_id)
join payment p using(rental_id)
where c.customer_id = id_cliente
group by c.customer_id;
end;
$$
select * from resumen_cliente(1);

-- ----- FUNCIONES QUE RETORNAN CONJUNTOS (SETOF) -----

-- 46. Crea una función `peliculas_por_categoria(nombre_cat text)` que retorne
--     TODAS las películas de una categoría dada, devolviendo (film_id, title,
--     rental_rate). Pista: usa RETURNS TABLE (...) con RETURN QUERY.
create or replace function f_peliculas_por_categoria(nombre_cat text)
returns table(film_id int,tilte text,rental_rate numeric(4,2))
language plpgsql as
$$
begin
return query
	select f.film_id, f.title,f.rental_rate from film f
	join film_category fc using(film_id)
	join category c using(category_id)
	where c."name" = nombre_cat;
end;
$$
select * from peliculas_por_categoria('Horror');

-- 47. Crea una función `top_n_clientes(n int)` que devuelva los N clientes que
--     más han gastado, con (customer_id, nombre, total_gastado). Pruébala con
--     n=3, n=10.
create or replace function f_top_n_clientes(n_clientes int)
returns table(customer_id int,first_name text,total_gastado numeric(5,2))
language plpgsql as 
$$
begin
return query
	select c.customer_id,c.first_name, sum(p.amount) as total_gastado from customer c
	join payment p using(customer_id)
	group by c.customer_id
	order by total_gastado desc
	limit n_clientes;
end;
$$
select * from top_n_clientes(6);
-- ----- CONTROL DE FLUJO (IF, LOOP, VARIABLES) -----

-- 48. Crea una función `clasificar_pelicula(id_film int)` que reciba un film_id
--     y devuelva un texto: 'Corta', 'Media' o 'Larga' según su length
--     (< 60, 60-120, > 120). Usa una variable local con DECLARE y un IF/ELSIF/ELSE.
create or replace function f_clasificar_pelicula(id_film int)
returns text
language plpgsql as 
$$
declare
cat_film text;
film_length smallint;
begin
select f.length into film_length 
from film f 
where f.film_id = id_film;
if film_length < 60 then
	cat_film := 'Corta';
elsif film_length < 120 then
	cat_film := 'Media';
else cat_film := 'Larga';
end if;
return cat_film;
end;
$$
select clasificar_pelicula(1);

-- 49. Crea una función `calcular_multa(dias_retraso int, rate numeric)` que
--     calcule una multa: si dias_retraso <= 0 devuelve 0; si <= 3 devuelve
--     rate * dias_retraso; si > 3 devuelve rate * dias_retraso * 1.5 (recargo).
--     Practica CASE dentro de PL/pgSQL.

create or replace function f_calcular_multa(dias_retraso int, rate numeric)
returns numeric
language plpgsql as
$$
declare
multa numeric;
begin
case 
	when dias_retraso <= 0 then
		 multa := 0;
	when dias_retraso <= 3 then
		 multa := rate * dias_retraso;
	else multa := rate * dias_retraso * 1.5;
end case;
return multa;
end;
$$
select calcular_multa(5,0.99);

-- ----- PROCEDIMIENTOS (PROCEDURE con transacciones) -----

-- 50. Crea un procedimiento `aumentar_precios_categoria(nombre_cat text,
--     porcentaje numeric)` que suba el rental_rate de todas las películas
--     de una categoría por el porcentaje dado. Debe hacer COMMIT explícito
--     al final. Invócalo con CALL aumentar_precios_categoria('Horror', 5).
create or replace procedure p_aumentar_precios_categoria(in nombre_cat text,in porcentaje numeric)
language plpgsql as
$$
declare
begin
	update film f set rental_rate = rental_rate + (rental_rate * porcentaje)
	from film_category fc
	join category c using(category_id)
	where c."name" = nombre_cat and fc.film_id = f.film_id;
	commit;
end;
$$
call aumnetar_precios_categoria('Horror', 0.05)

-- 51. Crea un procedimiento `insertar_nuevo_alquiler(id_cliente int,
--     id_inventario int, id_staff int)` que inserte una nueva renta con
--     rental_date = now() y devuelva por RAISE NOTICE el rental_id creado.
--     Practica el uso de INTO para capturar valores de un INSERT ... RETURNING.
create or replace procedure p_insertar_nuevo_alquiler(id_cliente int,id_inventario int,id_staff int)
language plpgsql as 
$$
declare
	rental_id_new int;
begin
	insert into rental(rental_date,inventory_id,customer_id,return_date,staff_id)
	values (now(),id_inventario,id_cliente,null,id_staff) returning rental_id into rental_id_new;
	raise notice 'New Rental Created: %',rental_id_new;
end;
$$
call insertar_nuevo_alquiler(1,1,1);
-- ----- TRIGGERS -----

-- 52. Crea una tabla de auditoría `audit_film_updates` con columnas
--     (audit_id serial PK, film_id int, old_rental_rate numeric,
--     new_rental_rate numeric, modificado_en timestamp DEFAULT now()).
--     Luego crea un trigger AFTER UPDATE ON film que registre en esta tabla
--     cada vez que cambie el rental_rate. Prueba modificando una película
--     y verifica que se registró.

create temp table audit_film_updates
				(audit_id serial,film_id int,
				old_rental_rate numeric,new_rental_rate numeric,
				modificado_en timestamp default now());
--Trigger Function
create or replace function f_register_audit()
returns trigger
language plpgsql as 
$$
begin
	insert into audit_film_updates(
		film_id,
		old_rental_rate,
		new_rental_rate,
		modificado_en)
	values(
		new.film_id,
		old.rental_rate,
		new.rental_rate,
		now());
	return new;
end;
$$
--Trigger
create or replace trigger tr_audit_films_updates
after update on film
for each row
execute function f_register_audit();

-- 53. Crea un trigger BEFORE INSERT ON rental que valide que el inventory_id
--     está disponible (no tiene otra renta con return_date IS NULL).
--     Si no está disponible, use RAISE EXCEPTION para rechazar la inserción.
create or replace function f_validate_inventory()
returns trigger
language plpgsql as
$$
declare
	not_available_inventory boolean;
begin
	select exists(
		select 1 from rental r
		where r.inventory_id = new.inventory_id
		and r.return_date is null
	) into not_available_inventory;
	if not_aveilable_inventory then
		raise exception 'Inventario con id % no esta disponible', new.inventory_id;
	end if;
	return new;
end;
$$
create trigger t_validate_inventory
before insert on rental
for each row
execute function f_validate_inventory();

-- 54. Crea un trigger AFTER DELETE ON category que impida borrar una categoría
--     que tenga películas asociadas (usando RAISE EXCEPTION). Aunque la FK ya
--     protege esto, practica hacerlo desde el trigger con un mensaje personalizado.
create or replace function f_check_dependency()
returns trigger
language plpgsql as
$$
declare
has_movies boolean;
begin
select exists(
select 1 from film_category fc
where fc.category_id = old.category_id
) into has_movies;
if has_movies then
	raise exception 'No se puede eliminar la categoria %, aun contiene filmes asociados', old.category_id;
end if;
return old;
end;
$$
create trigger tr_check_dependency
before delete on category
for each row 
execute function f_check_dependency();
-- ----- MANEJO DE ERRORES (EXCEPTION) -----

-- 55. Modifica la función `total_rentas_cliente` del ejercicio 44 para que,
--     si el customer_id no existe, lance un RAISE EXCEPTION con un mensaje
--     personalizado. Practica el manejo dentro de un bloque BEGIN...EXCEPTION.
create or replace function f_total_rentas_cliente(id_cliente int)
returns int
language plpgsql
as $$
declare
    total_rentas numeric;
begin
	
	if not exists (
		select 1 from customer c
		where c.customer_id = id_cliente
	) then
	    raise exception 'El cliente con id % no existe',id_cliente;
	end if;
	select count(*) into total_rentas from customer
	    join rental using(customer_id)
	    where customer_id = id_cliente;
	    return total_rentas;
end;
$$;

-- 56. Crea una función `insertar_actor_seguro(nombre text, apellido text)` que
--     inserte un actor pero capture el error si el nombre está vacío (con
--     EXCEPTION WHEN OTHERS) y devuelva NULL en ese caso en vez de fallar.

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
	when others then
		raise notice 'Fallo Insert: %', SQLERRM;
		-- raise; funciona como re-throw;
		return null;
end;
$$

-- ----- CONSULTA Y LIMPIEZA DE OBJETOS PL/pgSQL -----

-- 57. Lista todas las funciones que creaste consultando información_schema:
--     SELECT routine_name, routine_type FROM information_schema.routines
--     WHERE routine_schema = 'public' AND routine_name LIKE 'tu_prefijo%';
--     Explora también \df en psql.
select * from information_schema.routines
where routine_schema = 'public' and 
(routine_name like 'f\_%' or
 routine_name like 'p\_%'
)
;

-- 58. Elimina TODAS las funciones, procedimientos y triggers que creaste en
--     esta tanda usando DROP FUNCTION / DROP PROCEDURE / DROP TRIGGER,
--     dejando la base limpia. Verifica con \df que solo queden las funciones
--     originales de Pagila.
drop trigger t_validate_inventory on rental;
drop function f_insertar_actor_seguro;
drop procedure p_aumentar_precios_categoria;