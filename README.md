# 🍞 Pan-orama Governance — Dashboard Governance Bundle

This bundle deploys the **Dashboard Governance** AI/BI (Lakeview) dashboard. The dashboard tracks how AI/BI dashboards are created, used, shared, and deleted across workspaces.

| | |
|---|---|
| **Data source** | Unity Catalog system tables (`system.access.audit`, `system.query.history`, `system.billing.*`, `system.access.workspaces_latest`) |
| **Delivered by** | Yesenia Alejandro — Delivery Solutions Architect |

The dashboard pages read `system.access.audit`. The other tables are used by the smoke tests and the additional charts described in `docs/PLAN_DEPLOYMENT_GRUPO_BIMBO.md` (section 8).

## Contents

```
Pan-orama-Governance/
├── databricks.yml                         # Bundle config: variables, dashboard resource, dev/prod targets
├── README.md
├── docs/PLAN_DEPLOYMENT_GRUPO_BIMBO.md     # Definitions, AD groups, deployment phases, RACI, test plan, additional charts
├── tests/smoke_tests.sql                  # SQL checks to run in the client environment
└── src/
    └── dashboard_governance.lvdash.json   # Dashboard definition (datasets, pages, widgets)
```

### Dashboard pages

| Page | What it shows |
|---|---|
| **Overview** | Active dashboard count, dashboards by workspace, top creators, action breakdown, error trend |
| **Usage & Adoption** | Top consumers (views), daily activity trend, action breakdown and trend |
| **Access & Permissions** | Sharing/permission events: table, by user, by action |
| **Errors & Reliability** | Error trend, top users with errors, errors by action and by status code, error details |
| **Audit Trail** | Recent actions (latest 200), dashboard creators, deletion log |
| **Inactive Dashboards** | Dashboards with no activity in the lookback window: count, top 20 owners, detail table |
| **Global Filters** | `Lookback (days)`: time window for every dataset. `History (days)`: audit history scanned to find inactive dashboards |

### Datasets

`dashboards_by_workspace`, `activity_trend`, `dashboard_inventory`, `top_consumers`, `dashboard_creators`, `recent_actions`, `deletion_log`, `action_breakdown`, `sharing_activity`, `error_details`, `failed_operations`, `inactive_dashboards`, `inactive_by_owner`

### Activity-based metrics

Every metric comes from audit **events**, so a dashboard only counts as active if something happened to it (view, edit, refresh, share...) inside the lookback window. System tables have no dashboard inventory, so dashboards with no events at all are not visible.

**Inactive Dashboards** = dashboards that had events in the `history_days` window, were not trashed or deleted, and had no events in the last `lookback_days`.
- **Owner** is the creator (`createDashboard`). If the dashboard wasn't created inside the history window, it falls back to the last editor (`updateDashboard` / `publishDashboard`). If neither happened, the owner is `unknown`, and those dashboards are left out of the owners chart. A larger `history_days` reduces the number of `unknown` owners.
- **Cost:** with `history_days` = 30, the query scans about a month of audit events and takes about 1 minute. At 90 days it takes about 2.5 minutes.

### `lookback_days` / `history_days` parameters

Every dataset filters with `event_date >= date_sub(current_date(), :lookback_days)`.

- **Default: `7` days.** This keeps queries fast while testing.
- **Change it at runtime** with the **Lookback (days)** global filter (e.g. `30`, `90`).
- `history_days` (default `30`) is used only by the Inactive Dashboards page. It is set with the **History (days)** global filter, max 365, and must be greater than `lookback_days`.
- **Change the default:** in `src/dashboard_governance.lvdash.json`, update `"value": "7"` in each dataset's `parameters[].defaultSelection` and in the global filter, then redeploy.

## Prerequisites

- Databricks CLI v0.232+ (needed for bundle `dashboards` resources) (`databricks --version`), authenticated to the target workspace (`databricks auth login --profile <profile>`)
- A SQL warehouse (serverless recommended)
- `SELECT` on `system.access.audit` for the warehouse owner and the dashboard viewers (system tables must be enabled for the account)

## Configuration

Variables in `databricks.yml`:

| Variable | Description | Default |
|---|---|---|
| `warehouse_id` | SQL warehouse that runs the dashboard | `REPLACE_WITH_YOUR_WAREHOUSE_ID` |
| `catalog_name` | Default catalog for datasets | `main` (dev: `dev_catalog`, prod: `prod_catalog`) |
| `schema_name` | Default schema for datasets | `default` (dev: `dev_schema`, prod: `prod_schema`) |

All queries use fully qualified `system.access.audit`, so `catalog_name`/`schema_name` only matter if you add datasets that use unqualified table names.

To find a warehouse ID:

```bash
databricks warehouses list --profile <profile>
```

Set it in `databricks.yml`, or pass it on the command line with `--var warehouse_id=<id>`.

## Deploy

Run these from this directory (the one containing `databricks.yml`):

```bash
# 1. Validate
databricks bundle validate -t dev --profile <profile> --var warehouse_id=<id>

# 2. Deploy to dev (development mode: dashboard is named "[dev <user>] Dashboard Governance - POC")
databricks bundle deploy -t dev --profile <profile> --var warehouse_id=<id>

# 3. Deploy to prod
databricks bundle deploy -t prod --profile <profile> --var warehouse_id=<id>
```

The `fevm` target is preconfigured for `https://fevm-serverless-stable-ga965x.cloud.databricks.com`. It uses warehouse `gb_gov_mvp` and the schema `serverless_stable_ga965x_catalog.gb_gov_mvp`, so it needs no `--var`:

```bash
databricks bundle deploy -t fevm --profile fevm-serverless-stable-ga965x
```

Then open the dashboard from **Dashboards** in the workspace, or get the URL with:

```bash
databricks bundle summary -t dev --profile <profile>
```

### Permissions

| Target | Permissions |
|---|---|
| `dev` | `users`: CAN_READ |
| `prod` | `admins`: CAN_EDIT, `users`: CAN_READ |
| `bimbo_dev` | `GB-DBX-DashGov-Developers`: CAN_MANAGE, `GB-DBX-DashGov-Consumers`: CAN_READ |
| `bimbo_prod` | `GB-DBX-DashGov-Admins`: CAN_MANAGE, Developers and Consumers: CAN_READ |

### Grupo Bimbo targets

`bimbo_dev` and `bimbo_prod` deploy to the client's own workspaces. Before using them, replace the `REPLACE_WITH_BIMBO_*` workspace URLs and warehouse names in `databricks.yml`, then follow `docs/PLAN_DEPLOYMENT_GRUPO_BIMBO.md`. Group names are bundle variables (`admins_group`, `developers_group`, `consumers_group`).

### Remove

```bash
databricks bundle destroy -t dev --profile <profile>
```

## Updating the dashboard

If you edit the dashboard in the UI, export the changes back into the bundle before redeploying. Otherwise the next deploy overwrites them:

```bash
databricks bundle generate dashboard --resource dashboard_governance --force -t dev --profile <profile>
```
