;;; local-example.el is meant to be a file that does not get used by
;;; Emacs but is a reference for setting up your own local.el with
;;; setup that you don't want committed to the .emacs.d dotfiles repo.

;; You can setup database connections by defining a
;; sql-connection-alist, it will automatically reach out to
;; authinfo.gpg to retrieve encrypted details (password etc) so they
;; aren't even stored in plaintext on disk.
;;
;; authinfo.gpg example:
;; machine localhost login alice port 5432 password my-local-password
;; machine db.example.com login bob port 5432 password super-secret-password
(setq sql-connection-alist
      '((local-postgres
         (sql-product 'postgres)
         ;; it's important to use 127.0.0.1 > localhost or Emacs will
         ;; assume you can use a socket which is not the case for
         ;; connections via cloud-sql-proxy if you are using that.
         (sql-server "127.0.0.1")
         (sql-port 5432)
         (sql-user "alice")
         (sql-database "mydb"))

        (work-postgres
         (sql-product 'postgres)
         (sql-server "db.example.com")
         (sql-port 5432)
         (sql-user "bob")
         (sql-database "sales"))))

(defvar +cloud-sql-instances
  '(("some-db"
     :instance "some-env:europe-west2:some-db"
     :port 5432))
  "Named Cloud SQL Proxy instances.")
