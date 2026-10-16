-- TaskOra sync table. Import once in phpMyAdmin (or open install.php once).
CREATE TABLE IF NOT EXISTS taskora_docs (
  uid        VARCHAR(128) NOT NULL,
  col        VARCHAR(32)  NOT NULL,
  doc_id     VARCHAR(64)  NOT NULL,
  data       MEDIUMTEXT   NULL,
  deleted    TINYINT(1)   NOT NULL DEFAULT 0,
  updated_at BIGINT       NOT NULL,
  PRIMARY KEY (uid, col, doc_id),
  KEY by_user_time (uid, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
