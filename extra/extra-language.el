;;; extra-language.el --- Small modes for a mostly unfontified Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Load this file once from init.el.  Filename associations are at the end.
;; Each section owns its indentation.  Add formatters to individual mode
;; hooks if desired.  All editing support here uses stock Emacs Lisp.

;;; Code:

;; Only cursor handling is common.  Each mode computes its own column.
(defun extra-language--apply-column (column)
  (when column
    (if (<= (current-column) (current-indentation))
        (indent-line-to column)
      (save-excursion (indent-line-to column)))))

;;; Go

(defvar go-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?` "\"" table)
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    table))

(defun extra-go--raw-backslashes (start end)
  ;; Ordinary strings and runes allow escapes.  Backticks do not.
  (goto-char start)
  (while (search-forward "\\" end t)
    (let ((pos (1- (point))))
      (when (eq (nth 3 (save-excursion (syntax-ppss pos))) ?`)
        (put-text-property pos (1+ pos) 'syntax-table (string-to-syntax "."))))))

(defun extra-go-indent-line ()
  (let ((column
         (save-excursion
           (back-to-indentation)
           (let* ((state (syntax-ppss))
                  (opener (nth 1 state))
                  (flush (or (memq (char-after) '(?\) ?\] ?\}))
                             (looking-at-p "\\(?:case\\_>\\|default[ \t]*:\\)"))))
             (cond ((or (nth 3 state) (nth 4 state)) nil)
                   ((null opener) 0)
                   (t (goto-char opener)
                      (+ (current-indentation) (if flush 0 tab-width))))))))
    (extra-language--apply-column column)))

(define-derived-mode go-mode prog-mode "Go"
  "Edit Go with tab-indented blocks and outdented case labels."
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 8)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local syntax-propertize-function #'extra-go--raw-backslashes)
  (setq-local indent-line-function #'extra-go-indent-line))

;;; Zig

(defvar zig-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?/ ". 12b" table)
    (modify-syntax-entry ?\n "> b" table)
    table))

(defun extra-zig--string-lines (start end)
  ;; Multiline literal lines are opaque to delimiter matching.
  (goto-char start)
  (while (re-search-forward "^[ \t]*\\(\\\\\\\\\\)" end t)
    (let ((pos (match-beginning 1)))
      (put-text-property pos (1+ pos) 'syntax-table (string-to-syntax "< b")))))

(defun extra-zig-indent-line ()
  (let ((column
         (save-excursion
           (back-to-indentation)
           (let ((opener (nth 1 (syntax-ppss)))
                 (close (memq (char-after) '(?\) ?\] ?\}))))
             (if (null opener) 0
               (goto-char opener)
               (+ (current-indentation) (if close 0 4)))))))
    (extra-language--apply-column column)))

(define-derived-mode zig-mode prog-mode "Zig"
  "Edit Zig with four-space block indentation."
  (setq-local indent-tabs-mode nil)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local syntax-propertize-function #'extra-zig--string-lines)
  (setq-local indent-line-function #'extra-zig-indent-line))

;;; Terraform

(defvar terraform-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "< b" table)
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    table))

(defun extra-terraform--whole-buffer (start end)
  ;; Changing a marker may change the meaning of every following line.
  (unless (and (= start (point-min)) (= end (point-max)))
    (cons (point-min) (point-max))))

(defun extra-terraform--heredocs (start end)
  (goto-char start)
  (let ((fence (string-to-syntax "|"))
        (case-fold-search nil))
    (while (re-search-forward
            "<<\\(-?\\)\\([[:alpha:]_][[:alnum:]_-]*\\)[ \t]*$" end t)
      (let* ((open (match-beginning 0))
             (indented (> (match-end 1) (match-beginning 1)))
             (marker (match-string-no-properties 2))
             (state (save-excursion (syntax-ppss open))))
        (unless (or (nth 3 state) (nth 4 state))
          (put-text-property open (1+ open) 'syntax-table fence)
          (if (re-search-forward
               (concat "^" (if indented "[ \t]*" "")
                       (regexp-quote marker) "$") end t)
              (put-text-property (1- (point)) (point) 'syntax-table fence)
            (goto-char end)))))))

(defun extra-terraform-indent-line ()
  (let ((column
         (save-excursion
           (back-to-indentation)
           (let* ((state (syntax-ppss))
                  (opener (nth 1 state))
                  (close (memq (char-after) '(?\) ?\] ?\}))))
             (cond ((or (nth 3 state) (nth 4 state)) nil)
                   ((null opener) 0)
                   (t (goto-char opener)
                      (+ (current-indentation) (if close 0 2))))))))
    (extra-language--apply-column column)))

(define-derived-mode terraform-mode prog-mode "Terraform"
  "Edit Terraform blocks and preserve heredoc contents."
  (setq-local indent-tabs-mode nil)
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local syntax-propertize-function #'extra-terraform--heredocs)
  (add-hook 'syntax-propertize-extend-region-functions
            #'extra-terraform--whole-buffer nil t)
  (setq-local indent-line-function #'extra-terraform-indent-line))

;;; YAML

;; Indentation is part of the data.  Suggest a column on an empty line.
;; Existing text, including block scalar content, keeps its indentation.
(defun extra-yaml-indent-line ()
  (when (save-excursion (beginning-of-line) (looking-at-p "[ \t]*$"))
    (indent-line-to
     (save-excursion
       (beginning-of-line)
       (if (bobp) 0
         (forward-line -1)
         (back-to-indentation)
         (let ((base (current-column))
               (sequence-map (looking-at-p "- +[^# \t]")))
           (cond
            ((looking-at-p "#") base)
            ((looking-at-p "-[ \t]*\\(?:#.*\\)?$") (+ base 2))
            ((looking-at-p ".*:[ \t]*\\(?:[|>][-+0-9]*[ \t]*\\)?\\(?:#.*\\)?$")
             (+ base (if sequence-map 4 2)))
            (t base))))))))

(define-derived-mode yaml-mode prog-mode "YAML"
  "Suggest indentation on blank YAML lines.  Edit existing indentation by hand."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2)
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  ;; RET should not strip trailing spaces from the previous scalar line.
  (setq-local electric-indent-inhibit t)
  (setq-local indent-line-function #'extra-yaml-indent-line)
  ;; A blank scalar line can contain significant spaces too.
  (setq-local indent-region-function #'ignore))

;;; Clojure and EDN

(defvar clojure-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\; "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?, " " table)
    (modify-syntax-entry ?\\ "\\" table)
    (dolist (char (string-to-list "-_*+!?:/.<>=&%$"))
      (modify-syntax-entry char "_" table))
    (dolist (char (string-to-list "'`~@^#"))
      (modify-syntax-entry char "'" table))
    table))

(defvar extra-clojure-body-forms
  '("ns" "def" "defn" "defn-" "defmacro" "fn" "let" "letfn" "loop"
    "if" "if-not" "if-let" "when" "when-not" "when-let" "do" "doseq"
    "for" "binding" "with-open" "try" "catch" "finally" "comment"
    "cond" "case" "->" "->>" "as->" "deftest" "testing")
  "List heads whose subsequent lines indent two columns from the opener.")

(defun extra-clojure--list-column ()
  ;; Point starts on the opening paren. Align ordinary calls with their
  ;; first argument when it is on the same line as the function name.
  (let ((base (current-column)))
    (forward-char)
    (if (not (looking-at "\\(\\sw\\|\\s_\\)+"))
        (1+ base)
      (let ((head (match-string-no-properties 0)))
        (goto-char (match-end 0))
        (skip-chars-forward " \t,")
        (if (or (member head extra-clojure-body-forms)
                (eolp) (eq (char-after) ?\;))
            (+ base 2)
          (current-column))))))

(defun extra-clojure-indent-line ()
  (extra-language--apply-column
   (save-excursion
     (back-to-indentation)
     (let* ((state (syntax-ppss))
            (opener (nth 1 state))
            (close (memq (char-after) '(?\) ?\] ?\}))))
       (cond
        ((nth 3 state) nil)
        ((null opener) 0)
        (t
         (goto-char opener)
         (cond (close (current-column))
               ((memq (char-after) '(?\[ ?\{)) (1+ (current-column)))
               (t (extra-clojure--list-column)))))))))

(define-derived-mode clojure-mode prog-mode "Clojure"
  "Edit Clojure forms, vectors, maps and EDN."
  (setq-local indent-tabs-mode nil)
  (setq-local comment-start ";")
  (setq-local comment-end "")
  (setq-local indent-line-function #'extra-clojure-indent-line))

;;; File associations

(dolist (entry '(("\\.go\\'" . go-mode)
                 ("\\.zig\\'" . zig-mode)
                 ("\\.\\(?:tf\\|tfvars\\)\\'" . terraform-mode)
                 ("\\.ya?ml\\'" . yaml-mode)
                 ("\\.\\(?:clj[cs]?\\|edn\\)\\'" . clojure-mode)))
  (add-to-list 'auto-mode-alist entry))

;; Recent Emacs versions ship a JSON mode.  Older releases ship JS mode.
(add-to-list 'auto-mode-alist
             (cons "\\.json\\'" (if (fboundp 'js-json-mode) 'js-json-mode 'js-mode)))

(provide 'extra-language)
;;; extra-language.el ends here
