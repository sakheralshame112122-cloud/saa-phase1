SET NAMES utf8mb4;

SET FOREIGN_KEY_CHECKS=0;

CREATE TABLE workspaces (
  id              CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name            VARCHAR(64)  NOT NULL,
  slug            VARCHAR(32)  NOT NULL,
  status          ENUM('active','suspended','archived') NOT NULL DEFAULT 'active',
  timezone_name   VARCHAR(64)  NOT NULL DEFAULT 'Asia/Riyadh',
  created_by      CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at      DATETIME(3)  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_workspaces_slug (slug),
  KEY ix_workspaces_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE users (
  id            CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id  CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,          -- NOT NULL إلزامي (C-01)
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,          -- Argon2id — لكلمة مرور لوحة التحكم فقط
  status        ENUM('active','invited','disabled') NOT NULL DEFAULT 'invited',
  mfa_enabled   TINYINT(1) NOT NULL DEFAULT 0,
  mfa_secret_enc TEXT NULL,                     -- مشفّر بنفس طبقة D4
  last_login_at DATETIME(3) NULL,
  created_by    CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at    DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_ws_email (workspace_id, email),
  KEY ix_users_ws_status (workspace_id, status),
  CONSTRAINT fk_users_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE roles (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  code VARCHAR(32) NOT NULL,
  name_ar VARCHAR(64) NOT NULL,
  permission_matrix JSON NOT NULL,
  is_system TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE user_roles (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  role_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  scope ENUM('workspace','account') NOT NULL DEFAULT 'workspace',
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_roles (workspace_id, user_id, role_id, scope, social_account_id),
  KEY ix_user_roles_ws_user (workspace_id, user_id),
  KEY ix_user_roles_ws_account (workspace_id, social_account_id),
  CONSTRAINT fk_ur_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE auth_sessions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii NOT NULL,   -- SHA-256(opaque token)
  csrf_state_hash CHAR(64) CHARACTER SET ascii NULL,
  ip_hash CHAR(64) CHARACTER SET ascii NULL,
  user_agent_hash CHAR(64) CHARACTER SET ascii NULL,
  expires_at DATETIME(3) NOT NULL,
  revoked_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_token (token_hash),
  KEY ix_sessions_ws_user (workspace_id, user_id, expires_at),
  CONSTRAINT fk_sessions_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE social_accounts (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  platform VARCHAR(20) NOT NULL,
  platform_account_id VARCHAR(64) CHARACTER SET ascii NOT NULL,   -- Page ID
  account_name VARCHAR(255) NOT NULL,
  account_username VARCHAR(255) NULL,
  account_url VARCHAR(512) NULL,
  connection_status ENUM('pending','connected','needs_reauth','revoked','disabled') NOT NULL DEFAULT 'pending',
  granted_scopes JSON NULL,
  page_tasks JSON NULL,
  last_sync_status VARCHAR(32) NULL,
  connected_at DATETIME(3) NULL,
  last_synced_at DATETIME(3) NULL,
  last_token_check_at DATETIME(3) NULL,
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sa_ws_platform_account (workspace_id, platform, platform_account_id),
  KEY ix_sa_ws_status (workspace_id, connection_status),
  CONSTRAINT fk_sa_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  CONSTRAINT ck_sa_platform CHECK (platform IN ('facebook')),
  CONSTRAINT ck_sa_platform_id CHECK (platform_account_id REGEXP '^[0-9]+$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE key_versions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  version_number SMALLINT UNSIGNED NOT NULL,
  state ENUM('active','decrypt_only','retired') NOT NULL DEFAULT 'active',
  kek_reference VARCHAR(128) NOT NULL,     -- اسم/مرجع سرّي في البيئة، وليس المفتاح
  activated_at DATETIME(3) NOT NULL,
  retired_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_key_version (version_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE oauth_credentials (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  credential_type ENUM('user_token','page_token') NOT NULL,
  ciphertext MEDIUMBLOB NOT NULL,          -- AES-256-GCM (envelope) — لا يُقرأ بلا مفتاح
  iv VARBINARY(16) NOT NULL,
  auth_tag VARBINARY(16) NOT NULL,
  aad_context VARCHAR(255) NOT NULL,       -- workspace|account|type → يمنع نقل الشيفرة بين سياقين
  key_version_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  token_fingerprint CHAR(64) CHARACTER SET ascii NOT NULL,  -- SHA-256(token) للكشف/الربط فقط
  scopes JSON NOT NULL,
  issued_at DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NULL,             -- NULL = بلا انتهاء زمني (Page token من User token طويل الأمد)
  last_validated_at DATETIME(3) NULL,
  status ENUM('active','expiring_soon','expired','revoked','invalid') NOT NULL DEFAULT 'active',
  rotated_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_cred_account_type (social_account_id, credential_type),
  KEY ix_cred_ws_status (workspace_id, status, expires_at),
  CONSTRAINT fk_cred_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  CONSTRAINT fk_cred_sa FOREIGN KEY (social_account_id) REFERENCES social_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_cred_key FOREIGN KEY (key_version_id) REFERENCES key_versions(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE oauth_credential_events (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  event_type ENUM('issued','refreshed','reauthed','revoked','expired','validation_failed') NOT NULL,
  detail_redacted JSON NULL,               -- بلا توكنات، بلا بصمات كاملة
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_oce_ws_account_time (workspace_id, social_account_id, created_at),
  CONSTRAINT fk_oce_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE media_assets (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  media_type ENUM('image','video') NOT NULL,
  storage_key VARCHAR(512) NOT NULL,       -- MinIO object key (DEC-05)
  original_filename VARCHAR(255) NULL,
  mime_type VARCHAR(255) NOT NULL,
  size_bytes BIGINT UNSIGNED NOT NULL,
  width SMALLINT UNSIGNED NULL,
  height SMALLINT UNSIGNED NULL,
  duration_seconds SMALLINT UNSIGNED NULL,
  content_hash CHAR(64) CHARACTER SET ascii NOT NULL,
  scan_status ENUM('pending','clean','rejected') NOT NULL DEFAULT 'pending',
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_ws_hash (workspace_id, content_hash),
  KEY ix_media_ws_created (workspace_id, created_at),
  CONSTRAINT fk_media_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE platform_posts (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  body TEXT NOT NULL,
  content_hash CHAR(64) CHARACTER SET ascii NOT NULL,   -- منع تكرار المحتوى (W-05)
  post_kind ENUM('text','photo','video','link') NOT NULL DEFAULT 'text',
  link_url VARCHAR(1024) NULL,
  status ENUM('draft','scheduled','queued','publishing','pending_confirm','published','failed','unknown','cancelled')
         NOT NULL DEFAULT 'draft',
  scheduled_for DATETIME(3) NULL,                        -- UTC
  schedule_mode ENUM('platform_native','system_cron') NULL,
  platform_post_id VARCHAR(64) CHARACTER SET ascii NULL,
  platform_permalink VARCHAR(512) NULL,
  idempotency_key_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  approved_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  published_at DATETIME(3) NULL,
  last_reconciled_at DATETIME(3) NULL,
  failure_code VARCHAR(64) NULL,
  failure_reason_redacted TEXT NULL,
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY ix_posts_ws_status_time (workspace_id, status, scheduled_for),
  KEY ix_posts_sa_time (workspace_id, social_account_id, created_at),
  UNIQUE KEY uq_posts_platform_post (social_account_id, platform_post_id),
  KEY ix_posts_ws_content_hash (workspace_id, content_hash, created_at),
  CONSTRAINT fk_posts_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  CONSTRAINT fk_posts_sa FOREIGN KEY (social_account_id) REFERENCES social_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE post_media (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  post_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  media_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  position TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_post_media (post_id, media_id),
  KEY ix_post_media_ws (workspace_id, post_id),
  CONSTRAINT fk_pm_post FOREIGN KEY (post_id) REFERENCES platform_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_pm_media FOREIGN KEY (media_id) REFERENCES media_assets(id) ON DELETE CASCADE,
  CONSTRAINT fk_pm_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE publication_attempts (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  post_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  attempt_no SMALLINT UNSIGNED NOT NULL,
  outcome ENUM('request_sent','success','rejected','unknown','timeout','rate_limited') NOT NULL,
  http_status SMALLINT UNSIGNED NULL,
  meta_error_code SMALLINT UNSIGNED NULL,
  meta_error_subcode SMALLINT UNSIGNED NULL,
  fb_trace_id VARCHAR(64) CHARACTER SET ascii NULL,
  request_id VARCHAR(64) CHARACTER SET ascii NULL,
  backoff_ms INT UNSIGNED NULL,
  started_at DATETIME(3) NOT NULL,
  ended_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_attempt (post_id, attempt_no),
  KEY ix_attempts_ws_time (workspace_id, started_at),
  CONSTRAINT fk_att_post FOREIGN KEY (post_id) REFERENCES platform_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_att_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE idempotency_keys (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  scope VARCHAR(255) NOT NULL,              -- METHOD + route pattern (مثال: POST:/api/v1/posts/{id}/publish)
  key_value VARCHAR(128) CHARACTER SET ascii NOT NULL,
  request_body_hash CHAR(64) CHARACTER SET ascii NOT NULL,
  state ENUM('pending','in_progress','completed','conflict') NOT NULL DEFAULT 'pending',
  response_status SMALLINT UNSIGNED NULL,
  response_body_cached JSON NULL,
  resource_type VARCHAR(64) NULL,
  resource_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  expires_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_idem (workspace_id, scope, key_value),
  KEY ix_idem_expiry (expires_at),
  CONSTRAINT fk_idem_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE platform_comments (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  post_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  platform_comment_id VARCHAR(64) CHARACTER SET ascii NOT NULL,
  parent_platform_comment_id VARCHAR(64) CHARACTER SET ascii NULL,
  author_platform_id VARCHAR(128) CHARACTER SET ascii NULL,   -- PSID
  author_display_name VARCHAR(255) NULL,
  body TEXT NOT NULL,
  body_hash CHAR(64) CHARACTER SET ascii NOT NULL,
  visibility ENUM('visible','hidden','deleted','unknown') NOT NULL DEFAULT 'visible',
  classification ENUM('praise','question','complaint','threat','legal','medical','financial','dispute','spam','ambiguous','unclassified')
                 NOT NULL DEFAULT 'unclassified',
  confidence DECIMAL(4,3) NULL,
  routing ENUM('auto_reply_allowed','human_approval_required','escalated') NOT NULL DEFAULT 'human_approval_required',
  is_sensitive TINYINT(1) NOT NULL DEFAULT 0,
  platform_created_at DATETIME(3) NOT NULL,
  fetched_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at DATETIME(3) NULL,
  sync_source ENUM('webhook','polling','manual') NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_comments_platform (social_account_id, platform_comment_id),  -- منع التكرار عند إعادة المزامنة
  KEY ix_comments_ws_created (workspace_id, platform_created_at),
  KEY ix_comments_ws_routing (workspace_id, routing, visibility),
  KEY ix_comments_ws_class (workspace_id, classification, confidence),
  CONSTRAINT fk_c_sa FOREIGN KEY (social_account_id) REFERENCES social_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_c_post FOREIGN KEY (post_id) REFERENCES platform_posts(id) ON DELETE CASCADE,
  CONSTRAINT ck_confidence CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  CONSTRAINT fk_c_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE comment_replies (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  comment_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  idempotency_key_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  body TEXT NOT NULL,
  body_hash CHAR(64) CHARACTER SET ascii NOT NULL,
  status ENUM('draft','pending_approval','queued','sending','sent','failed','unknown','cancelled','blocked_sensitive')
         NOT NULL DEFAULT 'draft',
  platform_reply_id VARCHAR(64) CHARACTER SET ascii NULL,
  origin ENUM('human','ai_assisted','automation') NOT NULL,
  approved_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  sent_at DATETIME(3) NULL,
  failure_code VARCHAR(64) NULL,
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_reply_platform_id (platform_reply_id),
  KEY ix_replies_ws_status (workspace_id, status),
  KEY ix_replies_comment (comment_id, created_at),
  CONSTRAINT fk_r_comment FOREIGN KEY (comment_id) REFERENCES platform_comments(id) ON DELETE CASCADE,
  CONSTRAINT fk_r_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE approvals (
  open_subject VARCHAR(96) GENERATED ALWAYS AS (CASE WHEN status='open' THEN CONCAT(subject_type,':',subject_id) END) STORED COMMENT 'FIX-04 partial-index substitute: at most one open approval per subject',
  PRIMARY KEY (id),
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject_type ENUM('comment_reply','post','automation_rule','memory_item') NOT NULL,
  subject_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reason ENUM('sensitive','low_confidence','policy','manual_review','permission_missing') NOT NULL,
  status ENUM('open','approved','rejected','expired','cancelled') NOT NULL DEFAULT 'open',
  requested_note TEXT NULL,
  decision_note TEXT NULL,
  assigned_to CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  decided_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  decided_at DATETIME(3) NULL,
  sla_due_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  KEY ix_appr_ws_status (workspace_id, status, sla_due_at),
  KEY ix_appr_subject (workspace_id, subject_type, subject_id),
  CONSTRAINT fk_appr_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  UNIQUE KEY uq_appr_open_subject (open_subject)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_suggestions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  comment_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  prompt_version_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  suggestion_text TEXT NOT NULL,
  classification_snapshot ENUM('praise','question','complaint','threat','legal','medical','financial','dispute','spam','ambiguous','unclassified') NOT NULL,
  confidence DECIMAL(4,3) NULL,
  provider_meta_redacted JSON NULL,
  used_reply_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_sugg_ws_comment (workspace_id, comment_id, created_at),
  CONSTRAINT fk_sugg_comment FOREIGN KEY (comment_id) REFERENCES platform_comments(id) ON DELETE CASCADE,
  CONSTRAINT fk_sugg_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_prompt_versions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  prompt_key VARCHAR(64) NOT NULL,
  version_no SMALLINT UNSIGNED NOT NULL,
  template MEDIUMTEXT NOT NULL,
  output_schema JSON NOT NULL,
  status ENUM('draft','active','retired') NOT NULL DEFAULT 'draft',
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  activated_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_prompt_version (workspace_id, prompt_key, version_no),
  KEY ix_prompt_active (workspace_id, prompt_key, status),
  CONSTRAINT fk_pv_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_usage_logs (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  prompt_version_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  provider VARCHAR(64) NOT NULL,
  model VARCHAR(64) NOT NULL,
  input_tokens INT UNSIGNED NULL,
  output_tokens INT UNSIGNED NULL,
  cost_usd DECIMAL(10,6) NULL,
  latency_ms INT UNSIGNED NULL,
  outcome ENUM('success','schema_invalid','timeout','provider_error','blocked') NOT NULL,
  subject_comment_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_usage_ws_time (workspace_id, created_at),
  KEY ix_usage_ws_outcome (workspace_id, outcome),
  CONSTRAINT fk_usage_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE memory_items (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  item_type ENUM('style','dialect','tone','phrase_preferred','topic_preferred','topic_forbidden','reply_rule','example_approved','business_fact','safety_keyword') NOT NULL,
  content TEXT NOT NULL,
  provenance ENUM('confirmed','inferred') NOT NULL DEFAULT 'inferred',
  confidence DECIMAL(4,3) NULL,
  source_ref VARCHAR(255) NULL,
  status ENUM('active','disabled','archived') NOT NULL DEFAULT 'active',
  is_user_editable TINYINT(1) NOT NULL DEFAULT 1,
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  expires_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY ix_mem_ws_type (workspace_id, item_type, status),
  CONSTRAINT ck_mem_conf CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  CONSTRAINT fk_mem_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE automation_rules (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  name VARCHAR(128) NOT NULL,
  is_enabled TINYINT(1) NOT NULL DEFAULT 0,
  mode ENUM('draft_only','suggest','auto_reply_whitelist') NOT NULL DEFAULT 'suggest',
  allowlist_classifications JSON NOT NULL,   -- القائمة البيضاء فقط: praise/question/thanks
  min_confidence DECIMAL(4,3) NOT NULL DEFAULT 0.900,
  business_hours JSON NULL,
  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Riyadh',
  daily_reply_cap SMALLINT UNSIGNED NOT NULL DEFAULT 50,
  hourly_reply_cap SMALLINT UNSIGNED NOT NULL DEFAULT 10,
  created_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY ix_auto_ws_enabled (workspace_id, is_enabled),
  CONSTRAINT ck_min_conf CHECK (min_confidence >= 0 AND min_confidence <= 1),
  CONSTRAINT fk_auto_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE kill_switch_state (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  scope ENUM('platform','workspace','social_account') NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  is_stopped TINYINT(1) NOT NULL DEFAULT 0,
  reason VARCHAR(255) NULL,
  engaged_by CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  engaged_at DATETIME(3) NULL,
  released_at DATETIME(3) NULL,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kill_scope (workspace_id, scope, social_account_id),
  KEY ix_kill_ws (workspace_id, is_stopped),
  CONSTRAINT fk_kill_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE notifications (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  channel ENUM('in_app') NOT NULL DEFAULT 'in_app',
  severity ENUM('info','warning','critical') NOT NULL,
  event_code VARCHAR(128) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NULL,
  payload JSON NULL,
  user_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  read_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_notif_ws_read (workspace_id, read_at, created_at),
  CONSTRAINT fk_notif_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE activity_logs (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  actor_user_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  actor_kind ENUM('user','system','scheduler','worker') NOT NULL,
  action VARCHAR(64) NOT NULL,
  subject_type VARCHAR(64) NOT NULL,
  subject_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  result ENUM('success','failure','denied','skipped') NOT NULL,
  execution_mode ENUM('manual','automated') NOT NULL,
  before_state_redacted JSON NULL,
  after_state_redacted JSON NULL,
  request_id VARCHAR(64) CHARACTER SET ascii NULL,
  ip_hash CHAR(64) CHARACTER SET ascii NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_logs_ws_time (workspace_id, created_at),
  KEY ix_logs_ws_action (workspace_id, action, created_at),
  KEY ix_logs_subject (workspace_id, subject_type, subject_id),
  CONSTRAINT fk_logs_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE webhook_events (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  platform_event_id VARCHAR(64) CHARACTER SET ascii NULL,
  payload_hash CHAR(64) CHARACTER SET ascii NOT NULL,
  object_type ENUM('page') NOT NULL,
  field_name VARCHAR(32) NOT NULL,
  signature_status ENUM('valid','invalid','missing') NOT NULL,
  processing_status ENUM('received','processed','ignored','failed','duplicate') NOT NULL DEFAULT 'received',
  payload_redacted JSON NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  processed_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_wh_hash (payload_hash),        -- Meta تعيد الإرسال حتى 36 ساعة ⇒ منع الازدواج
  KEY ix_wh_status (processing_status, received_at),
  KEY ix_wh_account (social_account_id, received_at),
  CONSTRAINT fk_wh_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE webhook_subscriptions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subscribed_fields JSON NOT NULL,             -- ["feed"] (+ "messages" فقط إن مُنحت pages_messaging)
  status ENUM('active','missing','failed') NOT NULL DEFAULT 'missing',
  last_verified_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_whsub_account (social_account_id),
  KEY ix_whsub_ws_status (workspace_id, status),
  CONSTRAINT fk_whsub_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sync_cursors (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  resource ENUM('comments','posts','insights') NOT NULL,
  strategy ENUM('webhook','polling','hybrid') NOT NULL DEFAULT 'hybrid',
  cursor_value VARCHAR(255) NULL,
  last_run_at DATETIME(3) NULL,
  next_run_at DATETIME(3) NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cursor (social_account_id, resource),
  KEY ix_cursor_due (next_run_at),
  CONSTRAINT fk_cursor_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE metric_definitions (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  metric_key VARCHAR(64) NOT NULL,             -- الاسم في الواجهة
  api_field VARCHAR(64) CHARACTER SET ascii NULL,  -- اسم الحقل في Graph API (NULL = غير متاح)
  availability ENUM('available','conditional','unavailable','unverified') NOT NULL,
  period ENUM('day','week','days_28','lifetime') NULL,
  source_url VARCHAR(255) NOT NULL,            -- رابط Meta الرسمي
  citation_accessed_on DATE NOT NULL,          -- تاريخ الاطلاع
  notes VARCHAR(255) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_metric_key (metric_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE metric_snapshots (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  social_account_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  metric_definition_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  granularity ENUM('day','week','days_28','lifetime') NOT NULL,
  value BIGINT NOT NULL,
  api_field VARCHAR(64) CHARACTER SET ascii NOT NULL,
  source_response_hash CHAR(64) CHARACTER SET ascii NULL,
  fetched_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_snapshot (social_account_id, metric_definition_id, granularity, period_start),
  KEY ix_snap_ws_time (workspace_id, period_start),
  CONSTRAINT fk_snap_def FOREIGN KEY (metric_definition_id) REFERENCES metric_definitions(id) ON DELETE RESTRICT,
  CONSTRAINT fk_snap_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE job_dead_letters (
  id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  workspace_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL,
  queue_name VARCHAR(64) NOT NULL,
  task_name VARCHAR(128) NOT NULL,
  task_id VARCHAR(128) CHARACTER SET ascii NULL,
  payload_redacted JSON NULL,
  error_summary_redacted TEXT NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('open','retried','discarded') NOT NULL DEFAULT 'open',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  resolved_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY ix_dlq_status (status, created_at),
  KEY ix_dlq_ws (workspace_id, created_at),
  CONSTRAINT fk_dlq_ws FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS=1;
