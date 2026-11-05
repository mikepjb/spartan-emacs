;;; init.el -*- lexical-binding: t; -*-
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(electric-pair-mode 1)
(show-paren-mode 1)

(load-theme 'modus-vivendi t)
(set-face-attribute 'default nil :font "Rec Mono Linear" :height 140)

(defmacro il (&rest body) `(lambda () (interactive) ,@body))
(defmacro ff (&rest path) `(il (find-file (concat ,@path))))

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
