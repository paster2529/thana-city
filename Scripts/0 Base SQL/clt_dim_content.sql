SELECT * FROM "trusted".hook_content_items ORDER BY id;
SELECT * FROM "trusted".hook_articles ORDER BY 1;

WITH hook_content_items_raw AS (
	SELECT *
		, NULLIF(REGEXP_SUBSTR(action_value, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 1, 1, 'i'), '') AS content_uuid
	FROM (
		SELECT id::VARCHAR AS content_items_id
			, block_id
			, media_type
			, target_member_types[0]::TEXT AS target_member
			, action_provider
			, action_store_id
			, action_type
			, display_order
			, NULLIF(REGEXP_REPLACE(action_value, '[[:space:]]', ''), '') AS action_value
		FROM "trusted".hook_content_items
	) ORDER BY display_order
)
, dim_content_items AS (
	SELECT *
		, CASE
			WHEN action_value IS NULL THEN NULL
			WHEN action_value ILIKE 'http%' THEN 'External link'
			WHEN action_value LIKE '%article%' THEN 'Article'
			WHEN content_uuid IS NOT NULL THEN 'Content'
			ELSE 'Internal page'
			END AS path_category
		, CASE
			WHEN action_value IS NULL THEN NULL
			WHEN action_value ILIKE 'http%' THEN REGEXP_SUBSTR(action_value, '://([^/]+)', 1, 1, 'e')
			WHEN content_uuid IS NOT NULL THEN INITCAP(REGEXP_SUBSTR(action_value, '/([a-z0-9_]+)-[0-9a-f]{8}-', 1, 1, 'ie'))
			ELSE INITCAP(REGEXP_SUBSTR(action_value, '^/?([^/]+)', 1, 1, 'e'))
			END AS action_value_type
		, CASE
			WHEN action_value IS NULL THEN NULL
			WHEN content_uuid IS NOT NULL THEN content_uuid
			ELSE REGEXP_SUBSTR(action_value, '[^/]+$')
			END AS action_value_id
	FROM hook_content_items_raw
)
, dim_article AS (
	SELECT id::VARCHAR AS article_id
		, slug AS article_slug
		, NULLIF(title.en::TEXT, '') AS article_title_en
		, NULLIF(title.th::TEXT, '') AS article_title_th
		, CASE
			WHEN REGEXP_INSTR(NVL(title.en::TEXT, ''), '(^|[^a-z])test([^a-z]|$)', 1, 1, 0, 'i') > 0 THEN 1
			WHEN REGEXP_INSTR(NVL(slug, ''), '(^|[^a-z])test([^a-z]|$)', 1, 1, 0, 'i') > 0 THEN 1
			ELSE 0
			END AS is_test_article
		, content_block_id
	FROM "trusted".hook_articles
	WHERE slug <> 'test'
)
SELECT a.block_id
	, a.content_items_id
	, b.article_id
	, b.article_slug
	, b.article_title_en
	, b.article_title_th
	, a.action_provider
	, a.action_store_id
	, a.action_type
	, a.path_category
	, a.action_value_type
	, a.action_value_id
FROM dim_content_items a
FULL OUTER JOIN dim_article b ON a.content_uuid = b.article_id
ORDER BY a.block_id
	, b.article_id
	, a.content_items_id