;;; smart-jump-test.el --- Tests for smart-jump -*- lexical-binding: t -*-
(require 'smart-jump)

(defun smart-jump-set-smart-jump-list-for-matching-mode (mode list)
  "Set `smart-jump-list' with LIST for every buffer that matches MODE."
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when (or (bound-and-true-p mode) ;; `minor-mode'
                (eq major-mode mode)) ;; `major-mode'
        (setq smart-jump-list list)))))

(ert-deftest smart-jump-no-registration-uses-fallbacks ()
  "When mode has not been registered, calling `smart-jump' triggers fallback
functions."
  (defvar smart-jump-jump-counter nil)
  (let* ((smart-jump-list nil) ;; nil --> no registration.
         (counter 0)
         (smart-jump-jump-counter (lambda ()
                                         (interactive)
                                         (setq counter (1+ counter))))
         (smart-jump-simple-jump-function smart-jump-jump-counter)
         (smart-jump-simple-find-references-function
          smart-jump-jump-counter))
    (call-interactively #'smart-jump-go)
    (call-interactively #'smart-jump-references)
    (should (equal counter 2))))

(ert-deftest smart-jump-with-errors-uses-fallbacks ()
  "When first to N-1 `smart-jump's throws an error, fallbacks are triggered."
  (defvar smart-jump-jump-counter nil)
  (let* ((smart-jump-list '((
                             :jump-fn (lambda () (interactive) (throw 'error))
                             :refs-fn (lambda () (interactive (throw 'error)))
                             :should-jump t
                             :heuristic 'error
                             )))
         (counter 0)
         (smart-jump-jump-counter (lambda ()
                                         (interactive)
                                         (setq counter (1+ counter))))
         (smart-jump-simple-jump-function smart-jump-jump-counter)
         (smart-jump-simple-find-references-function smart-jump-jump-counter))
    (call-interactively #'smart-jump-go)
    (call-interactively #'smart-jump-references)
    (should (equal counter 2))))

(ert-deftest smart-jump-no-errors-no-fallbacks ()
  "When there are no errors, jumps in smart-jump-list are called successfully.
No fallbacks are triggered."
  (defvar smart-jump-fallback-counter nil)
  (defvar smart-jump-jump-counter nil)
  (let* ((counter 0)
         (smart-jump-jump-counter (lambda ()
                                         (interactive)
                                         (setq counter (1+ counter))))
         (smart-jump-list `((
                             :jump-fn ,smart-jump-jump-counter
                             :refs-fn ,smart-jump-jump-counter
                             :should-jump t
                             :heuristic error
                             )))
         (smart-jump-fallback-counter (lambda ()
                                        (interactive)
                                        ;; If fallback is called at all, this
                                        ;; test has failed.
                                        (setq counter -1)))
         (smart-jump-simple-jump-function smart-jump-fallback-counter)
         (smart-jump-simple-find-references-function smart-jump-fallback-counter))
    (call-interactively #'smart-jump-go)
    (call-interactively #'smart-jump-references)
    (should (equal counter 2))))

(ert-deftest smart-jump-with-args-do-not-add-fallbacks ()
  "When `smart-jump-references' or `smart-jump-go' is called with an argument,
do not add fallback strategy to `smart-jump-list'.

For example ,when continuing `smart-jump-references' (say from an async
strategy), we don't want to add the callback to the list of `smart-jump'
strategies because it should have already been added in the first call."
  (defvar smart-jump-fallback-counter nil)
  (defvar smart-jump-jump-counter nil)
  (let* ((counter 0)
         (smart-jump-jump-counter (lambda ()
                                         (interactive)
                                         (setq counter (1+ counter))))
         (smart-jump-list `((
                             :jump-fn ,smart-jump-jump-counter
                             :refs-fn ,smart-jump-jump-counter
                             :should-jump t
                             :heuristic error
                             )))
         (smart-jump-fallback-counter (lambda ()
                                        (interactive)
                                        ;; If fallback is called at all, this
                                        ;; test has failed.
                                        (setq counter -1)))
         (smart-jump-simple-jump-function smart-jump-fallback-counter)
         (smart-jump-simple-find-references-function
          smart-jump-fallback-counter))
    (smart-jump-go smart-jump-list)
    (smart-jump-references smart-jump-list)
    (should (equal counter 2))))

(ert-deftest smart-jump-:should-jump:-is-false-uses-fallback ()
  "When the 1 -> N-1 jump's :should-jump is false, it should skip that jump
and use the fallback instead."
  (defvar smart-jump-fallback-counter nil)
  (defvar smart-jump-jump-counter nil)
  (let* ((counter 0)
         (smart-jump-jump-counter (lambda ()
                                    (interactive)
                                    ;; Test fails if this is hit.
                                    (setq counter -1)))
         (smart-jump-list `((
                             :jump-fn ,smart-jump-jump-counter
                             :refs-fn ,smart-jump-jump-counter
                             :should-jump nil
                             :heuristic error
                             )))
         (smart-jump-fallback-counter (lambda ()
                                        (interactive)
                                        (setq counter (1+ counter))))
         (smart-jump-simple-jump-function smart-jump-fallback-counter)
         (smart-jump-simple-find-references-function
          smart-jump-fallback-counter))
    (call-interactively #'smart-jump-go)
    (call-interactively #'smart-jump-references)
    (should (equal counter 2))))

(ert-deftest smart-jump-register-updates-current-mode ()
  "When calling `smart-jump-register', current buffer's `smart-jump-list'
should be updated."
  (defvar smart-jump-old-smart-jump-list nil)
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when (eq major-mode 'emacs-lisp-mode)
        ;; Keep track of `smart-jump-list' so we can reset the state back
        ;; to normal after the test runs.
        (setq smart-jump-old-smart-jump-list smart-jump-list))))
  (with-temp-buffer
    (let ((major-mode 'emacs-lisp-mode)
          (smart-jump-list '()))
      (smart-jump-register :modes 'emacs-lisp-mode
                           :jump-fn 'dummy)
      (should (equal (plist-get (car smart-jump-list) :jump-fn) 'dummy))
      ;; Reset the state back...
      (smart-jump-set-smart-jump-list-for-matching-mode
       'emacs-lisp-mode smart-jump-old-smart-jump-list))))

;;; smart-jump-test.el ends here
