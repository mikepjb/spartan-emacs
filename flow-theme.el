;;; flow-theme.el, Quiet theme + synthwave accents  -*- lexical-binding: t; -*-
(deftheme flow "Designed to encourage quiet focus")

(defcustom flow-mode 'dark
  "Theme variant. Either 'dark or 'light"
  :type '(choice (const :tag "Dark" dark)
                 (const :tag "Light" light))
  :group 'flow)

(defun flow-toggle-theme ()
  (interactive)
  (setq flow-mode (if (eq flow-mode 'dark) 'light 'dark))
  (load-theme 'flow t))

(defface font-lock-paren-face nil "" :group 'font-lock-faces)
(defface font-lock-bracket-face nil "" :group 'font-lock-faces)
(defface font-lock-brace-face nil "" :group 'font-lock-faces)
(defface org-current nil "" :group 'font-lock-faces)
(defface org-next nil "" :group 'font-lock-faces)

(let* ((dark-p (eq flow-mode 'dark))
       ;; Color organised as a pyramid for attention, with small areas
       ;; of interest down to the main bulk of the view. This should
       ;; also dictate color choice in UI i.e you don't want to draw
       ;; the eye with a yellow for truncation symbols in the fringes.

       ;; Top layer, high interest - buffer names, errors/warnings,
       ;; prompts, cursor.
       (yellow         (if dark-p "#f9e2af" "#df8e1d")) ; catppucin mocha yellow
       (magenta        (if dark-p "#cba6f7" "#8839ef")) ; purple
       (cyan           (if dark-p "#89dceb" "#006599")) ; muted cyan
       (bright-magenta (if dark-p "#ff00ff" "#9b009c"))       ; pure neon magenta - cursor

       ;; Middle layer, low but significant interest, function names
       ;; etc that appear frequently.
       (lavender       (if dark-p "#b7bdf8" "#404cbc"))
       (teal           (if dark-p "#94e2d5" "#006c73"))
       (sapphire       (if dark-p "#74c7ec" "#006b7f"))

       ;; Main foreground/background used for the rest of the view.
       (fg             (if dark-p "#cdd6f4" "#4c4f69"))
       (fg+            (if dark-p "#bac2de" "#5c5f77"))
       (fg++           (if dark-p "#a6adc8" "#6c6f85"))
       (fg+++          (if dark-p "#6c7086" "#9ca0b0"))
       (fg++++         (if dark-p "#585b70" "#8c8fa1"))
       (bg             (if dark-p "#0a0a10" "#eff1f5"))
       ;; +colors are darker/lighter depending on theme for consistent depth effect.
       (bg+    (if dark-p "#11111b" "#eaecf1"))
       (bg++   (if dark-p "#181825" "#e5e8ec"))
       (bg+++  (if dark-p "#1e1e2e" "#e0e3e7"))
       (bg++++ (if dark-p "#313244" "#d4d7dc"))
       (bg+green       (if dark-p "#0c1412" "#d1fde6")) ;; for git diffs
       (bg+green+       (if dark-p "#0e211c" "#bffbdc"))
       (bg+red         (if dark-p "#1f0809" "#f4d3d5"))
       (bg+red+         (if dark-p "#350f11" "#ecb9bc"))

       ;; Rare colors, usually for ansi/terminal
       (red            (if dark-p "#eba0ac" "#e64553")) ; catppucin mocha maroon
       (green          (if dark-p "#a6e3a1" "#40a02b")) ; muted green
       (blue           (if dark-p "#89b4fa" "#1e66f5")) ; catppucin mocha sapphire

       ;; Semantic colors set from the above
       (match yellow))

  (apply
   #'custom-theme-set-faces 'flow
   (mapcar
    (lambda (s) `(,(car s) ((t ,(cdr s)))))
    `((default :background ,bg :foreground ,fg)
      (cursor :background ,bright-magenta :foreground ,bg)
      (region :background ,bg++)
      (fringe :background ,bg :foreground ,bg+++)
      (minibuffer-prompt :foreground ,teal)
      (hl-line :background ,bg+++)

      (mode-line :background ,bg :foreground ,fg
                 :box (:line-width 1 :color ,bg++++ :style nil))
      (mode-line-inactive :background ,bg :foreground ,fg
                          :box (:line-width 1 :color ,bg++++ :style nil))
      (mode-line-buffer-id :foreground ,cyan :weight bold)
      (mode-line-emphasis :foreground ,teal)
      (mode-line-highlight :foreground ,teal)

      (vertical-border :foreground ,bg++++)
      (link :foreground ,lavender :underline t)
      (escape-glyph :foreground ,bg+)
      (icon :foreground ,yellow)
      (fill-column-indicator :foreground ,bg+++)

      (success :foreground ,green)
      (info :foreground ,lavender)
      (match :background ,bg :foreground ,match)
      (isearch :background ,match :foreground ,bg)
      (lazy-highlight :background ,match :foreground ,bg)
      (query-replace :background ,green :foreground ,bg)

      (dired-directory :foreground ,teal)
      (dired-executable :foreground ,sapphire)
      (dired-symlink :foreground ,lavender)
      (dired-marked :foreground ,yellow :weight bold)

      (compilation-info :foreground ,teal)
      (compilation-warning :foreground ,yellow)
      (compilation-error :foreground ,magenta)

      (grep-hit-face :foreground ,magenta)
      (grep-match-face :background ,match :foreground ,bg)

      (diff-added :foreground ,fg :background ,bg+green)
      (diff-refine-added :background ,bg+green+)
      (diff-removed :background ,bg+red)
      (diff-refine-removed :background ,bg+red+)
      (diff-changed :foreground ,yellow)
      (diff-header :foreground ,sapphire)
      (diff-file-header :foreground ,cyan :weight bold)

      (completions-highlight :foreground ,fg :background ,bg+++)
      (icomplete-selected-match :foreground ,fg :background ,bg++++)
      (completions-annotations :foreground ,teal)
      (completions-common-part :foreground ,fg++)
      (completions-first-difference :foreground ,fg+++)

      (font-lock-comment-face :foreground ,fg++)
      (font-lock-string-face :foreground ,teal)
      (font-lock-keyword-face :foreground ,fg)
      (font-lock-function-name-face :foreground ,sapphire)
      (font-lock-variable-name-face :foreground ,lavender)
      (font-lock-type-face :foreground ,fg)
      (font-lock-constant-face :foreground ,sapphire)
      (font-lock-builtin-face :foreground ,fg++)

      (error :foreground ,magenta)
      (warning :foreground ,yellow)

      (line-number :foreground ,fg+++)
      (line-number-current-line :foreground ,fg++ :background ,bg+++)

      (markdown-header-face-1 :height 1.6 :weight bold :foreground ,fg
                              :box (:line-width (-1 . 32) :color ,bg))
      (markdown-header-face-2 :height 1.3 :slant italic :foreground ,fg
                              :box (:line-width (-1 . 20) :color ,bg))
      (markdown-header-face-3 :height 1.0 :weight bold :foreground ,fg
                              :box (:line-width (-1 . 12) :color ,bg))
      (markdown-header-face-4 :height 1.0 :weight bold :foreground ,fg)
      (org-level-1 :height 1.6 :weight bold :foreground ,fg
                   :box (:line-width (-1 . 32) :color ,bg))
      (org-level-2 :height 1.3 :slant italic :foreground ,fg
                   :box (:line-width (-1 . 20) :color ,bg))
      (org-level-3 :height 1.0 :foreground ,fg
                   :box (:line-width (-1 . 12) :color ,bg))
      (org-level-4 :height 1.0 :foreground ,fg)
      (org-level-5 :height 1.0 :foreground ,fg)
      (org-level-6 :height 1.0 :foreground ,fg)

      (org-ellipsis :foreground ,fg+++ :underline nil)
      (org-headline-done :foreground ,fg+++ :underline nil :strike-through t)
      (org-done :foreground ,green :underline nil)
      (org-todo :foreground ,sapphire :underline nil :inherit fixed-pitch)
      (org-next :foreground ,yellow :underline nil :inherit fixed-pitch)
      (org-current :foreground ,green :underline nil :inherit fixed-pitch)
      (org-tag :foreground ,fg+++ :underline nil :inherit fixed-pitch)
      (org-agenda-structure :foreground ,lavender)
      (org-scheduled-previously :foreground ,yellow)
      (org-hide :foreground ,bg :inherit fixed-pitch)
      (org-block :inherit fixed-pitch)
      (org-block-begin-line :inherit fixed-pitch)
      (org-block-end-line :inherit fixed-pitch)
      (org-code :inherit fixed-pitch)
      (org-verbatim :inherit fixed-pitch)
      (org-special-keyword :foreground ,fg+++ :inherit fixed-pitch)
      (org-date :foreground ,teal :inherit fixed-pitch)
      (org-checkbox :inherit fixed-pitch)
      (org-meta-line :inherit fixed-pitch)
      (org-drawer :inherit fixed-pitch)

      (markdown-markup-face :background ,bg+++)

      (eshell-prompt :foreground ,yellow)
      (sh-quoted-exec :foreground ,fg)
      (ansi-color-black :foreground ,bg :background ,fg)
      (ansi-color-red :foreground ,red :background ,bg)
      (ansi-color-green :foreground ,green :background ,bg)
      (ansi-color-yellow :foreground ,yellow :background ,bg)
      (ansi-color-blue :foreground ,blue :background ,bg)
      (ansi-color-magenta :foreground ,magenta :background ,bg)

      (font-lock-paren-face :foreground ,lavender)
      (font-lock-bracket-face :foreground ,sapphire)
      (font-lock-brace-face :foreground ,teal))))

  ;; When fringe-mode is 0, I am not sure the truncation chars are
  ;; fontified so we set this manually and update the glyph while
  ;; we're at it.
  (set-display-table-slot
   standard-display-table 0
   (make-glyph-code ?… 'escape-glyph))

  (defun flow-delimiters-enable ()
    (font-lock-add-keywords
     nil
     '(("(\\|)" 0 'font-lock-paren-face t)
       ("\\[\\|\\]" 0 'font-lock-bracket-face t)
       ("{\\|}" 0 'font-lock-brace-face t))
     'append)
    (font-lock-flush))

  (add-hook 'prog-mode-hook #'flow-delimiters-enable)

  (defun flow/truncate-buffer-name ()
    (let* ((name (if buffer-file-name
                     (abbreviate-file-name buffer-file-name)
                   (buffer-name)))
           (max-len (/ (window-width) 3)))
      (if (<= (length name) max-len)
          name
        (concat "<" (substring name (- (length name) (- max-len 1)))))))

  (setq-default
   mode-line-format
   `(" "
     (:eval (propertize
             (flow/truncate-buffer-name)
             'face
             '(:foreground ,cyan :weight bold)))
     " [%*]"
     mode-line-format-right-align
     (:eval (concat (if (and (fboundp 'org-clocking-p) (org-clocking-p))
                        (propertize (format " ● %s"
                                            (org-duration-from-minutes
                                             (org-clock-get-clocked-time)))
                                    'face '(:foreground ,cyan :weight bold))
                      (propertize " ○" 'face '(:foreground ,cyan :weight bold)))
                    (propertize " | " 'face '(:foreground ,bg++++))))
          (:eval (when (and (boundp 'vc-mode) vc-mode)
              (concat (replace-regexp-in-string "^ Git[-:]" "" vc-mode)
                      (propertize " | " 'face '(:foreground ,bg++++)))))
     "%l:%c"
     (:eval (propertize " | " 'face '(:foreground ,bg++++)))
     (:eval (when-let ((proc (get-buffer-process (current-buffer))))
              (propertize (format "[%s] " (process-name proc))
                          'face '(:foreground ,bright-magenta :weight bold))))
     (:eval (replace-regexp-in-string "-mode$" "" (symbol-name major-mode)))
     " ")))

(provide-theme 'flow)
