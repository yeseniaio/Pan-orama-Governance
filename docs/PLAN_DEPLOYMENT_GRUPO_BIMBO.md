# Dashboard Governance — Plan de Deployment para Grupo Bimbo

| | |
|---|---|
| **Entregable** | Dashboard Governance (AI/BI dashboard) empaquetado como Declarative Automation Bundle (DAB) |
| **MVP entregado por** | Yesenia Alejandro — Delivery Solutions Architect |
| **Deployment y operación** | Client Owner — Grupo Bimbo |
| **Ambiente MVP** | `fevm-serverless-stable-ga965x` (target `fevm`) — ambiente de demostración de Databricks |
| **Ambientes del cliente** | targets `bimbo_dev` y `bimbo_prod` en `databricks.yml` |
| **Fuente de datos** | System tables de Unity Catalog (`system.access.audit`, `system.query.history`, `system.billing.*`, `system.access.workspaces_latest`) |

---

## 1. Alcance

**Incluido en el MVP**
- Dashboard con 5 páginas: Overview, Usage & Adoption, Access & Permissions, Errors & Reliability, Audit Trail.
- Global filter `Lookback (days)`, con default de 7 días.
- Un bundle con targets `fevm` (MVP), `bimbo_dev` y `bimbo_prod`.
- Documentación, smoke tests (`tests/smoke_tests.sql`) y una sesión de knowledge transfer.

**Fuera del alcance del MVP**, a cargo del cliente o para una fase 2
- Configurar el CI/CD pipeline en la herramienta de Grupo Bimbo (Azure DevOps o GitHub).
- Crear los grupos en Entra ID y el SCIM provisioning.
- Construir los charts adicionales de la sección 8 (están definidos, pero no implementados).
- Operar el dashboard después del go-live.

---

## 2. Definiciones requeridas (checklist para el cliente)

Hay que llenar esta tabla antes de empezar la Fase 1. Cada valor se traslada a `databricks.yml` o a la configuración del CI/CD.

### 2.1 Account y workspaces

| ID | Definición | Valor Grupo Bimbo | Responsable |
|---|---|---|---|
| D-01 | Cloud / región del Databricks account | ☐ Azure / AWS — región: ____ | Client Owner |
| D-02 | Account ID de Databricks | ____ | Account Admin |
| D-03 | Metastore ID (Unity Catalog) del workspace de deployment | ____ | Metastore Admin |
| D-04 | Workspace URL para dev/test | `https://____` → `bimbo_dev.workspace.host` | Workspace Admin |
| D-05 | Workspace URL para prod (puede ser el mismo que dev) | `https://____` → `bimbo_prod.workspace.host` | Workspace Admin |
| D-06 | Alcance del reporte: todos los workspaces del account o solo algunos | ☐ Todos ☐ Lista: ____ | Client Owner |
| D-07 | Folder donde se publica el dashboard | `/Workspace/Shared/Governance/` | Workspace Admin |
| D-08 | Folder raíz del bundle en prod | `/Workspace/Shared/.bundle/dashboard_governance/bimbo_prod` | Platform Engineer |

> Las system tables muestran datos de todo el account, pero solo se pueden consultar desde un workspace con Unity Catalog habilitado. Basta con un workspace de deployment para ver todos los workspaces del account (sujeto a D-06).

### 2.2 Compute (SQL warehouse)

| ID | Definición | Valor recomendado | Responsable |
|---|---|---|---|
| D-09 | Nombre del warehouse en dev | `wh-gb-governance-dev` → `lookup.warehouse` | Workspace Admin |
| D-10 | Nombre del warehouse en prod | `wh-gb-governance-prod` | Workspace Admin |
| D-11 | Tipo / tamaño | Serverless, 2X-Small, auto-stop de 10 min, max clusters 1–2 | Platform Engineer |
| D-12 | Tags de costo | `project=dashboard-governance`, `owner=<area>` | Client Owner |
| D-13 | Permiso `CAN_USE` en el warehouse | SP de deployment + Developers (+ Consumers solo si `embed_credentials: false`) | Workspace Admin |

### 2.3 Data access (Unity Catalog)

| ID | Definición | Detalle | Responsable |
|---|---|---|---|
| D-14 | System schemas habilitados | `access` (requerido); `query` y `billing` (para los charts adicionales) | Account Admin |
| D-15 | Grants sobre system tables | Ver la sección 5.3 | Metastore Admin |
| D-16 | Validar los `action_name` en el account del cliente | Ejecutar el smoke test T-04 | Platform Engineer |
| D-17 | Retención requerida | El audit log conserva unos 365 días; el dashboard usa hasta 90 | Client Owner |
| D-18 | Dominio corporativo de email (para el chart de accesos externos) | `@grupobimbo.com` u otros: ____ | Security |

### 2.4 Identidades y seguridad

| ID | Definición | Valor recomendado | Responsable |
|---|---|---|---|
| D-19 | Convención de nombres de los grupos de AD | `GB-DBX-DashGov-<Rol>` (ver la sección 4) | Identity Admin |
| D-20 | Método de sincronización Entra ID → Databricks | SCIM provisioning a nivel account o Automatic Identity Management | Identity Admin |
| D-21 | Service principal para CI/CD | `sp-gb-dbx-dashgov-cicd` (Entra ID managed) | Identity Admin |
| D-22 | Autenticación del CI/CD | OAuth M2M (client secret) o Workload Identity Federation (OIDC) | Platform Engineer |
| D-23 | `embed_credentials` | **true** (recomendado): los queries corren con la identidad del publisher y los consumers no necesitan grants. **false**: cada viewer necesita `SELECT` | Client Owner + Security |
| D-24 | ¿Los consumers pueden ver emails y mensajes de error? | ☐ Sí ☐ No → hay que enmascarar o agregar los datos | Security |
| D-25 | ¿Algún viewer debe ver solo su propio workspace? | ☐ No ☐ Sí → se requiere una view con row filter | Security |

### 2.5 Entrega y operación

| ID | Definición | Valor | Responsable |
|---|---|---|---|
| D-26 | Repositorio Git | `____/dashboard-governance` | Platform Engineer |
| D-27 | Branching | `feature/*` → PR → `main`; prod solo se despliega desde `main` | Platform Engineer |
| D-28 | Herramienta de CI/CD | ☐ Azure DevOps ☐ GitHub Actions ☐ Otra | Platform Engineer |
| D-29 | Refresh schedule y subscriptions | p. ej. diario a las 07:00 CST a `GB-DBX-DashGov-Consumers` | Client Owner |
| D-30 | Default de `lookback_days` en prod | 30 (el MVP usa 7) | Client Owner |
| D-31 | Idioma de títulos y labels | ☐ Español ☐ Inglés | Client Owner |
| D-32 | Owner del dashboard en prod (debe ser el SP, no una persona) | `sp-gb-dbx-dashgov-cicd` | Client Owner |

---

## 3. Roles

| Rol | Persona / área | Organización |
|---|---|---|
| **MVP Delivery Lead** | Yesenia Alejandro (Delivery Solutions Architect) | Databricks |
| **Client Owner** | Líder de Data Platform / Data Governance — *nombre: ____* | Grupo Bimbo |
| **Databricks Account Admin** | *nombre: ____* | Grupo Bimbo |
| **Metastore Admin** | *nombre: ____* | Grupo Bimbo |
| **Workspace Admin** | *nombre: ____* | Grupo Bimbo |
| **Identity Admin (Entra ID)** | Equipo de IAM / Directorio — *nombre: ____* | Grupo Bimbo |
| **Platform / DevOps Engineer** | Responsable del CI/CD y del repo — *nombre: ____* | Grupo Bimbo |
| **Security & Compliance** | Seguridad de la información — *nombre: ____* | Grupo Bimbo |
| **Business Consumers** | Governance, Auditoría, BI CoE | Grupo Bimbo |

---

## 4. Grupos de AD (Entra ID) y usuarios

Los grupos se crean en Entra ID, se sincronizan **a nivel account** (SCIM) y se asignan al workspace de deployment. No deben crearse como grupos locales del workspace.

| Grupo de AD | Propósito | Miembros típicos | Permiso en el dashboard (dev / prod) | Otros permisos |
|---|---|---|---|---|
| `GB-DBX-DashGov-Admins` | Owners funcionales; aprueban cambios | Client Owner, Workspace Admin | — / `CAN_MANAGE` | `CAN_MANAGE` en el folder del bundle en prod |
| `GB-DBX-DashGov-Developers` | Mantienen el bundle y los queries | Data/Platform engineers | `CAN_MANAGE` / `CAN_READ` | `SELECT` en las system tables, `CAN_USE` en el warehouse de dev, `CAN_VIEW` en el folder de prod |
| `GB-DBX-DashGov-Consumers` | Usan el dashboard | Governance, BI CoE, auditoría, seguridad | `CAN_READ` (UAT) / `CAN_READ` | Ninguno, si `embed_credentials: true` |
| `sp-gb-dbx-dashgov-cicd` *(service principal)* | Deploy a prod y owner del dashboard | — | — / owner | `SELECT` en las system tables, `CAN_USE` en el warehouse de prod, workspace access |

**Usuarios de prueba para UAT**, uno por rol:

| Usuario | Grupo | Qué debe validar |
|---|---|---|
| `qa.admin@grupobimbo.com` | Admins | Puede editar, compartir y publicar |
| `qa.dev@grupobimbo.com` | Developers | Puede hacer deploy a `bimbo_dev`; en prod solo puede ver |
| `qa.consumer@grupobimbo.com` | Consumers | Ve datos sin tener grants propios; no puede editar |
| `qa.noaccess@grupobimbo.com` | *(ninguno)* | No ve el dashboard |

Los nombres de grupo son variables del bundle (`admins_group`, `developers_group`, `consumers_group`). Si Grupo Bimbo usa otra convención, se cambian en `databricks.yml` o con `--var`.

---

## 5. Proceso de deployment (orden de ejecución)

### Fase 0 — MVP (Databricks) ✅ / en curso
1. Construir el dashboard y el bundle en `fevm` (`databricks bundle deploy -t fevm`).
2. Validar los `action_name` reales y que todos los widgets muestren datos.
3. Hacer la demo con el Client Owner y recibir feedback.
4. Entregar el bundle (repo o zip), este documento y `tests/smoke_tests.sql`.
5. Dar la sesión de knowledge transfer al Platform Engineer y al Client Owner.

**Criterio de salida:** el Client Owner aprueba el MVP y la checklist de la sección 2 está asignada.

### Fase 1 — Preparación del ambiente del cliente
1. **Account Admin:** habilitar los system schemas.
   ```bash
   databricks system-schemas list   <metastore-id>
   databricks system-schemas enable <metastore-id> access
   databricks system-schemas enable <metastore-id> query     # charts adicionales
   databricks system-schemas enable <metastore-id> billing   # charts adicionales
   ```
2. **Identity Admin:** crear los grupos de la sección 4 en Entra ID y el service principal; sincronizarlos al account (SCIM).
3. **Account Admin:** asignar los grupos y el SP al workspace de deployment (workspace assignment).
4. **Workspace Admin:** crear el SQL warehouse (D-09/D-10) y dar `CAN_USE` según D-13.
5. **Metastore Admin:** ejecutar los grants de la sección 5.3.
6. **Platform Engineer:** crear el repo Git, cargar el bundle y añadir `.databricks/` a `.gitignore`.

**Criterio de salida:** el smoke test T-01 (acceso) pasa con el SP y con un developer.

### Fase 2 — Configuración del bundle
1. Reemplazar los placeholders en `databricks.yml`:
   - `bimbo_dev.workspace.host` y `bimbo_prod.workspace.host`
   - `REPLACE_WITH_BIMBO_*_WAREHOUSE_NAME`
   - los nombres de grupo, si son distintos
2. Ajustar el default de `lookback_days` (D-30) y el idioma (D-31).
3. Aplicar el alcance de workspaces (D-06) y las decisiones de seguridad (D-23 a D-25).
4. Abrir un PR con estos cambios; lo aprueba el Client Owner.

### Fase 3 — Deploy y pruebas en `bimbo_dev`
```bash
databricks auth login --host https://<bimbo-dev-workspace> --profile bimbo-dev
databricks bundle validate -t bimbo_dev --profile bimbo-dev
databricks bundle deploy   -t bimbo_dev --profile bimbo-dev
databricks bundle summary  -t bimbo_dev --profile bimbo-dev   # URL del dashboard
```
Después, ejecutar los smoke tests T-01 a T-10 de la sección 6.

**Criterio de salida:** todos los tests P1 pasan y no hay widgets vacíos sin justificación.

### Fase 4 — UAT con consumers
1. Agregar a los usuarios de UAT a `GB-DBX-DashGov-Consumers`.
2. Ejecutar los tests de permisos (T-07, T-08) con cada usuario de prueba.
3. Validar las cifras: comparar una muestra de eventos con lo esperado (T-06).
4. Recoger feedback de contenido y priorizar los charts de la sección 8.

**Criterio de salida:** el Client Owner firma el UAT.

### Fase 5 — Deploy a `bimbo_prod` (CI/CD)
1. Hacer merge a `main`.
2. El pipeline ejecuta, autenticado como `sp-gb-dbx-dashgov-cicd`:
   ```bash
   databricks bundle validate -t bimbo_prod
   databricks bundle deploy   -t bimbo_prod
   ```
   Variables de entorno: `DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET` (o OIDC).
3. Publicar el dashboard (`embed_credentials` según D-23).
4. Configurar el refresh schedule y las subscriptions (D-29).
5. Ejecutar un smoke test rápido en prod (T-02, T-07).

### Fase 6 — Operación (hypercare de 2 semanas, luego BAU)
- Cualquier cambio se hace en dev (UI) y luego `databricks bundle generate dashboard --resource dashboard_governance --force -t bimbo_dev`, seguido de un PR. **No se edita directamente en prod**, porque el siguiente deploy sobrescribe los cambios.
- Revisar el costo del warehouse cada mes (chart N-09).
- Revisar trimestralmente la membresía de los grupos.

### 5.3 Grants requeridos (Metastore Admin)
```sql
-- Para cada <principal>: sp-gb-dbx-dashgov-cicd, GB-DBX-DashGov-Developers
-- (y GB-DBX-DashGov-Consumers solo si embed_credentials = false)
GRANT USE CATALOG ON CATALOG system                     TO `<principal>`;
GRANT USE SCHEMA  ON SCHEMA  system.access              TO `<principal>`;
GRANT SELECT      ON TABLE   system.access.audit        TO `<principal>`;
-- Para los charts adicionales (sección 8):
GRANT SELECT      ON TABLE   system.access.workspaces_latest TO `<principal>`;
GRANT USE SCHEMA  ON SCHEMA  system.query               TO `<principal>`;
GRANT SELECT      ON TABLE   system.query.history       TO `<principal>`;
GRANT USE SCHEMA  ON SCHEMA  system.billing             TO `<principal>`;
GRANT SELECT      ON TABLE   system.billing.usage       TO `<principal>`;
GRANT SELECT      ON TABLE   system.billing.list_prices TO `<principal>`;
```

---

## 6. Plan de pruebas (ambiente del cliente)

Los queries de soporte están en `tests/smoke_tests.sql`.

| ID | Prioridad | Prueba | Cómo | Resultado esperado |
|---|---|---|---|---|
| T-01 | P1 | Acceso a las system tables | Query T-01 como el SP y como un developer | Devuelve filas, sin `PERMISSION_DENIED` |
| T-02 | P1 | Bundle validate / deploy | `bundle validate` y `deploy -t bimbo_dev` | `Validation OK!` y el dashboard creado |
| T-03 | P1 | Idempotencia | Repetir `bundle deploy` sin cambios | No hay errores ni dashboards duplicados |
| T-04 | P1 | `action_name` reales | Query T-04 | Aparecen `getDashboard`, `getPublishedDashboard`, `createDashboard`, `trashDashboard`, etc. |
| T-05 | P1 | Cada dataset devuelve datos | Query T-05 y revisión visual de cada página | Ningún widget vacío sin explicación |
| T-06 | P2 | Reconciliación de cifras | Comparar el counter "Dashboard Inventory" con el query T-06 | Las cifras coinciden |
| T-07 | P1 | Permiso de consumer | Entrar como `qa.consumer` | Ve los datos y no tiene opción de editar |
| T-08 | P1 | Usuario sin acceso | Entrar como `qa.noaccess` | No ve el dashboard |
| T-09 | P2 | Global filter | Cambiar `Lookback (days)` a 7, 30 y 90 | Todos los widgets se recalculan |
| T-10 | P2 | Performance | Abrir el dashboard con lookback de 90 días | Cada página carga en menos de 10 s con el warehouse ya encendido |
| T-11 | P2 | `bundle destroy` en dev | `databricks bundle destroy -t bimbo_dev` | Se eliminan los recursos de dev |
| T-12 | P3 | Subscriptions | Programar un envío a Consumers | Llega el email con el snapshot |

---

## 7. Matriz RACI

**R** = Responsible (ejecuta) · **A** = Accountable (aprueba y responde) · **C** = Consulted · **I** = Informed

| # | Actividad | Yesenia (DSA) | Client Owner | Account Admin | Metastore Admin | Workspace Admin | Identity Admin | Platform / DevOps | Security | Consumers |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Construir el MVP (dashboard + bundle) en `fevm` | **A/R** | C | – | – | – | – | I | – | I |
| 2 | Demo y aprobación del MVP | R | **A** | – | – | – | – | I | C | C |
| 3 | Documentación, smoke tests y knowledge transfer | **A/R** | C | – | – | – | – | C | – | – |
| 4 | Llenar la checklist de definiciones (sección 2) | C | **A** | R | R | R | R | R | R | – |
| 5 | Habilitar los system schemas | C | A | **R** | I | – | – | – | – | – |
| 6 | Crear grupos de AD y SP; SCIM | C | A | C | – | – | **R** | I | C | – |
| 7 | Asignar grupos y SP al workspace | C | A | **R** | – | C | C | – | – | – |
| 8 | Crear el SQL warehouse y dar `CAN_USE` | C | A | – | – | **R** | – | C | – | – |
| 9 | Grants en las system tables | C | A | – | **R** | – | – | – | C | – |
| 10 | Decidir `embed_credentials` y exposición de PII | C | **A** | – | C | – | – | – | **R** | I |
| 11 | Crear el repo Git y el CI/CD pipeline | C | A | – | – | – | – | **R** | I | – |
| 12 | Configurar `databricks.yml` (hosts, warehouse, grupos) | C | A | – | – | C | – | **R** | – | – |
| 13 | Deploy y smoke tests en `bimbo_dev` | C | **A** | – | – | I | – | **R** | – | – |
| 14 | UAT (permisos y cifras) | C | **A** | – | – | – | – | R | C | **R** |
| 15 | Aprobar el go-live | I | **A/R** | I | I | I | – | C | C | I |
| 16 | Deploy a `bimbo_prod` vía CI/CD | I | A | – | – | I | – | **R** | – | I |
| 17 | Publicar y configurar schedules y subscriptions | C | **A** | – | – | – | – | R | – | I |
| 18 | Priorizar y construir los charts adicionales (sección 8) | C (diseño) | **A** | – | – | – | – | R | C | C |
| 19 | Operación, costos y revisión de accesos | – | **A** | C | C | R | R | R | C | I |
| 20 | Soporte de Databricks (escalaciones de producto) | **R** | A | – | – | – | – | C | – | – |

> El Client Owner es **Accountable** de todo lo que ocurre en el ambiente de Grupo Bimbo. Yesenia es Accountable solo del MVP y de su documentación; después participa como **Consulted**.

---

## 8. Charts adicionales propuestos

Todos usan system tables y el parámetro `:lookback_days`. Hay que **validar los queries en el account del cliente** antes de agregarlos al `.lvdash.json`. Los campos marcados con ⚠ dependen de `request_params` y deben confirmarse con el query T-04.

### Prioridad alta

**N-01 · Workspace name en lugar de workspace ID** (mejora para todos los charts por workspace)
```sql
SELECT COALESCE(w.workspace_name, CAST(a.workspace_id AS STRING)) AS workspace_name,
       COUNT(DISTINCT a.request_params.dashboard_id)             AS dashboard_count
FROM system.access.audit a
LEFT JOIN system.access.workspaces_latest w ON a.workspace_id = w.workspace_id
WHERE a.service_name = 'dashboards'
  AND a.event_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY dashboard_count DESC
```
Visualización: bar chart que reemplaza "Dashboards by Workspace".

**N-02 · Top dashboards por viewers únicos** (adopción real)
```sql
SELECT request_params.dashboard_id         AS dashboard_id,
       COUNT(DISTINCT user_identity.email) AS unique_viewers,
       COUNT(*)                            AS views,
       MAX(event_date)                     AS last_viewed
FROM system.access.audit
WHERE service_name = 'dashboards'
  AND action_name IN ('getDashboard', 'getPublishedDashboard')
  AND event_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY unique_viewers DESC LIMIT 20
```
Visualización: bar chart y tabla.

**N-03 · Usuarios activos diarios (DAU)**
```sql
SELECT event_date, COUNT(DISTINCT user_identity.email) AS active_users
FROM system.access.audit
WHERE service_name = 'dashboards'
  AND action_name IN ('getDashboard', 'getPublishedDashboard')
  AND event_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY event_date
```
Visualización: line chart y un counter con el promedio.

**N-04 · Dashboards obsoletos (candidatos a limpieza)**: tuvieron actividad en los últimos 365 días, pero ninguna vista en los últimos N días y no fueron eliminados.
```sql
WITH ev AS (
  SELECT request_params.dashboard_id AS dashboard_id, workspace_id, event_date, action_name
  FROM system.access.audit
  WHERE service_name = 'dashboards'
    AND request_params.dashboard_id IS NOT NULL
    AND event_date >= date_sub(current_date(), 365)
)
SELECT dashboard_id,
       CAST(ANY_VALUE(workspace_id) AS STRING)                                                     AS workspace_id,
       MAX(CASE WHEN action_name IN ('getDashboard','getPublishedDashboard') THEN event_date END) AS last_viewed,
       MAX(CASE WHEN action_name IN ('createDashboard','updateDashboard','publishDashboard') THEN event_date END) AS last_modified,
       datediff(current_date(),
         MAX(CASE WHEN action_name IN ('getDashboard','getPublishedDashboard') THEN event_date END)) AS days_since_view
FROM ev
GROUP BY dashboard_id
HAVING SUM(CASE WHEN action_name IN ('trashDashboard','deleteDashboard') THEN 1 ELSE 0 END) = 0
   AND (last_viewed IS NULL OR last_viewed < date_sub(current_date(), :lookback_days))
ORDER BY days_since_view DESC NULLS FIRST
```
Visualización: tabla y un counter "Dashboards sin uso".

**N-05 · Performance por dashboard** (latencia de queries)
```sql
SELECT query_source.dashboard_id                                  AS dashboard_id,
       COUNT(*)                                                   AS queries,
       ROUND(AVG(total_duration_ms) / 1000, 2)                    AS avg_sec,
       ROUND(PERCENTILE(total_duration_ms, 0.95) / 1000, 2)       AS p95_sec,
       ROUND(AVG(CASE WHEN from_result_cache THEN 1 ELSE 0 END) * 100, 1) AS cache_hit_pct,
       ROUND(SUM(read_bytes) / POWER(1024, 3), 2)                 AS gb_read
FROM system.query.history
WHERE query_source.dashboard_id IS NOT NULL
  AND start_time >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY p95_sec DESC LIMIT 20
```
Visualización: bar chart de p95 y una tabla. Sirve para detectar dashboards lentos o costosos.

**N-06 · Queries fallidos por dashboard**
```sql
SELECT query_source.dashboard_id AS dashboard_id, executed_by, error_message, COUNT(*) AS failures
FROM system.query.history
WHERE query_source.dashboard_id IS NOT NULL
  AND execution_status = 'FAILED'
  AND start_time >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY failures DESC LIMIT 50
```
Visualización: tabla en la página Errors & Reliability. Complementa los errores de API con errores de ejecución SQL.

### Prioridad media

**N-07 · Accesos de usuarios externos o service principals** (seguridad, D-18)
```sql
SELECT CASE WHEN user_identity.email NOT LIKE '%@%'                 THEN 'Service principal'
            WHEN lower(user_identity.email) LIKE '%@grupobimbo.com' THEN 'Corporate'
            ELSE 'External' END                    AS identity_type,
       user_identity.email                         AS identity,
       COUNT(*)                                    AS events,
       COUNT(DISTINCT request_params.dashboard_id) AS dashboards
FROM system.access.audit
WHERE service_name = 'dashboards'
  AND event_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY events DESC
```
Visualización: un pie o bar chart por `identity_type`, más una tabla filtrada a "External".

**N-08 · Ciclo de vida: creados vs publicados vs eliminados por semana**
```sql
SELECT date_trunc('WEEK', event_date) AS week,
       CASE WHEN action_name = 'createDashboard'                     THEN 'Created'
            WHEN action_name = 'publishDashboard'                    THEN 'Published'
            WHEN action_name IN ('trashDashboard','deleteDashboard') THEN 'Deleted' END AS lifecycle,
       COUNT(DISTINCT request_params.dashboard_id) AS dashboards
FROM system.access.audit
WHERE service_name = 'dashboards'
  AND action_name IN ('createDashboard','publishDashboard','trashDashboard','deleteDashboard')
  AND event_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY week
```
Visualización: stacked bar chart.

**N-09 · Costo de los warehouses usados por dashboards** (DBUs y costo a list price)
```sql
WITH dash_wh AS (
  SELECT DISTINCT compute.warehouse_id AS warehouse_id
  FROM system.query.history
  WHERE query_source.dashboard_id IS NOT NULL
    AND start_time >= date_sub(current_date(), :lookback_days)
)
SELECT u.usage_date,
       u.usage_metadata.warehouse_id                               AS warehouse_id,
       SUM(u.usage_quantity)                                       AS dbus,
       ROUND(SUM(u.usage_quantity * lp.pricing.effective_list.default), 2) AS list_cost_usd
FROM system.billing.usage u
JOIN dash_wh d ON u.usage_metadata.warehouse_id = d.warehouse_id
LEFT JOIN system.billing.list_prices lp
  ON u.sku_name = lp.sku_name AND u.cloud = lp.cloud
 AND u.usage_start_time >= lp.price_start_time
 AND (lp.price_end_time IS NULL OR u.usage_start_time < lp.price_end_time)
WHERE u.usage_date >= date_sub(current_date(), :lookback_days)
GROUP BY ALL ORDER BY u.usage_date
```
Visualización: stacked area chart por warehouse. El costo es a list price; no refleja los descuentos del contrato. Estos warehouses pueden atender también otros workloads; para atribuir el costo por dashboard se puede prorratear con `total_task_duration_ms` de N-05.

**N-10 · Concentración de ownership** (riesgo de dependencia de una sola persona)
```sql
SELECT user_identity.email AS creator,
       COUNT(DISTINCT request_params.dashboard_id)  AS dashboards_created,
       COUNT(DISTINCT workspace_id)                 AS workspaces
FROM system.access.audit
WHERE service_name = 'dashboards' AND action_name = 'createDashboard'
  AND event_date >= date_sub(current_date(), 365)
GROUP BY ALL ORDER BY dashboards_created DESC LIMIT 20
```
Visualización: bar chart.

### Fase 2 (requiere validación o un componente adicional)

| ID | Chart | Fuente / nota |
|---|---|---|
| N-11 | Dashboards publicados con embedded credentials | `publishDashboard` + ⚠ `request_params.embed_credentials` |
| N-12 | Schedules y subscriptions creados, por dashboard | ⚠ Confirmar los `action_name` de schedules y subscriptions con T-04 |
| N-13 | Permisos otorgados a grupos amplios (`users`, `account users`) | `changeWorkspaceAcl` + ⚠ parsear `request_params.aclPermissionSet` |
| N-14 | **Inventario real con nombre de dashboard y owner** | Un job diario que guarde `GET /api/2.0/lakeview/dashboards` en `<catalog>.<schema>.dashboard_inventory` y que se cruce con el audit log. Aquí sí se usan las variables `catalog_name` y `schema_name` del bundle |
| N-15 | Uso de Genie spaces | `service_name = 'aibiGenie'`. Extiende el gobierno a AI/BI completo |

**Organización sugerida de páginas:** agregar N-02/N-03 a *Usage & Adoption*, N-04/N-08/N-10 a una página nueva *Lifecycle & Cleanup*, N-05/N-06/N-09 a una página nueva *Performance & Cost* y N-07 a *Access & Permissions*.

---

## 9. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| System schemas no habilitados en el metastore del cliente | Dashboard vacío o con errores | Paso 1 de la Fase 1; test T-01 |
| `action_name` distintos en el account del cliente | Widgets vacíos | Test T-04 antes del UAT |
| Exposición de emails y errores a demasiados usuarios | Riesgo de compliance | Grupo Consumers acotado; decisiones D-23 y D-24 |
| Ediciones manuales en prod sobrescritas por el siguiente deploy | Pérdida de cambios | Proceso de la Fase 6 (`bundle generate` → PR) |
| Dashboard con owner personal | Se rompe si la persona sale de la compañía | El owner en prod es el SP (D-32) |
| Costo del warehouse | Consumo inesperado | Serverless con auto-stop corto; tags; chart N-09 |
