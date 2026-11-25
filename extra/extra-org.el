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

(require 'quarter-master)

(setq quarter-master-slot-labels
      '(("04:00" "06:00" "Work time" "work")
        ("08:00" "09:30" "Train / Family" "family")
        ("12:00" "12:45" "Lunch" "self")
        ("12:45" "13:00" "Coffee" "self")
        ("13:00" "16:30" "Work time" "work")
        ("16:30" "18:00" "Train / Family" "family")
        ("19:30" "20:30" "Work time" "work")
        ("20:30" "21:00" "plan tomorrow + backstop" "self")
        ))

(provide 'extra-org)
