(use-package sql
  :config (progn
            (setq sql-mysql-login-params
                  (append sql-mysql-login-params '(port :default 3306)))
            (setq sql-postgres-login-params
                  (append sql-postgres-login-params '(port :default 5432)))))
