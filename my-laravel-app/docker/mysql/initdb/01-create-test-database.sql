-- テスト用データベースを開発用と同時に用意する。
-- Laravel の migrate はデータベース自体の作成を行わないため、ここで作る。
-- このスクリプトは MySQL の docker-entrypoint が「データディレクトリが空のとき」
-- にのみ実行する。既存ボリュームには適用されないので、追加した後は
-- `docker compose down -v` でボリュームごと作り直すこと。
CREATE DATABASE IF NOT EXISTS bookkeeper_test
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

-- MYSQL_USER で作られる app ユーザーは開発用 DB の権限しか持たないため、
-- テスト用 DB への権限を明示的に与える。
GRANT ALL PRIVILEGES ON `bookkeeper_test`.* TO 'app'@'%';
FLUSH PRIVILEGES;
