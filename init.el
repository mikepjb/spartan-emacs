;;; init.el -*- lexical-binding: t; -*-
;;
;; Designed for Emacs 31.1 on Mac OS 27 or Arch Linux
;;
;;; Commentary (can delete later, just organisational reference currently):
;; - ALL sections should be considered safe since they are sourced from the same folder
;; Overall layout:
;; - Emacs general config? UI config
;; - imports (i.e specific fns like REPL and navi)

;; TODO roll your own olivetti

;;;; 1. Environment

(setq read-process-output-max (* 4 1024 1024)
      load-prefer-newer t ;; init.el > init.elc if newer
      debug-on-error nil) ;; switch to t for help debugging emacs.

(load (locate-user-emacs-file "local.el") 'noerror 'nomessage)

(require 'seq) ;; use for REPL + context helpers

;;;; 2. Interface

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(fringe-mode 0)
(fido-vertical-mode 1)
(blink-cursor-mode 0)

(load-theme 'flow t)

(when-let* ((font (and (display-graphic-p)
                       (car (member "Rec Mono Linear" (font-family-list))))))
  (set-face-attribute 'default nil :family font :height 150))

(setq inhibit-startup-screen t
      ns-use-native-fullscreen nil
      ring-bell-function 'ignore
      use-dialog-box nil
      use-file-dialog nil
      use-short-answers t
      split-width-threshold 160
      split-height-threshold nil
      split-window-preferred-function #'+split-window-logic
      frame-resize-pixelwise t)

(setq-default cursor-in-non-selected-windows nil)

(defun +other-window-or-split ()
  "If one window, split, otherwise invoke 'other-window'"
  (interactive)
  (when (= (length (window-list)) 1)
      (split-window-right))
  (other-window 1))

(defun +toggle-maximized-borderless ()
  "Toggle between a normal window and a borderless maximized window."
  (interactive)
  (let ((undecorated (frame-parameter nil 'undecorated)))
    (set-frame-parameter nil 'undecorated (not undecorated))
    (toggle-frame-maximized)))

(defun +toggle-frame-fullscreen ()
  "Platform-appropriate fullscreen toggle."
  (interactive)
  (if (eq system-type 'darwin)
      (toggle-frame-fullscreen)
    (+toggle-maximized-borderless)))

;;;; 3. Editing and buffers

(electric-pair-mode 1)
(show-paren-mode 1)

(c-add-style ;; custom java intendation style
 "+java"
 '("stroustrup" (c-offsets-alist . ((arglist-cont-nonempty . 0)
                                    (statement-block-intro . +)))))

(setq c-default-style '((java-mode . "+java") (other . "gnu"))
      c-basic-offset 4
      js-indent-level 2
      isearch-wrap-pause 'no)

(setq-default
 display-fill-column-indicator-column 80
 truncate-lines t
 indent-tabs-mode nil
 tab-width 2
 standard-indent 2
 whitespace-style '(face trailing tabs empty indentation::space))

(add-hook 'before-save-hook #'whitespace-cleanup)

(defun +kill-region-or-backward-word ()
  (interactive)
  (cond ((region-active-p) (call-interactively #'kill-region))
        (t (backward-kill-word 1))))

(require 'outline)

(setq outline-minor-mode-cycle t)

(defun mx/elisp-outline-setup ()
  ;; Use only comment headings, regardless of the major mode's
  ;; outline search implementation.
  (setq-local outline-search-function nil)
  (setq-local outline-regexp ";;;+ ")
  (setq-local outline-level #'lisp-outline-level)
  (setq-local outline-default-state 4)
  (outline-minor-mode 1))

(add-hook 'emacs-lisp-mode-hook #'mx/elisp-outline-setup)

(define-key outline-minor-mode-map (kbd "<backtab>")
            #'outline-cycle-buffer)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . ("jdtlsw"))))

;;;; 4. State and persistence

(savehist-mode 1)
(save-place-mode 1)

(setq create-lockfiles nil
      make-backup-files nil
      auto-save-default nil
      custom-file (locate-user-emacs-file "custom.el"))

(load custom-file 'noerror 'nomessage)

;;;; 5. Workflows
;;;;; 5.i Project

(require 'project)

(setq project-vc-extra-root-markers
      '("Makefile" "gradlew" "pom.xml"
        "go.mod" "package.json" "deps.edn"))

(defmacro +with-project-context (&rest body)
  "Evaluate BODY at the project root, or in the current directory."
  (declare (indent 0) (debug t))
  `(let* ((project (project-current nil))
          (default-directory
           (if project
               (project-root project)
             default-directory)))
     ,@body))

(defun +select-folder (path)
  "Find file for a given PATH."
  (interactive)
  (let* ((full-path (expand-file-name path))
         (dirs (directory-files full-path nil "^[A-z]")))
    (dired (concat full-path "/" (completing-read ">> " dirs)))))

;;;;; 5.ii REPL

(defun +repl-node ()
  (interactive)
  (comint-run "node"))

(defvar +repl-config
  '(("emacs-lisp" ielm
     emacs-lisp-mode lisp-interaction-mode)
    ("python" run-python
     python-mode python-ts-mode)
    ("sqlite" sql-sqlite
     sql-mode)
    ("node" +repl-node
     typescript-mode js2-mode))
  "REPL entries as NAME, COMMAND, and matching major modes.")

(defun +repl--matches-p (entry)
  (apply #'derived-mode-p (cddr entry)))

(defun +repl--choose (entries)
  (let ((name (completing-read
               "REPL: "
               (mapcar #'car entries)
               nil t)))
    (assoc name entries)))

(defun +repl (&optional choose)
  "Start the REPL associated with the current buffer.
  With a prefix argument, choose from all configured REPLs."
  (interactive "P")
  (let* ((entries (if choose
                      +repl-config
                    (seq-filter #'+repl--matches-p
                                +repl-config)))
         (entry
          (cond
           ((null entries)
            (user-error "No REPL configured for %s" major-mode))
           ((null (cdr entries))
            (car entries))
           (t
            (+repl--choose entries)))))
    (other-window-prefix)
    (+with-project-context
     (funcall (cadr entry)))))

;;;;; 5.iii Terminal

(setq eshell-banner-message "")

;;;;; 5.iv Compilation and testing

;;;;; 5.v File management

(setq dired-listing-switches "-lah") ;; human readable file sizes

(defun mx/speedbar-toggle ()
  (interactive)
  (speedbar-window)
  (when-let* ((buf (bound-and-true-p speedbar-buffer))
              (win (get-buffer-window buf)))
    (select-window win)))

;;;;; 5.v Version control

(setq vc-follow-symlinks t
      vc-hide-up-to-date t
      vc-handled-backends '(Git)
      vc-log-show-diff nil
      vc-git-log-edit-summary-target 50)

;; (setq vc-dir-auto-hide-up-to-date 'revert
;;       vc-dir-save-some-buffers-on-revert t)
;; (setq vc-git-log-switches '("--name-status")) ;; show affected files in git log view

(defun +vc-pr ()
  (interactive)
  (shell-command
   (format "gh pr %s"
           (pcase (completing-read "Stage: " '("Draft" "Review" "View") nil t)
             ("Draft" "create --draft --fill")
             ("Review" "create --fill")
             ("View" "view --web")))))

;;;;; 5.vi Databases

(setq sql-input-ring-file-name
      (expand-file-name "sql-history" user-emacs-directory))

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

;;;;; 5.vii Search

(when (executable-find "rg")
  (setq xref-search-program 'ripgrep)
  (setq grep-command "rg -nS --no-heading ")
  (setq grep-find-template "rg <C> --null -nH -e <R> <D>"))

(with-eval-after-load 'grep
  (dolist (dir '("node_modules" "dist" "build" "target" ".idea"))
    (add-to-list 'grep-find-ignored-directories dir))
  (dolist (dir '(".tags" "tags" "package-lock.json"))
    (add-to-list 'grep-find-ignored-files dir)))

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

(add-hook 'find-file-hook #'+ctags-link)

;;;;; 5.viii Documentation

(setenv "MANROFFOPT" "-P-c")
(setq Man-notify-method 'pushy pop-up-frames nil) ;; avoid creating frames for man

;;;;; 5.ix Org

(use-package org
  :ensure nil
  :hook ((org-mode . org-indent-mode))
  :bind (:map org-mode-map
              ("M-RET" . nil))
  :custom
  (org-modules nil)
  (org-ellipsis " ▼")
  (org-cycle-separator-lines 1)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "CURRENT(c)" "WAITING(w)"
               "|" "DONE(d!)")))
  (org-log-done 'time)
  (org-log-into-drawer t)
  (org-startup-folded 'show3levels)
  (org-agenda-span 14)
  (org-agenda-start-on-weekday nil)
  (org-agenda-restore-windows-after-quit t)
  (org-archive-location "~/.notes/archive.org::* From %s")
  (org-directory "~/.notes")
  (org-agenda-files '("~/.notes"))
  (org-refile-targets
   '((nil :maxlevel . 3) ("~/.notes/archive.org" :maxlevel . 3)))
  (org-agenda-sorting-strategy '(todo-state-down priority-up))
  (org-agenda-custom-commands
   '(("a" "Agenda + Unscheduled TODOs"
      ((agenda "")
       (todo "TODO|NEXT|CURRENT"
             ((org-agenda-skip-function
               '(org-agenda-skip-entry-if 'scheduled 'deadline 'timestamp))
              (org-agenda-overriding-header "Unscheduled TODOs")))))))
  (org-icalendar-include-todo nil)
  (org-icalendar-use-scheduled '(event-if-not-todo event-if-todo))
  (org-icalendar-use-deadline '(event-if-not-todo event-if-todo)))

(advice-add 'org-refile :after 'org-save-all-org-buffers)

(defun +org-clock-toggle ()
  (interactive)
  (if (org-clocking-p) (org-clock-out)
    (if (and (eq major-mode 'org-mode) (org-entry-is-todo-p))
        (org-todo "CURRENT") (org-clock-in-last))))

(defun +org-clock-todo-change ()
  (cond ((string= org-state "CURRENT") (org-clock-in))
        ((org-clocking-p) (org-clock-out))))

(defun +org-archive-done ()
  "Archive all DONE entries in the current Org file."
  (interactive)
  (org-map-entries
   (lambda ()
     (org-archive-subtree))
   "/DONE"
   'file))

;;;;; 5.x LLMs


(require 'auth-source)
(require 'json)

(defvar navi-config
  '(:endpoint "http://localhost:7777/v1/chat/completions"
    :model "qwen3.5-9b"
    :auth-host nil))

(defvar navi-system-prompt
  "You are an expert senior software engineer. Your core expertise
is Clojure, but you are highly proficient in Go, JavaScript, TypeScript,
and Java.

Provide elite, production-grade code snippets, concise reviews, or direct
technical answers. Always default to Clojure unless another language is
explicitly specified.

CRITICAL DIRECTIVES:
1. Focus exclusively on idiomatic solutions, stable/standard libraries, and modern best practices.
2. Be direct, dense, and objective. Strip out conversational filler, introductions, greetings, and concluding remarks.
3. Deliver answers optimized for a terminal UI: prioritize clean code blocks over long prose explanations
")
(defvar navi-buffer-name "*navi*")
(defun navi--api-key (a)
  nil)

(defun navi--sentinel (proc _event)
  (when (memq (process-status proc) '(exit signal))
    (let* ((curl-buf (process-buffer proc))
           (output (with-current-buffer curl-buf (buffer-string)))
           (question (process-get proc :question))
           (content
            (or (ignore-errors
                  (let* ((obj (json-parse-string output :object-type 'alist))
                         (choices (alist-get 'choices obj)))
                    (alist-get 'content
                               (alist-get 'message (aref choices 0)))))
                (format "[no content]\n%s" output)))
           (buf (get-buffer-create navi-buffer-name)))
      (with-current-buffer buf
        (unless (eq major-mode 'markdown-mode) (markdown-mode))
        (goto-char (point-max))
        (insert (if (bobp) "" "\n\n---\n\n")
                "````user\n" question "\n````\n\n"
                content "\n"))
      (kill-buffer curl-buf)
      (message "navi: response ready (M-x navi-view)"))))

;;;###autoload
(defun navi (input &optional context context-lang)
  (interactive
   (let* ((region (and (use-region-p)
                       (buffer-substring-no-properties
                        (region-beginning) (region-end))))
          (lang (and region
                     (replace-regexp-in-string
                      "-\\(ts-\\)?mode\\'" "" (symbol-name major-mode)))))
     (list (read-string "navi> ") region lang)))
  (let* ((cfg navi-config)
         (endpoint (plist-get cfg :endpoint))
         (model (plist-get cfg :model))
         (key (navi--api-key (plist-get cfg :auth-host)))
         (full (if context
                   (format "```%s\n%s\n```\n\n%s"
                           (or context-lang "") context input)
                 input))
         (payload
          (json-encode
           `((model . ,model)
             (messages . [((role . "system") (content . ,navi-system-prompt))
                          ((role . "user") (content . ,full))]))))
         (proc (make-process
                :name "navi"
                :buffer (generate-new-buffer " *navi-curl*")
                :noquery t :coding 'utf-8 :connection-type 'pipe
                :command `("curl" "-sS" "-X" "POST"
                           "-H" "Content-Type: application/json"
                           ,@(when key (list "-H" (concat "Authorization: Bearer " key)))
                           "--data-binary" "@-" ,endpoint)
                :sentinel #'navi--sentinel)))
    (process-put proc :question full)
    (process-send-string proc payload)
    (process-send-eof proc)
    (message "navi: query sent")))

(defun navi-view ()
  (interactive)
  (let ((buf (get-buffer navi-buffer-name)))
    (if buf (pop-to-buffer buf)
      (message "navi: no responses yet"))))

(defun navi-server ()
  "Start llama-server in the background."
  (interactive)
  (make-process
   :name "navi-server"
   :buffer (get-buffer-create "*navi-server*")
   :command `("llama-server"
              "-m" ,(expand-file-name
                     "~/models/Qwen3.5-4B-UD-Q3_K_XL.gguf")
              "--jinja"
              "--host" "127.0.0.1"
              "--port" "7777"
              "-c" "16384"
              "--metrics"
              "-ngl" "-1"
              "-np" "1"
              "--temp" "0.6"
              "--top-p" "0.95"
              "--top-k" "20"
              "--min-p" "0.00"
              "--presence-penalty" "0.0"
              "--repeat-penalty" "1.0")))

;;;; 6. Global Bindings

(defmacro il (&rest body) `(lambda () (interactive) ,@body))
(defmacro ff (&rest path) `(il (find-file (concat ,@path))))

(dolist (b `(("M-s" save-buffer)
             ("M-o" +other-window-or-split)
             ("M-O" delete-other-windows)
             ("M-H" ,help-map)
             ("M-D" duplicate-dwim)
             ("M-g v" vc-dir-root)
             ("M-g l" vc-print-root-log)
             ("M-RET" +toggle-frame-fullscreen)
             ("M--" ,(il (set-frame-size nil 160 55)))
             ("C-;" hippie-expand)
             ("M-;" completion-at-point)
             ("M-/" comment-line)
             ("M-p" backward-paragraph)
             ("M-n" forward-paragraph)
             ("M-F" query-replace-regexp)
             ("M-K" kill-whole-line)
             ("C-h" delete-backward-char)
             ("C-j" newline) ;; autoindents
             ("M-j" ,(il (join-line -1)))
             ("C-c i" ,(ff user-emacs-directory "init.el"))
             ("C-c l" ,(ff user-emacs-directory "local.el"))
             ("C-c n" ,(ff (getenv "HOME") "/.notes/index.org"))
             ("C-c a" ,(il (org-agenda nil "a")))
             ;; ("M-p" project-find-file)
             ("M-P" ,(il (+select-folder "~/src")))
             ("C-c c" org-capture)
             ("C-c h" org-insert-heading) ;; org-toggle-heading is what I sometimes want too.
             ("M-u" undo)
             ("M-r" undo-redo)
             ;; ("M-I" ,(il (+with-project-context (call-interactively 'occur))))
             ("M-i" imenu) ;; bad binding but also a reminder for i(ndex)menu
             ("M-I" ,(il (+with-project-context (call-interactively 'rgrep))))
             ("C-c t" +ctags)
             ("C-c m" recompile)
             ("C-c M" ,(il (+with-project-context (call-interactively 'compile))))
             ("C-c ." +test)
             ("M-R" +repl)
             ("M-Q" sql-connect)
             ("C-w" +kill-region-or-backward-word)
             ("C-z" +terminal)))
  (global-set-key (kbd (car b)) (cadr b)))

;; vc reference
;; - g - refresh status
;; - x - hide clean/ignored entries
;; - m/u - mark/unmark files
;; - i - register new files
;; - v - start a commit
;; - l/L - show history for the selected file
;; - P - push current branch
;; - + - pull current branch (set rebase.true in git config too

;;; Vendoring -- plan to remove
(add-to-list 'load-path (expand-file-name "vendor" user-emacs-directory))

(autoload 'go-mode "go-mode" nil t)
(autoload 'clojure-mode "clojure-mode" nil t)
(autoload 'clojurescript-mode "clojure-mode" nil t)
(autoload 'clojurec-mode "clojure-mode" nil t)
(autoload 'zig-mode "zig-mode" nil t)
(autoload 'markdown-mode "markdown-mode" nil t)
(autoload 'hcl-mode "hcl-mode" nil t)
(autoload 'terraform-mode "terraform-mode" nil t)
(autoload 'typescript-mode "typescript-mode" nil t)

(dolist (entry
         '(("\\.go\\'"                 . go-mode)
           ("\\.clj\\'"                . clojure-mode)
           ("\\.cljs\\'"               . clojurescript-mode)
           ("\\.cljc\\'"               . clojurec-mode)
           ("\\.edn\\'"                . clojure-mode)
           ("\\.zig\\'"                . zig-mode)
           ("\\.\\(?:md\\|markdown\\)\\'" . markdown-mode)
           ("\\.hcl\\'"                . hcl-mode)
           ("\\.tf\\'"                 . terraform-mode)
           ("\\.tfvars\\'"             . terraform-mode)
           ("\\.[cm]?ts\\'"            . typescript-mode)
           ("\\.[cm]?js\\'"            . js-mode)))
  (add-to-list 'auto-mode-alist entry))
