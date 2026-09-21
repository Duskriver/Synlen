-- 已发布 schema 1；schema 2 仅向书架与清单添加 format。
CREATE TABLE shelf_books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_hash TEXT NOT NULL UNIQUE, file_path TEXT, cover_path TEXT,
  title TEXT NOT NULL, author TEXT NOT NULL,
  authors TEXT NOT NULL DEFAULT '[]', description TEXT,
  subjects TEXT NOT NULL DEFAULT '[]', total_chapters INTEGER NOT NULL DEFAULT 0,
  epub_version TEXT NOT NULL DEFAULT '', import_date INTEGER NOT NULL,
  direction INTEGER NOT NULL DEFAULT 0,
  current_chapter_index INTEGER NOT NULL DEFAULT 0,
  reading_progress REAL NOT NULL DEFAULT 0.0,
  chapter_scroll_position REAL DEFAULT 0.0, last_opened_date INTEGER,
  is_finished INTEGER NOT NULL DEFAULT 0, group_name TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL,
  last_synced_date INTEGER
);
CREATE TABLE book_manifests (
  id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash TEXT NOT NULL UNIQUE,
  opf_root_path TEXT NOT NULL, spine TEXT NOT NULL, toc TEXT NOT NULL,
  manifest TEXT NOT NULL, epub_version TEXT NOT NULL, last_updated INTEGER NOT NULL
);
CREATE TABLE shelf_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
  creation_date INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE word_explanations (
  id INTEGER NOT NULL PRIMARY KEY, word TEXT NOT NULL, explanation TEXT NOT NULL,
  last_updated INTEGER NOT NULL, context TEXT
);
CREATE TABLE word_pronunciations (
  id INTEGER NOT NULL PRIMARY KEY, word TEXT NOT NULL UNIQUE,
  audio_url TEXT, last_updated INTEGER NOT NULL
);
CREATE TABLE sentence_analyses (
  id INTEGER PRIMARY KEY AUTOINCREMENT, sentence TEXT NOT NULL UNIQUE,
  analysis TEXT NOT NULL, last_updated INTEGER NOT NULL
);
CREATE TABLE sentence_pronunciations (
  id INTEGER NOT NULL PRIMARY KEY, sentence TEXT NOT NULL UNIQUE,
  audio_url TEXT, last_updated INTEGER NOT NULL
);
