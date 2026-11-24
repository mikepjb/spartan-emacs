;;; init.el -*- lexical-binding: t; -*-

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . ("jdtlsw"))))

(defun +check ()
  (interactive)
  (message "I would run either the whole test suite or a single file"))

(defun +build ()
  (interactive)
  (message "I would build the project"))

(defun +run ()
  (interactive)
  (message "I would run the project"))

(defun +repl ()
  (interactive)
  (message "REPL time!"))

(defun +format ()
  (interactive)
  (message "I would format the current file"))

(defun +audit ()
  (interactive)
  (message "I would run an audit (may be it's own mode/file)"))

(defun +cloud-sql-proxy-start ()
  "Start a Cloud SQL Proxy instance. Requires +cloud-sql-instances var to
be set, look at local-example.el for help here."
  (interactive)
  (let* ((choice
          (completing-read
           "Cloud SQL instance: "
           (mapcar #'car +cloud-sql-instances)
           nil t))
         (config (assoc choice +cloud-sql-instances))
         (instance (plist-get (cdr config) :instance))
         (port (number-to-string (plist-get (cdr config) :port)))
         (buffer (get-buffer-create
                  (format "*cloud-sql-proxy:%s*" choice))))
    (start-process
     (format "cloud-sql-proxy:%s" choice)
     buffer
     "cloud-sql-proxy"
     "--auto-iam-authn"
     "-p" port
     instance)
    (message "Started Cloud SQL Proxy for %s on port %s" choice port)))

(defun +ctags ()
  (interactive)
  (+with-project-context
   (make-process
    :name "ctags" :buffer nil
    :command '("ctags" "-eR" "-f" ".tags"
               "--exclude=node_modules" "--exclude=dist" ".")
    :sentinel (lambda (_ e) (message "ctags: %s" (string-trim e))))))

(defun +ctags-link ()
  (when-let* ((dir (locate-dominating-file default-directory ".tags")))
    (let ((tags-file (expand-file-name ".tags" dir)))
      (when (and (file-regular-p tags-file)
                 (not (member tags-file tags-table-list)))
        (visit-tags-table tags-file t)))))

;; (add-hook 'find-file-hook #'+ctags-link) ;; manually invoke for now

(provide 'extra-development)
