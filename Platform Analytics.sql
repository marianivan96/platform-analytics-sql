-- ACQUISITION

-- Signups per ecosystem with verified vs unverified breakdown
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT u.id) AS total_signups,
  SUM(u.verified_at IS NOT NULL) AS verified,
  SUM(u.verified_at IS NULL) AS unverified,
  ROUND(100 * SUM(u.verified_at IS NOT NULL) / NULLIF(COUNT(DISTINCT u.id), 0), 1) AS verified_pct
FROM users u
JOIN users_ecosystems ue ON ue.user_id = u.id
JOIN ecosystem e ON e.id = ue.ecosystem_id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY total_signups DESC;


-- How does this month compare to the same period last year
SELECT
  user_type,
  current_period,
  previous_period,
  ROUND(100 * (current_period - previous_period) / NULLIF(previous_period, 0), 2) AS growth_pct
FROM (
  SELECT user_type,
    SUM(CASE WHEN period = 'current'  THEN cnt ELSE 0 END) AS current_period,
    SUM(CASE WHEN period = 'previous' THEN cnt ELSE 0 END) AS previous_period
  FROM (
    SELECT
      CASE WHEN verified_at IS NOT NULL THEN 'validated' ELSE 'non_validated' END AS user_type,
      COUNT(DISTINCT id) AS cnt,
      'current' AS period
    FROM users
    WHERE deleted_at IS NULL
      AND DATE(created_at) BETWEEN '2026-01-01' AND '2026-01-31'
    GROUP BY 1
    UNION ALL
    SELECT
      CASE WHEN verified_at IS NOT NULL THEN 'validated' ELSE 'non_validated' END,
      COUNT(DISTINCT id),
      'previous'
    FROM users
    WHERE deleted_at IS NULL
      AND DATE(created_at) BETWEEN '2025-01-01' AND '2025-01-31'
    GROUP BY 1
    UNION ALL
    SELECT 'total', COUNT(DISTINCT id), 'current'
    FROM users
    WHERE deleted_at IS NULL
      AND DATE(created_at) BETWEEN '2026-01-01' AND '2026-01-31'
    UNION ALL
    SELECT 'total', COUNT(DISTINCT id), 'previous'
    FROM users
    WHERE deleted_at IS NULL
      AND DATE(created_at) BETWEEN '2025-01-01' AND '2025-01-31'
  ) raw
  GROUP BY user_type
) final
ORDER BY FIELD(user_type, 'total', 'validated', 'non_validated');


-- What type of stakeholders are signing up
SELECT
  sg.label AS stakeholder_group,
  COUNT(DISTINCT u.id) AS users
FROM users u
JOIN users_stakeholder_groups_profile usg ON usg.user_id = u.id
JOIN stakeholder_groups_profile sg ON sg.id = usg.stakeholder_group_id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY sg.label
ORDER BY users DESC;


-- VISITOR CONVERSION

-- Visitor to user conversion rate per ecosystem
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT v.id) AS visitors,
  COUNT(DISTINCT CASE WHEN v.user_id IS NOT NULL THEN v.id END) AS converted,
  ROUND(
    COUNT(DISTINCT CASE WHEN v.user_id IS NOT NULL THEN v.id END) * 100.0
    / NULLIF(COUNT(DISTINCT v.id), 0), 2
  ) AS conversion_pct
FROM track_visitors v
LEFT JOIN users_ecosystems ue ON ue.user_id = v.user_id
LEFT JOIN ecosystem e ON e.id = ue.ecosystem_id
WHERE DATE(v.first_visit_on) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY conversion_pct DESC;


-- High-intent visitors who never signed up (5+ pageviews, visited 2+ days)
SELECT
  e.name AS ecosystem,
  COUNT(*) AS missed_conversions
FROM track_visitors v
LEFT JOIN users_ecosystems ue ON ue.user_id = v.user_id
LEFT JOIN ecosystem e ON e.id = ue.ecosystem_id
WHERE v.user_id IS NULL
  AND v.page_views_count >= 5
  AND v.lifespan_days >= 2
  AND DATE(v.first_visit_on) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY missed_conversions DESC;


-- Do signed-in users browse more than anonymous ones
SELECT
  CASE WHEN user_id IS NULL THEN 'anonymous' ELSE 'signed_in' END AS visitor_type,
  ROUND(AVG(page_views_count), 2) AS avg_pageviews,
  ROUND(AVG(visits_count), 2) AS avg_visits,
  ROUND(AVG(lifespan_days), 2) AS avg_lifespan_days
FROM track_visitors
WHERE DATE(first_visit_on) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY visitor_type;


-- ACTIVATION

-- How many users signed up but never did anything
SELECT
  COUNT(*) AS total_signups,
  SUM(ua.id IS NULL) AS never_acted,
  ROUND(100 * SUM(ua.id IS NULL) / COUNT(*), 2) AS inactive_pct
FROM users u
LEFT JOIN user_actions ua ON ua.user_id = u.id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31';


-- What is the first thing new users do after signing up
SELECT
  fa.first_action,
  COUNT(*) AS users
FROM (
  SELECT
    ua.user_id,
    SUBSTRING_INDEX(GROUP_CONCAT(ua.action ORDER BY ua.created_at ASC SEPARATOR ','), ',', 1) AS first_action
  FROM user_actions ua
  WHERE ua.user_id IN (
    SELECT id FROM users
    WHERE deleted_at IS NULL
      AND DATE(created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  )
  GROUP BY ua.user_id
) fa
GROUP BY fa.first_action
ORDER BY users DESC;


-- Average minutes from signup to first action
SELECT
  ROUND(AVG(TIMESTAMPDIFF(MINUTE, u.created_at, fa.first_action_time)), 1) AS avg_minutes_to_first_action
FROM users u
JOIN (
  SELECT user_id, MIN(created_at) AS first_action_time
  FROM user_actions
  GROUP BY user_id
) fa ON fa.user_id = u.id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31';


-- % of new users who took action within 7 days per ecosystem
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT u.id) AS signups,
  SUM(a7.user_id IS NOT NULL) AS activated_within_7d,
  ROUND(100 * SUM(a7.user_id IS NOT NULL) / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS activation_7d_pct
FROM users u
JOIN users_ecosystems ue ON ue.user_id = u.id
JOIN ecosystem e ON e.id = ue.ecosystem_id
LEFT JOIN (
  SELECT DISTINCT ua.user_id
  FROM user_actions ua
  JOIN users u2 ON u2.id = ua.user_id
  WHERE u2.deleted_at IS NULL
    AND ua.created_at >= u2.created_at
    AND ua.created_at <  u2.created_at + INTERVAL 7 DAY
) a7 ON a7.user_id = u.id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY activation_7d_pct DESC;


-- ENGAGEMENT

-- All action types ranked by volume and unique users
SELECT
  ua.action,
  COUNT(*) AS total,
  COUNT(DISTINCT ua.user_id) AS unique_users
FROM user_actions ua
JOIN users u ON u.id = ua.user_id
WHERE u.deleted_at IS NULL
  AND DATE(ua.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY ua.action
ORDER BY total DESC;


-- Daily active users per ecosystem
SELECT
  e.name AS ecosystem,
  DATE(ua.created_at) AS day,
  COUNT(DISTINCT ua.user_id) AS dau
FROM user_actions ua
JOIN users u ON u.id = ua.user_id
JOIN ecosystem e ON e.id = ua.ecosystem_id
WHERE u.deleted_at IS NULL
  AND DATE(ua.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name, DATE(ua.created_at)
ORDER BY day, ecosystem;


-- Users active on 2+ days (repeat engagement)
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT ua.user_id) AS active_users,
  COUNT(DISTINCT CASE WHEN x.active_days >= 2 THEN x.user_id END) AS repeat_users,
  ROUND(
    100 * COUNT(DISTINCT CASE WHEN x.active_days >= 2 THEN x.user_id END)
    / NULLIF(COUNT(DISTINCT ua.user_id), 0), 2
  ) AS repeat_rate_pct
FROM user_actions ua
JOIN users u ON u.id = ua.user_id
JOIN ecosystem e ON e.id = ua.ecosystem_id
JOIN (
  SELECT ecosystem_id, user_id, COUNT(DISTINCT DATE(created_at)) AS active_days
  FROM user_actions
  WHERE DATE(created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  GROUP BY ecosystem_id, user_id
) x ON x.ecosystem_id = ua.ecosystem_id AND x.user_id = ua.user_id
WHERE u.deleted_at IS NULL
  AND DATE(ua.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY repeat_rate_pct DESC;


-- RETENTION

-- D1 / D7 / D30 cohort retention per ecosystem
SELECT
  e.name AS ecosystem,
  DATE(u.created_at) AS signup_day,
  COUNT(DISTINCT u.id) AS signups,
  ROUND(100 * SUM(d1.user_id IS NOT NULL)  / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS d1_pct,
  ROUND(100 * SUM(d7.user_id IS NOT NULL)  / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS d7_pct,
  ROUND(100 * SUM(d30.user_id IS NOT NULL) / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS d30_pct
FROM users u
JOIN users_ecosystems ue ON ue.user_id = u.id
JOIN ecosystem e ON e.id = ue.ecosystem_id
LEFT JOIN (
  SELECT DISTINCT ua.user_id FROM user_actions ua
  JOIN users u2 ON u2.id = ua.user_id
  WHERE u2.deleted_at IS NULL
    AND ua.created_at >= u2.created_at + INTERVAL 1 DAY
    AND ua.created_at <  u2.created_at + INTERVAL 2 DAY
) d1 ON d1.user_id = u.id
LEFT JOIN (
  SELECT DISTINCT ua.user_id FROM user_actions ua
  JOIN users u2 ON u2.id = ua.user_id
  WHERE u2.deleted_at IS NULL
    AND ua.created_at >= u2.created_at + INTERVAL 7 DAY
    AND ua.created_at <  u2.created_at + INTERVAL 8 DAY
) d7 ON d7.user_id = u.id
LEFT JOIN (
  SELECT DISTINCT ua.user_id FROM user_actions ua
  JOIN users u2 ON u2.id = ua.user_id
  WHERE u2.deleted_at IS NULL
    AND ua.created_at >= u2.created_at + INTERVAL 30 DAY
    AND ua.created_at <  u2.created_at + INTERVAL 31 DAY
) d30 ON d30.user_id = u.id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name, DATE(u.created_at)
ORDER BY signup_day, ecosystem;


-- Users who haven't logged in for 2+ years
SELECT
  sg.label AS stakeholder_group,
  COUNT(DISTINCT u.id) AS inactive_users
FROM users u
JOIN users_stakeholder_groups_profile usg ON usg.user_id = u.id
JOIN stakeholder_groups_profile sg ON sg.id = usg.stakeholder_group_id
WHERE u.last_login < DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
  AND u.deleted_at IS NULL
GROUP BY sg.label
ORDER BY inactive_users DESC;



-- CONTENT CREATION

-- Resources created vs actually published per ecosystem
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT r.id) AS created,
  SUM(r.published_at IS NOT NULL) AS published,
  ROUND(100 * SUM(r.published_at IS NOT NULL) / NULLIF(COUNT(DISTINCT r.id), 0), 1) AS publish_rate_pct
FROM resources r
JOIN resources_ecosystems re ON re.resource_id = r.id
JOIN ecosystem e ON e.id = re.ecosystem_id
JOIN users u ON u.id = r.created_by
WHERE r.deleted_at IS NULL
  AND u.deleted_at IS NULL
  AND DATE(r.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
ORDER BY created DESC;


-- Entity counts this year vs last year (users, events, resources, initiatives, orgs)
SELECT 'users' AS entity,
  SUM(created_at >= DATE_FORMAT(CURDATE(), '%Y-01-01')
      AND created_at < DATE_ADD(CURDATE(), INTERVAL 1 DAY)) AS ytd,
  SUM(created_at >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-01-01'), INTERVAL 1 YEAR)
      AND created_at < DATE_SUB(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 1 YEAR)) AS ytd_prev_year
FROM users WHERE deleted_at IS NULL
UNION ALL
SELECT 'events',
  SUM(created_at >= DATE_FORMAT(CURDATE(), '%Y-01-01')
      AND created_at < DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
  SUM(created_at >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-01-01'), INTERVAL 1 YEAR)
      AND created_at < DATE_SUB(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 1 YEAR))
FROM events WHERE deleted_at IS NULL
UNION ALL
SELECT 'resources',
  SUM(created_at >= DATE_FORMAT(CURDATE(), '%Y-01-01')
      AND created_at < DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
  SUM(created_at >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-01-01'), INTERVAL 1 YEAR)
      AND created_at < DATE_SUB(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 1 YEAR))
FROM resources WHERE deleted_at IS NULL
UNION ALL
SELECT 'initiatives',
  SUM(created_at >= DATE_FORMAT(CURDATE(), '%Y-01-01')
      AND created_at < DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
  SUM(created_at >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-01-01'), INTERVAL 1 YEAR)
      AND created_at < DATE_SUB(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 1 YEAR))
FROM initiatives WHERE deleted_at IS NULL
UNION ALL
SELECT 'organizations',
  SUM(created_at >= DATE_FORMAT(CURDATE(), '%Y-01-01')
      AND created_at < DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
  SUM(created_at >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-01-01'), INTERVAL 1 YEAR)
      AND created_at < DATE_SUB(DATE_ADD(CURDATE(), INTERVAL 1 DAY), INTERVAL 1 YEAR))
FROM organizations WHERE deleted_at IS NULL;



-- SEARCH BEHAVIOUR

-- Search volume and zero-result rate per ecosystem
SELECT
  e.name AS ecosystem,
  COUNT(*) AS searches,
  COUNT(DISTINCT tsr.created_by) AS unique_searchers,
  ROUND(AVG(tsr.results_count), 2) AS avg_results,
  SUM(tsr.results_count = 0) AS zero_results,
  ROUND(100 * SUM(tsr.results_count = 0) / NULLIF(COUNT(*), 0), 2) AS zero_result_pct
FROM track_search_results tsr
LEFT JOIN ecosystem e ON e.id = tsr.ecosystem_id
LEFT JOIN users u ON u.id = tsr.created_by
WHERE DATE(tsr.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  AND (u.id IS NULL OR u.deleted_at IS NULL)
GROUP BY e.name
ORDER BY searches DESC;


-- Most searched queries — what users are actually looking for
SELECT
  LOWER(TRIM(tsr.query)) AS query,
  COUNT(*) AS searches,
  COUNT(DISTINCT tsr.created_by) AS unique_searchers,
  ROUND(100 * SUM(tsr.results_count = 0) / NULLIF(COUNT(*), 0), 2) AS zero_result_pct
FROM track_search_results tsr
WHERE DATE(tsr.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  AND tsr.query IS NOT NULL
  AND TRIM(tsr.query) <> ''
GROUP BY LOWER(TRIM(tsr.query))
ORDER BY searches DESC
LIMIT 100;


-- Queries that always return zero results — content gaps
SELECT
  LOWER(TRIM(tsr.query)) AS query,
  COUNT(*) AS times_searched,
  COUNT(DISTINCT tsr.created_by) AS users_affected
FROM track_search_results tsr
WHERE DATE(tsr.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  AND tsr.results_count = 0
  AND tsr.query IS NOT NULL
  AND TRIM(tsr.query) <> ''
GROUP BY LOWER(TRIM(tsr.query))
ORDER BY times_searched DESC
LIMIT 100;


-- Users searching the same zero-result query multiple times (frustration signal)
SELECT
  e.name AS ecosystem,
  u.email,
  tsr.query,
  COUNT(*) AS repeated_searches
FROM track_search_results tsr
JOIN ecosystem e ON e.id = tsr.ecosystem_id
JOIN users u ON u.id = tsr.created_by
WHERE DATE(tsr.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  AND tsr.results_count = 0
  AND tsr.query IS NOT NULL
  AND TRIM(tsr.query) <> ''
  AND u.deleted_at IS NULL
GROUP BY e.name, u.email, tsr.query
HAVING COUNT(*) >= 2
ORDER BY repeated_searches DESC
LIMIT 200;


-- NOTIFICATIONS

-- Notifications sent per ecosystem — volume and reach
SELECT
  e.name AS ecosystem,
  n.template AS notification_type,
  COUNT(nu.id) AS total_sent,
  COUNT(DISTINCT nu.user_id) AS unique_recipients
FROM notification_user nu
JOIN notification n ON n.id = nu.notification_id
LEFT JOIN users u ON u.id = nu.user_id
LEFT JOIN users_ecosystems ue ON ue.user_id = u.id
LEFT JOIN ecosystem e ON e.id = ue.ecosystem_id
WHERE DATE(nu.sent_at) BETWEEN '2026-01-01' AND '2026-01-31'
  AND (u.id IS NULL OR u.deleted_at IS NULL)
GROUP BY e.name, n.template
ORDER BY e.name, total_sent DESC;


-- GROWTH FLAGS

-- Ecosystems with low verification or low 7-day activation
SELECT
  e.name AS ecosystem,
  COUNT(DISTINCT u.id) AS signups,
  ROUND(100 * SUM(u.verified_at IS NOT NULL) / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS verification_pct,
  ROUND(100 * SUM(EXISTS (
    SELECT 1 FROM user_actions ua
    WHERE ua.user_id = u.id
      AND ua.created_at >= u.created_at
      AND ua.created_at <  u.created_at + INTERVAL 7 DAY
  )) / NULLIF(COUNT(DISTINCT u.id), 0), 2) AS activation_7d_pct
FROM users u
JOIN users_ecosystems ue ON ue.user_id = u.id
JOIN ecosystem e ON e.id = ue.ecosystem_id
WHERE u.deleted_at IS NULL
  AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY e.name
HAVING verification_pct < 60 OR activation_7d_pct < 40
ORDER BY verification_pct ASC;


-- Content categories with high demand (bookmarks) but low supply (resources created)
SELECT
  e.name AS ecosystem,
  rc.name AS category,
  COALESCE(s.resources_created, 0) AS resources_created,
  COALESCE(d.bookmarks, 0) AS bookmarks,
  ROUND(COALESCE(d.bookmarks, 0) / NULLIF(COALESCE(s.resources_created, 0), 0), 2) AS bookmarks_per_resource
FROM ecosystem e
LEFT JOIN (
  SELECT re.ecosystem_id, r.category_id, COUNT(DISTINCT r.id) AS resources_created
  FROM resources r
  JOIN resources_ecosystems re ON re.resource_id = r.id
  JOIN users u ON u.id = r.created_by
  WHERE r.deleted_at IS NULL
    AND u.deleted_at IS NULL
    AND DATE(r.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
  GROUP BY re.ecosystem_id, r.category_id
) s ON s.ecosystem_id = e.id
LEFT JOIN resource_categories rc ON rc.id = s.category_id
LEFT JOIN (
  SELECT b.ecosystem_id, r.category_id, COUNT(*) AS bookmarks
  FROM bookmarks b
  JOIN resources r ON r.id = b.entity_id
  LEFT JOIN users u ON u.id = b.user_id
  WHERE b.entity_type IN ('resource', 'resources')
    AND DATE(b.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
    AND (u.id IS NULL OR u.deleted_at IS NULL)
  GROUP BY b.ecosystem_id, r.category_id
) d ON d.ecosystem_id = e.id AND d.category_id = s.category_id
WHERE COALESCE(d.bookmarks, 0) >= 5
ORDER BY bookmarks_per_resource DESC
LIMIT 200;