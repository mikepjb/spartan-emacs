;;; init.el -*- lexical-binding: t; -*-

;; TODO
;; - transparency with video is great tbh. or.. transparency/background kinda thing?
;; - compilation jump tos
;; - still need to implement run/check/repl/build/format
;; - mac os maximise?!?
;; - vc git push with passphrase.. authinfo.gpg?

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(fringe-mode 0)
(electric-pair-mode 1)
(fido-vertical-mode 1)
(blink-cursor-mode 0)
(savehist-mode 1)
(save-place-mode 1)

(c-add-style ;; custom java intendation style
 "+java"
 '("stroustrup" (c-offsets-alist . ((arglist-cont-nonempty . 0)
                                    (statement-block-intro . +)))))

(setq
 inhibit-startup-screen t
 ns-use-native-fullscreen nil
 use-short-answers t
 ring-bell-function 'ignore
 c-default-style '((java-mode . "+java") (other . "gnu"))
 c-basic-offset 4
 js-indent-level 2
 isearch-wrap-pause 'no
 create-lockfiles nil
 make-backup-files nil
 auto-save-default nil
 project-vc-extra-root-markers
 '("package.json" "go.mod" "zig.build" "deps.edn" "gradle.build" "pom.xml"))

(setq-default
 display-fill-column-indicator-column 80
 cursor-in-non-selected-windows nil
 truncate-lines t
 indent-tabs-mode nil
 tab-width 2
 standard-indent 2
 whitespace-style '(face trailing tabs empty indentation::space))

(defconst +path
  '("$HOME/src/llama.cpp/build/bin" ; llama.cpp built from source
    "$HOME/.local/bin" ; User bin dir
    "/opt/homebrew/bin" ; Mac OS Homebrew package manager
    "/usr/local/go/bin"
    "$HOME/go/bin"
    "$HOME/.deno/bin"
    "$HOME/.npm/bin"
    "/bin"
    "/sbin" ; Mac OS puts some binaries in here like `lsof`
    "/usr/local/bin"
    "/usr/bin"
    "/usr/local/sbin"
    "$HOME/.cargo/bin"))

(let ((paths (mapcar #'substitute-in-file-name +path)))
  (setenv "PATH" (string-join paths ":"))
  (setq exec-path paths))

(when (executable-find "rg")
  (setq xref-search-program 'ripgrep)
  (setq grep-command "rg -nS --no-heading ")
  (setq grep-find-template "rg <C> --null -nH -e <R> <D>"))

(with-eval-after-load 'grep
  (dolist (dir '("node_modules" "dist" "build" "target" ".idea"))
    (add-to-list 'grep-find-ignored-directories dir))
  (dolist (dir '(".tags" "tags" "package-lock.json"))
    (add-to-list 'grep-find-ignored-files dir)))

(add-hook 'before-save-hook #'whitespace-cleanup)

(when (display-graphic-p)
  (set-face-attribute 'default nil :family "Rec Mono Linear" :height 140))

(dolist (k '(mac-command-modifier x-super-keysym))
  (when (boundp k) (set k 'meta)))

(load-theme 'flow t)

;; Mac OS seems to have a bug here that messes up maximise when hiding
;; the title bar.
(when (not (eq window-system 'ns))
  (add-hook 'window-size-change-functions
            #'frame-hide-title-bar-when-maximized))

(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)
(load (locate-user-emacs-file "local.el") 'noerror 'nomessage)

(defmacro il (&rest body) `(lambda () (interactive) ,@body))
(defmacro ff (&rest path) `(il (find-file (concat ,@path))))

(defmacro +with-project (&rest body)
  `(let* ((project (project-current nil))
          (default-directory
           (if project (project-root project)
             default-directory)))
     ,@body))

(defun +select-folder (path)
  "Find file for a given PATH."
  (interactive)
  (let* ((full-path (expand-file-name path))
         (dirs (directory-files full-path nil "^[A-z]")))
    (dired (concat full-path "/" (completing-read ">> " dirs)))))

(defun +kill-region-or-backward-word ()
  (interactive)
  (cond ((region-active-p) (call-interactively #'kill-region))
        (t (backward-kill-word 1))))

(dolist (b `(("M-s" save-buffer)
             ("M-o" ,(il (when (= (length (window-list)) 1)
                           (split-window-right))
                         (other-window 1)))
             ("M-O" delete-other-windows)
             ("M-P" imenu)
             ("M-i" project-find-file)
             ("C-c M-i" ,(il (project-find-file t)))
             ("M-I" ,(il (+select-folder "~/src")))
             ("M-n" forward-paragraph)
             ("M-p" backward-paragraph)
             ("M-g v" vc-dir-root)
             ("M-H" ,help-map)
             ("M-G" ,(il (+with-project (call-interactively 'rgrep))))
             ("M-j" ,(il (join-line -1)))
             ("C-h" delete-backward-char)
             ("C-j" newline) ;; autoindents
             ("C-z" ,(il (ansi-term "bash")))
             ("M-g a" +pi)
             ("C-w" +kill-region-or-backward-word)
             ("M-RET" toggle-frame-maximized)
             ("M-t" +check)
             ("M-g q" quarter-master)
             ("M-K" kill-whole-line)
             ("M-/" comment-line)
             ("C-," switch-to-prev-buffer) ;; really we want vim C-i/C-o
             ("C-." switch-to-next-buffer)
             ("C-c i" ,(ff user-emacs-directory "init.el"))
             ("C-c l" ,(ff user-emacs-directory "local.el"))
             ("C-c n" ,(ff (getenv "HOME") "/.notes/planner.org"))))
  (global-set-key (kbd (car b)) (cadr b)))

(with-eval-after-load 'term
  (define-key term-raw-map (kbd "M-o") #'other-window)
  (define-key term-raw-map (kbd "M-:") #'eval-expression)
  (define-key term-raw-map (kbd "M-x") #'execute-extended-command))

(add-to-list 'load-path (locate-user-emacs-file "extra/"))
(require 'extra-development)
(require 'extra-org)
(require 'extra-language)
