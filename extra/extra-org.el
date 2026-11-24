;;; init.el -*- lexical-binding: t; -*-

(setq org-modules nil
      org-src-window-setup 'current-window ;; table.el edits in same window
      org-ellipsis " ▼"
      org-cycle-separator-lines 1
      org-log-done 'time
      org-log-into-drawer t

      org-agenda-span 14
      org-agenda-start-on-weekday nil
      org-agenda-restore-windows-after-quit t

      org-directory "~/.notes"
      org-agenda-files '("~/.notes"))

(advice-add 'org-refile :after 'org-save-all-org-buffers)
(add-hook 'org-mode-hook #'org-indent-mode)

(provide 'extra-org)
