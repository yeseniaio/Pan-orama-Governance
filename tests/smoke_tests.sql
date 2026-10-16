-- Dashboard Governance — smoke tests for the client environment
-- Run in the Databricks SQL editor on the dashboard's warehouse.
-- See docs/PLAN_DEPLOYMENT_GRUPO_BIMBO.md section 6.

-- T-01 · Access to system tables (run as the SP and as a developer)
SELECT COUNT(*) AS audit_rows_last_7d
FROM system.access.audit
WHERE event_date >= date_sub(current_date(), 7);

-- T-04 · Real action names for dashboards in this account
SELECT service_name, action_name, COUNT(*) AS events
FROM system.access.audit
WHERE event_date >= date_sub(current_date(), 30)
  AND (service_name = 'dashboards'
       OR (service_name = 'workspace' AND action_name = 'changeWorkspaceAcl'
           AND request_params.aclChangeResourceName LIKE 'dashboards/%'))
GROUP BY ALL
ORDER BY events DESC;

-- T-05 · Row counts behind each dataset (30-day window); any 0 must be explained
SELECT 'top_consumers' AS dataset, COUNT(*) AS rows FROM system.access.audit
 WHERE service_name = 'dashboards' AND action_name IN ('getDashboard','getPublishedDashboard')
   AND event_date >= date_sub(current_date(), 30)
UNION ALL
SELECT 'dashboard_creators', COUNT(*) FROM system.access.audit
 WHERE service_name = 'dashboards' AND action_name = 'createDashboard'
   AND event_date >= date_sub(current_date(), 30)
UNION ALL
SELECT 'deletion_log', COUNT(*) FROM system.access.audit
 WHERE service_name = 'dashboards' AND action_name IN ('trashDashboard','deleteDashboard')
   AND event_date >= date_sub(current_date(), 30)
UNION ALL
SELECT 'sharing_activity', COUNT(*) FROM system.access.audit
 WHERE service_name = 'workspace' AND action_name = 'changeWorkspaceAcl'
   AND request_params.aclChangeResourceName LIKE 'dashboards/%'
   AND event_date >= date_sub(current_date(), 30)
UNION ALL
SELECT 'failed_operations', COUNT(*) FROM system.access.audit
 WHERE service_name = 'dashboards' AND response.status_code >= 400
   AND event_date >= date_sub(current_date(), 30);

-- T-06 · Reconciliation: must match the "Active Dashboards" counter with Lookback = 30
SELECT COUNT(DISTINCT request_params.dashboard_id) AS dashboard_count
FROM system.access.audit
WHERE service_name = 'dashboards'
  AND event_date >= date_sub(current_date(), 30);

-- T-01b · Optional: access needed by the proposed charts (section 8)
SELECT COUNT(*) AS workspaces FROM system.access.workspaces_latest;
SELECT COUNT(*) AS dashboard_queries_7d FROM system.query.history
 WHERE query_source.dashboard_id IS NOT NULL AND start_time >= date_sub(current_date(), 7);
SELECT COUNT(*) AS billing_rows_7d FROM system.billing.usage
 WHERE usage_date >= date_sub(current_date(), 7);
