;;; quarter-master.el --- A four-quarter day view for Org -*- lexical-binding: t; -*-

;; Load this file, then run M-x quarter-master.
;; TAB or M-f steps forward a quarter; backtab or M-b steps back.
;; Org Agenda’s f and b keys change days.
;; Arrows and C-n/C-p navigate the grid. DEL asks before removing a booking.
;; RET opens or creates a booking; a numeric prefix sets its length in quarters.
;; Change quarter-master-hours to set the usual visible interval.
;; Customize quarter-master-color-rules to colour bookings by TODO state or tag.
;; For daily planning hints, set quarter-master-slot-labels in your init file.
;; The final hour is exclusive. The ordinary agenda follows the grid.

(require 'org-agenda)
(require 'rx)
(require 'cl-lib)
(require 'subr-x)

(defgroup quarter-master nil "Quarter-hour day planner." :group 'org-agenda)
(defcustom quarter-master-hours '(4 22)
  "First visible hour and exclusive end hour, in local time."
  :type '(list integer integer) :group 'quarter-master)

(defface quarter-master-block
  '((((background dark)) :background "#32566a" :foreground "#ffffff")
    (t :background "#d4e7ed" :foreground "#17394a"))
  "Booking fill." :group 'quarter-master)
(defface quarter-master-alternate
  '((((background dark)) :background "#584765" :foreground "#ffffff")
    (t :background "#e9dfee" :foreground "#3d2849"))
  "Alternate booking fill." :group 'quarter-master)

(defcustom quarter-master-color-rules
  '((tag "work" (:inherit (font-lock-function-name-face region)))
    (tag "family" (:inherit (font-lock-variable-name-face region)))
    (tag "self" (:inherit (font-lock-string-face region)))
    (tag "travel" (:inherit (shadow region))))
  "Ordered rules for colouring bookings.  The first match wins.
Each rule is (KIND VALUE FACE), where KIND is `state' or `tag',
VALUE is an exact Org keyword or tag, and FACE is an Emacs face or
a face attribute list.  Tags follow Org's tag inheritance settings.
Defaults combine category foregrounds with the theme's `region' fill.
With rules configured, unmatched bookings use `quarter-master-block'.
With no rules, bookings use the two alternating fills."
  :type '(repeat (list (choice (const state) (const tag))
                       (string :tag "Keyword or tag")
                       (sexp :tag "Face name or attribute list")))
  :group 'quarter-master)

(defcustom quarter-master-booking-heading "Quarter Master"
  "Top-level heading for new bookings in the selected agenda file."
  :type 'string
  :group 'quarter-master)

(defcustom quarter-master-tag-cycle '("work" "family" "self" "travel")
  "Tags to cycle through with t on a Quarter Master booking."
  :type '(repeat string)
  :group 'quarter-master)

(defun quarter-master--heading-face ()
  "Return the first matching colour at the current Org heading."
  (when quarter-master-color-rules
    (let ((state (org-get-todo-state))
          (tags (org-get-tags)))
      (or (cl-loop for (kind value face) in quarter-master-color-rules
                   when (pcase kind
                          ('state (equal value state))
                          ('tag (member value tags)))
                   return face)
          'quarter-master-block))))

(cl-defstruct (quarter-master--event (:constructor quarter-master--make))
  title marker start end face)

(defun quarter-master--events ()
  "Collect timed Org entries from the current one-day agenda."
  (let (events)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((time (org-get-at-bol 'time-of-day))
              (duration (org-get-at-bol 'duration))
              (marker (or (org-get-at-bol 'org-hd-marker)
                          (org-get-at-bol 'org-marker))))
          (when (and (integerp time) (<= 0 time 2359)
                     (< (% time 100) 60) (markerp marker) (marker-buffer marker))
            (let* ((minutes (+ (* 60 (/ time 100)) (% time 100)))
                   (start (/ minutes 15))
                   (end (if (and (numberp duration) (> duration 0))
                            (min 96 (ceiling (+ minutes duration) 15))
                          (1+ start)))
                   (event (org-with-point-at marker
                            (org-back-to-heading t)
                            (quarter-master--make
                             :title (org-get-heading t t t t)
                             :face (quarter-master--heading-face)
                             :marker marker :start start :end end))))
              (push event events))))
        (forward-line)))
    (cl-stable-sort (nreverse events) #'< :key #'quarter-master--event-start)))

(defun quarter-master--lanes (events first)
  "Pack portions of EVENTS in the hour starting at quarter FIRST."
  (let ((lanes (list (make-vector 4 nil))))
    (dolist (event events)
      (let ((lo (max 0 (- (quarter-master--event-start event) first)))
            (hi (min 4 (- (quarter-master--event-end event) first))))
        (when (< lo hi)
          (let ((lane (cl-find-if
                       (lambda (row)
                         (cl-loop for i from lo below hi never (aref row i)))
                       lanes)))
            (unless lane
              (setq lane (make-vector 4 nil)
                    lanes (append lanes (list lane))))
            (cl-loop for i from lo below hi do (aset lane i event))))))
    lanes))

(defvar-local quarter-master--files nil)
(defvar-local quarter-master--preferred-file nil)
(defvar-local quarter-master--stops nil)

(defun quarter-master--time (quarter)
  (format "%02d:%02d" (/ quarter 4) (* 15 (% quarter 4))))

(defcustom quarter-master-slot-labels nil
  "Daily planning hints of the form (START END LABEL) or (START END LABEL TAG).
Use quarter-hour HH:MM times. END is exclusive. TAG is a bare Org tag
such as \"work\". Later rules take precedence where ranges overlap."
  :type '(repeat
          (list (string :tag "Start")
                (string :tag "End")
                (string :tag "Label")
                (option (string :tag "Default tag"))))
  :group 'quarter-master)

(defun quarter-master--labels (&optional field)
  "Return a vector of daily slot labels, or default tags when FIELD is `tags'."
  (let ((slots (make-vector 96 nil))
        (times (mapcar #'quarter-master--time (number-sequence 0 96))))
    (dolist (rule quarter-master-slot-labels)
      (pcase-let* ((`(,start ,end ,label . ,rest) rule)
                   (tag (car rest))
                   (lo (cl-position start times :test #'equal))
                   (hi (cl-position end times :test #'equal)))
        (unless (and lo hi (< lo hi)
                     (stringp label)
                     (not (string-match-p "[[:cntrl:]]" label))
                     (null (cdr rest))
                     (or (null tag)
                         (and (stringp tag)
                              (string-match-p "\\`[[:alnum:]_@#%]+\\'" tag))))
          (user-error "Invalid Quarter Master slot rule: %S" rule))
        (cl-loop for q from lo below hi
                 do (aset slots q (if (eq field 'tags) tag label)))))
    slots))

(defun quarter-master--create (quarter count)
  "Create a booking covering COUNT free quarters starting at QUARTER."
  (unless (and (integerp count) (> count 0))
    (user-error "Booking length must be a positive number of quarters"))
  (when (> (+ quarter count) (* 4 (cadr quarter-master-hours)))
    (user-error "Booking would extend past the end of the grid"))
  (cl-loop for q from quarter below (+ quarter count)
           when (get-text-property (aref quarter-master--stops q)
                                   'quarter-master-event)
           do (user-error "Quarter %s is already booked" (quarter-master--time q)))
  (unless quarter-master--files
    (user-error "Add an Org file to org-agenda-files first"))

  (let* ((date (format-time-string "%Y-%m-%d"
                                   (org-time-from-absolute org-starting-day)))
         (range (concat (quarter-master--time quarter) "-"
                        (quarter-master--time (+ quarter count))))
         (default-tag (aref (quarter-master--labels 'tags) quarter))
         (title (string-trim
                 (read-string (format "Booking at %s on %s: " range date))))
         (files quarter-master--files))
    (when (string-empty-p title)
      (user-error "A booking needs a title"))
    (let ((file (if (cdr files)
                    (completing-read "Agenda file: " files nil t nil nil
                                     (or quarter-master--preferred-file (car files)))
                  (car files))))
      (with-current-buffer (find-file-noselect file)
        (save-excursion
          (save-restriction
            (widen)
            (atomic-change-group
              ;; Find the top-level booking heading, creating it if needed.
              (goto-char (point-min))
              (if (catch 'found
                    (while (re-search-forward "^\\*[ \t]+" nil t)
                      (when (equal (org-get-heading t t t t)
                                   quarter-master-booking-heading)
                        (throw 'found t))))
                  (org-end-of-subtree t t)
                (goto-char (point-max))
                (unless (bolp) (insert "\n"))
                (insert "* " quarter-master-booking-heading "\n"))

              ;; Write the child heading and merge the default with typed tags.
              (unless (bolp) (insert "\n"))
              (insert (if org-odd-levels-only "*** " "** ") title)
              (when default-tag
                (let ((tags (org-get-tags nil t)))
                  (unless (member default-tag tags)
                    (org-set-tags (append tags (list default-tag))))))
              (end-of-line)
              (insert "\n<" date " " range ">\n")
              (save-buffer)))))
      (setq quarter-master--preferred-file file)
      (org-agenda-redo)
      (when-let ((pos (aref quarter-master--stops quarter)))
        (goto-char pos))
      (message "Booked %s on %s, %s" title date range))))

(defun quarter-master-open (&optional count)
  "Open this booking or create a booking in the current free quarter for COUNT quarters."
  (interactive "p")
  (let* ((quarter (get-text-property (point) 'quarter-master-slot))
         (event (get-text-property (point) 'quarter-master-event))
         (marker (and event (quarter-master--event-marker event))))
    (cond
     (event
      (unless (marker-buffer marker) (user-error "Refresh the agenda first"))
      (pop-to-buffer (marker-buffer marker))
      (widen)
      (goto-char marker)
      (org-show-context))
     ((null quarter) (user-error "Move to a quarter first"))
     ;; Blank padding in a secondary overlap lane is not free time.
     ((get-text-property (aref quarter-master--stops quarter) 'quarter-master-event)
      (goto-char (aref quarter-master--stops quarter))
      (quarter-master-open count))
     (t (quarter-master--create quarter (or count 1))))))

(defun quarter-master-delete ()
  "Confirm and delete a plain heading containing one timed booking."
  (interactive)
  (let* ((event (get-text-property (point) 'quarter-master-event))
         (slot (get-text-property (point) 'quarter-master-slot))
         (day (format-time-string "%Y-%m-%d" (org-time-from-absolute org-starting-day))))
    (unless event (user-error "No booking in this slot"))
    (let ((marker (quarter-master--event-marker event))
          (title (quarter-master--event-title event)))
      (unless (marker-buffer marker) (user-error "Refresh the agenda first"))
      (when (org-with-point-at marker
              (widen)
              (org-back-to-heading t)
              (let* ((start (point))
                     (end (save-excursion (org-end-of-subtree t t) (point)))
                     (entry (buffer-substring-no-properties start end))
                     (pattern (rx-to-string
                               `(seq string-start (+ "*") (+ blank) ,title (* blank) "\n"
                                     (* (any " \t\n"))
                                     (group "<" ,day (? (+ blank) (+ alpha)) (+ blank)
                                            (? digit) digit ":" (= 2 digit)
                                            (? "-" (? digit) digit ":" (= 2 digit)) ">")
                                     (* (any " \t\n")) string-end))))
                (unless (string-match pattern entry)
                  (user-error "Use RET to edit this heading; DEL handles plain bookings"))
                (when (y-or-n-p (format "Delete “%s” %s? " title (match-string 1 entry)))
                  (atomic-change-group (delete-region start end) (save-buffer))
                  t)))
        (org-agenda-redo)
        (goto-char (aref quarter-master--stops slot))))))

(defvar-local quarter-master--highlights nil)
(defvar-local quarter-master--selected nil)

(defun quarter-master--highlight ()
  "Highlight every visible part of the booking at point."
  (let ((event (get-text-property (point) 'quarter-master-event)))
    (unless (eq event quarter-master--selected)
      (mapc #'delete-overlay quarter-master--highlights)
      (setq quarter-master--highlights nil quarter-master--selected event)
      (when event
        (let ((pos (point-min)))
          (while (setq pos (text-property-any pos (point-max) 'quarter-master-event event))
            (let* ((end (next-single-property-change pos 'quarter-master-event nil (point-max)))
                   (overlay (make-overlay pos end)))
              (overlay-put overlay 'face '(:underline t :weight bold))
              (push overlay quarter-master--highlights)
              (setq pos end))))))))

(defun quarter-master--move (step)
  "Move STEP quarters, wrapping at the grid boundaries."
  (let* ((first (* 4 (car quarter-master-hours)))
         (count (* 4 (- (cadr quarter-master-hours) (car quarter-master-hours))))
         (current (get-text-property (point) 'quarter-master-slot))
         (offset (if current (- current first) (if (< step 0) 0 (- step))))
         (next (+ first (mod (+ offset step) count))))
    (goto-char (aref quarter-master--stops next))
    (message "%s–%s" (quarter-master--time next) (quarter-master--time (1+ next)))))

(defun quarter-master-next () (interactive) (quarter-master--move 1))
(defun quarter-master-previous () (interactive) (quarter-master--move -1))
(defun quarter-master-down () (interactive) (quarter-master--move 4))
(defun quarter-master-up () (interactive) (quarter-master--move -4))

(defun quarter-master-cycle-tag ()
  "Cycle the selected booking's local tag and refresh its block."
  (interactive)
  (let* ((event (get-text-property (point) 'quarter-master-event))
         (slot (get-text-property (point) 'quarter-master-slot))
         (marker (and event (quarter-master--event-marker event)))
         (cycle quarter-master-tag-cycle))
    (unless event (user-error "No booking in this slot"))
    (unless (marker-buffer marker) (user-error "Refresh the agenda first"))
    (unless cycle (user-error "Set quarter-master-tag-cycle first"))
    (org-with-point-at marker
      (org-back-to-heading t)
      (let* ((tags (org-get-tags nil t))
             (current (cl-find-if (lambda (tag) (member tag tags)) cycle))
             (next (or (cadr (member current cycle)) (car cycle)))
             (other-tags (cl-remove-if (lambda (tag) (member tag cycle)) tags)))
        (org-set-tags (append other-tags (list next)))
        (save-buffer)
        (message "Booking tag: %s" next)))
    (org-agenda-redo)
    (goto-char (aref quarter-master--stops slot))))

(defconst quarter-master--map
  (let ((map (make-sparse-keymap)))
    (dolist (group '((quarter-master-open "RET")
                     (quarter-master-open "C-j")
                     (quarter-master-cycle-tag "t")
                     (org-agenda-later "M-n")
                     (org-agenda-earlier "M-p")
                     (quarter-master-next "TAB" "<tab>" "<right>" "M-f" "f" "w")
                     (quarter-master-previous "<backtab>" "S-<tab>" "<left>" "M-b" "b")
                     (quarter-master-down "<down>" "C-n")
                     (quarter-master-up "<up>" "C-p")
                     (quarter-master-delete "DEL" "<backspace>" "<delete>" "<deletechar>")))
      (dolist (key (cdr group))
        (define-key map (kbd key) (car group))))
    (dotimes (digit 10)
      (define-key map (kbd (format "C-%d" digit)) #'digit-argument))
    map)
  "Bindings active inside the quarter-hour grid.")

(defun quarter-master--row (row first width labels)
  (let ((i 0))
    (while (< i 4)
      (let ((event (aref row i)))
        (if (null event)
            (let ((label (and labels (aref labels (+ first i)))))
              (insert (propertize "┊" 'face 'shadow))
              (if label
                  (insert " " (propertize
                               (truncate-string-to-width label (- width 2) nil ?\s "…")
                               'face 'font-lock-comment-face 'help-echo label))
                (insert (make-string (1- width) ?\s)))
              (cl-incf i))
          (let ((j (1+ i)) (beg (point))
                (starts (= (+ first i) (max (* 4 (car quarter-master-hours))
                                            (quarter-master--event-start event)))))
            (while (and (< j 4) (eq event (aref row j))) (cl-incf j))
            (let* ((size (* width (- j i)))
                   (label (if starts (quarter-master--event-title event) "")))
              (insert " " (truncate-string-to-width label (- size 2) nil ?\s "…") " ")
              (add-text-properties
               beg (point) (list 'face (quarter-master--event-face event)
                                 'quarter-master-event event
                                 'help-echo (quarter-master--event-title event))))
            (setq i j)))))))

(defun quarter-master--render ()
  (let* ((events (quarter-master--events))
         (labels (quarter-master--labels))
         (start (car quarter-master-hours))
         (end (cadr quarter-master-hours))
         (window (get-buffer-window (current-buffer) t))
         (width (max 3 (/ (- (window-body-width window) 5) 4)))
         (context (cl-loop for prop in '(org-lprops org-redo-cmd org-last-args
                                         org-series-cmd org-series-redo-cmd
                                         org-agenda-type)
                           append (list prop (get-text-property (point-min) prop))))
         (inhibit-read-only t))
    (unless (and (integerp start) (integerp end) (<= 0 start) (< start end) (<= end 24))
      (user-error "Set quarter-master-hours to a pair such as (4 22)"))
    ;; Suppress hints even when the booking occupies a secondary overlap lane.
    (dolist (event events)
      (cl-loop for q from (quarter-master--event-start event)
               below (quarter-master--event-end event) do (aset labels q nil)))
    (cl-loop for event in events for n from 0
             unless (quarter-master--event-face event) do
             (setf (quarter-master--event-face event)
                   (if (cl-evenp n) 'quarter-master-block 'quarter-master-alternate)))
    (setq quarter-master--stops (make-vector 96 nil)
          quarter-master--files (org-agenda-files))
    (setq-local header-line-format
                (format-time-string "  %A, %d %B %Y"
                                    (org-time-from-absolute org-starting-day)))
    (goto-char (point-min))
    (cl-loop for hour from start below end do
             (cl-loop for row in (quarter-master--lanes events (* 4 hour))
                      for lane from 0 do
                      (insert (if (zerop lane) (format "%02d   " hour) "     "))
                      (quarter-master--row row (* hour 4) width (and (zerop lane) labels))
                      (save-excursion
                        (dotimes (i 4)
                          (let ((q (+ (* hour 4) i)))
                            (move-to-column (+ 5 (* width i)))
                            (let ((beg (point)))
                              (move-to-column (+ 5 (* width (1+ i))))
                              (put-text-property beg (point) 'quarter-master-slot q)
                              (when (or (null (aref quarter-master--stops q))
                                        (and (aref row i)
                                             (null (get-text-property
                                                    (aref quarter-master--stops q)
                                                    'quarter-master-event))))
                                (aset quarter-master--stops q beg))))))
                      (insert "\n")))
    (add-text-properties (point-min) (point) (append (list 'keymap quarter-master--map) context))
    (insert "\n")
    (add-hook 'post-command-hook #'quarter-master--highlight nil t)
    (goto-char (point-min))))

;;;###autoload
(defun quarter-master ()
  "Show today's four-quarter grid above its normal Org agenda."
  (interactive)
  (let ((org-agenda-custom-commands
         '(("Q" "Quarter day" agenda ""
            ((org-agenda-span 1)
             (org-agenda-start-day nil)
             (org-agenda-start-on-weekday nil)
             (org-agenda-use-time-grid nil)
             (org-agenda-buffer-name "*Quarter Master*")
             (org-agenda-finalize-hook '(quarter-master--render)))))))
    (org-agenda nil "Q")
    (goto-char (aref quarter-master--stops (* 4 (car quarter-master-hours))))))

(provide 'quarter-master)
;;; quarter-master.el ends here
