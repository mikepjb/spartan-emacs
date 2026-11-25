;;; init.el -*- lexical-binding: t; -*-

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . ("jdtlsw"))))

(defvar +format-commands
  '((go-mode        "goimports" "-w")
    (zig-mode       "zig"       "fmt")
    (terraform-mode "terraform" "fmt")
    (yaml-mode      "prettier"  "--write")
    (js-json-mode   "prettier"  "--write")
    (clojure-mode   "cljfmt"    "fix")))

(defun +format-sentinel (process event)
  (when (and (memq (process-status process) '(exit signal))
             (not (zerop (process-exit-status process))))
    (message "%s: %s (see *format-log*)"
             (car (process-command process))
             (string-trim-right event))))

(defun +format ()
  (interactive)
  (when (and buffer-file-name (not (file-remote-p buffer-file-name)))
    (when-let ((command (cdr (assq major-mode +format-commands))))
      (auto-revert-mode 1)
      (condition-case err
          (make-process
           :name "format"
           :buffer "*format-log*"
           :command (append command (list buffer-file-name))
           :connection-type 'pipe
           :noquery t
           :sentinel #'+format-sentinel)
        (file-error
         (message "Could not start %s: %s"
                  (car command) (error-message-string err)))))))

(add-hook 'after-save-hook #'+format)

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
