# Pagila — Ejercicios SQL con PostgreSQL

## Origen del proyecto

Este repositorio está basado en **Pagila**, una adaptación para PostgreSQL de la base de datos de ejemplo [Sakila](https://dev.mysql.com/doc/sakila/en/) originalmente desarrollada por Mike Hillyer del equipo de documentación de MySQL AB.

El proyecto original de Pagila fue creado y mantenido por [Devrim Gündüz](https://github.com/devrimgunduz/pagila) y porta todas las tablas, datos, vistas y funciones de Sakila a PostgreSQL, añadiendo mejoras propias del motor como soporte JSONB, búsqueda fulltext nativa, particionado de tablas y triggers para `last_update`.

## Objetivo

El objetivo de este repositorio es **practicar y demostrar conocimientos de SQL con PostgreSQL** usando Pagila como base de datos de ejemplo. Se realizan ejercicios de consulta que cubren:

- Filtrado y ordenamiento (`WHERE`, `ORDER BY`, `LIMIT`)
- Joins entre tablas (`INNER JOIN`, `LEFT JOIN`)
- Agrupaciones y agregaciones (`GROUP BY`, `COUNT`, `SUM`, `AVG`)
- Subconsultas y CTEs
- Búsqueda fulltext nativa de PostgreSQL
- Consultas sobre columnas JSONB
- Funciones de ventana (`OVER`, `PARTITION BY`)

Las respuestas a los ejercicios se encuentran en la carpeta [`RespuestaEjerciciosCLAUDE/`](./RespuestaEjerciciosCLAUDE/).

## Esquema de la base de datos

![Diagrama del esquema](pagila-schema-diagram.png)

La base de datos simula una cadena de alquiler de películas con las siguientes tablas principales:

| Tabla | Descripción |
|---|---|
| `film` | Catálogo de películas |
| `actor` | Actores y su relación con películas |
| `customer` | Clientes registrados |
| `rental` | Registros de alquileres |
| `payment` | Pagos realizados (tabla particionada) |
| `inventory` | Inventario de copias por tienda |
| `store` / `staff` | Tiendas y personal |
| `address` / `city` / `country` | Datos geográficos |

## Preparar el entorno para ejecutar los scripts

### 1. Levantar la base de datos

El `docker-compose.yml` incluido levanta PostgreSQL 17 y carga automáticamente el esquema, los datos y los datos JSONB. Solo hace falta un comando:

```bash
docker-compose up -d
```

Esto hace en orden:
1. Crea la base de datos `postgres` (base por defecto)
2. Aplica `pagila-schema.sql` + `pagila-schema-jsonb.sql`
3. Carga `pagila-data.sql`
4. Restaura los backups JSONB (`pagila-data-apt-jsonb.backup` y `pagila-data-yum-jsonb.backup`)

> La primera vez tarda un par de minutos mientras carga todos los datos. Los siguientes `docker-compose up` usan el volumen persistente y arrancan en segundos.

### 2. Credenciales de conexión

| Parámetro | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5432` |
| Usuario | `postgres` |
| Contraseña | `123456` |
| Base de datos | `postgres` |

### 3. Ejecutar los scripts desde consola

```bash
# Conectarse al contenedor
docker exec -it pagila psql -U postgres

# Ejecutar un script directamente
docker exec -i pagila psql -U postgres -f /ruta/al/script.sql

# O desde fuera del contenedor apuntando al host
psql -h localhost -U postgres -d postgres -f RespuestaEjerciciosCLAUDE/preguntas\#1.sql
```

### 4. Ejecutar los scripts desde pgAdmin

pgAdmin está incluido en el docker-compose. Acceder en [http://localhost:5050](http://localhost:5050):

| Campo | Valor |
|---|---|
| Usuario | `admin@admin.com` |
| Contraseña | `root` |

El servidor `pagila` ya aparece preconfigurado. Abrir **Query Tool** sobre la base de datos `postgres` y pegar o abrir cualquier script de `RespuestaEjerciciosCLAUDE/`.

### 5. Verificar que los datos están cargados

```sql
-- Debe retornar 21 tablas
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Verificación rápida de datos
SELECT COUNT(*) FROM film;      -- 1000 películas
SELECT COUNT(*) FROM customer;  -- 599 clientes
SELECT COUNT(*) FROM rental;    -- 16044 registros
```

## Ejemplo de consulta

Rentas vencidas sin devolución:

```sql
SELECT
    CONCAT(customer.last_name, ', ', customer.first_name) AS cliente,
    address.phone,
    film.title
FROM rental
    INNER JOIN customer  ON rental.customer_id  = customer.customer_id
    INNER JOIN address   ON customer.address_id = address.address_id
    INNER JOIN inventory ON rental.inventory_id = inventory.inventory_id
    INNER JOIN film      ON inventory.film_id   = film.film_id
WHERE
    rental.return_date IS NULL
    AND rental_date < CURRENT_DATE
ORDER BY title
LIMIT 5;
```

## Búsqueda fulltext

```sql
SELECT * FROM film WHERE fulltext @@ to_tsquery('fate&india');
```

## Licencia

La base de datos Pagila está disponible bajo la [licencia de PostgreSQL](./LICENSE.txt).
