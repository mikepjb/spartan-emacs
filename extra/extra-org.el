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
      '(("04:00" "06:00" "Work time")
        ("12:00" "12:45" "Lunch")
        ("12:45" "13:00" "Coffee")
        ("13:00" "16:30" "Work time")
        ("19:30" "20:30" "Work time")
        ))

(setq quarter-master-tag-cycle
      '("work" "family" "travel"))

(setq quarter-master-color-rules
      '((tag   "work"    (:background "#c6e3f5" :foreground "#17394a"))
        (tag   "family"  (:background "#f4cddd" :foreground "#492436"))
        (tag   "travel"  (:background "#cbe7d3" :foreground "#193c29"))
        (tag   "lvh"     (:background "#f7d9b5" :foreground "#493018"))
        (tag   "hypalynx" (:background "#ddcdef" :foreground "#39264c"))
        (state "CURRENT" (:background "#ffe293" :foreground "#342600"))
        (state "DONE"    (:background "#d4d8dc" :foreground "#343a40"))))

(provide 'extra-org)
