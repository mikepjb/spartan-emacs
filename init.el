;;; init.el -*- lexical-binding: t; -*-
(require 'seq) ;; required for repl-mode

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(electric-pair-mode 1)
(show-paren-mode 1)

(fido-vertical-mode 1)

;; (load-theme 'modus-vivendi t)
(load-theme 'flow t)
(set-face-attribute 'default nil :font "Rec Mono Linear" :height 140)

(setq
 inhibit-startup-screen t
 ns-use-native-fullscreen nil
 ring-bell-function 'ignore
 eshell-banner-message ""
 use-dialog-box nil
 use-file-dialog nil
 use-short-answers t
 split-width-threshold 160
 split-height-threshold nil
 split-window-preferred-function #'+split-window-logic
 frame-resize-pixelwise t
 load-prefer-newer t           ;; init.el > init.elc if newer
 dired-listing-switches "-lah" ;; human readable file sizes
 c-default-style '((java-mode . "+java") (other . "gnu"))
 c-basic-offset 4
 vc-follow-symlinks t
 vc-hide-up-to-date t
 vc-handled-backends '(Git)
 vc-log-show-diff nil
 vc-git-log-edit-summary-target 50
 create-lockfiles nil
 make-backup-files nil
 auto-save-default nil
 isearch-wrap-pause 'no
 compilation-always-kill t
 compilation-scroll-output t
 js-indent-level 2
 sql-input-ring-file-name (expand-file-name "sql-history" user-emacs-directory))

(setq-default
 display-fill-column-indicator-column 80
 truncate-lines t
 indent-tabs-mode nil
 tab-width 2
 standard-indent 2
 whitespace-style '(face trailing tabs empty indentation::space)
 cursor-in-non-selected-windows nil)

(c-add-style ;; custom java intendation style
 "+java"
 '("stroustrup" (c-offsets-alist . ((arglist-cont-nonempty . 0)
                                    (statement-block-intro . +)))))

(defmacro il (&rest body) `(lambda () (interactive) ,@body))
(defmacro ff (&rest path) `(il (find-file (concat ,@path))))

(defvar +context-markers
  '("Makefile" "gradlew" "pom.xml" "go.mod" "package.json" "deps.edn" ".git"))

(defmacro +with-context (&rest body)
  `(let ((default-directory
          (or (seq-some (lambda (f) (locate-dominating-file default-directory f))
                        +context-markers)
              default-directory)))
     ,@body))

(defun +other-window-or-split ()
  "If one window, split, otherwise invoke 'other-window'"
  (interactive)
  (when (= (length (window-list)) 1)
      (split-window-right))
  (other-window 1))

(defun +kill-region-or-backward-word ()
  (interactive)
  (cond ((region-active-p) (call-interactively #'kill-region))
        (t (backward-kill-word 1))))

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

(defun +select-folder (path)
  "Find file for a given PATH."
  (interactive)
  (let* ((full-path (expand-file-name path))
         (dirs (directory-files full-path nil "^[A-z]")))
    (dired (concat full-path "/" (completing-read ">> " dirs)))))

(dolist (b `(
             ("M-s" save-buffer)
             ("M-o" +other-window-or-split)
             ("M-O" delete-other-windows)
             ("M-H" ,help-map)
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
             ("M-P" ,(il (+select-folder "~/src")))
             ("C-c c" org-capture)
             ("C-c h" org-insert-heading) ;; org-toggle-heading is what I sometimes want too.
             ("M-u" undo)
             ("M-r" undo-redo)
             ("M-i" ,(il (+with-context (call-interactively 'rgrep))))
             ;; ("M-I" ,(il (+with-context (call-interactively 'occur))))
             ("M-I" imenu) ;; bad binding but also a reminder for i(ndex)menu
             ("C-c t" +ctags)
             ("C-c m" recompile)
             ("C-c M" ,(il (+with-context (call-interactively 'compile))))
             ("C-c ." +test)
             ("M-R" +repl)
             ("M-Q" sql-connect)
             ("C-w" +kill-region-or-backward-word)
             ("C-z" +terminal)
             ("C-c p" project-find-file)
             ))
  (global-set-key (kbd (car b)) (cadr b)))

;; Editing/Development -- should also include things like indentation prefs.
(add-hook 'before-save-hook #'whitespace-cleanup)

(with-eval-after-load 'grep
  (dolist (dir '("node_modules" "dist" "build" "target" ".idea"))
    (add-to-list 'grep-find-ignored-directories dir))
  (dolist (dir '(".tags" "tags" "package-lock.json"))
    (add-to-list 'grep-find-ignored-files dir)))

;; REPL access
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
    (+with-context
     (funcall (cadr entry)))))

;; Vendoring -- plan to remove
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
