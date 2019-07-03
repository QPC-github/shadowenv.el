;;; shadowenv.el --- Shadowenv integration. -*- lexical-binding: t; -*-

;; Author: Dante Catalfamo <dante.catalfamo@shopify.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "24"))
;; Keywords: shadowenv, environment
;; URL: https://github.com/Shopify/shadowenv.el
;;
;; This file is not part of GNU Emacs.

;;; Commentary:

;; This package provides integration with shadowenv environment shadowing for projects.
;; See https://shopify.github.io/shadowenv/ for more details.

;;; Code:

(defconst shadowenv--instruction-split (string #x1E))
(defconst shadowenv--operand-split (string #x1F))
(defconst shadowenv--set-unexported (string #x01))
(defconst shadowenv--set-exported (string #x02))
(defconst shadowenv--unset (string #x03))
(defconst shadowenv-output-buffer "*shadowenv output*"
  "Output buffer for shadowenv command.")


(defgroup shadowenv nil
  "Shadowenv environment shadowing."
  :group 'emacs)


(defcustom shadowenv-binary-location nil
    "The location of the shadowenv binary.
If nil, binary location is determined with PATH environment variable."
  :type '(choice (const :tag "Get location from $PATH" nil)
                 (file :tag "Specify location"))
  :group 'shadowenv)


(defvar shadowenv-data nil
  "Internal shadowenv data.")

(make-variable-buffer-local 'shadowenv-data)


(defun shadowenv-run (data)
  "Run shadowenv porcelain with DATA."
  (unless (if shadowenv-binary-location
              (file-executable-p shadowenv-binary-location)
            (executable-find "shadowenv"))
    (error "Cannot find shadowenv binary"))

  (let ((shadowenv-binary (or shadowenv-binary-location "shadowenv")))
    (if (eq 0 (shell-command (concat shadowenv-binary " hook --porcelain '" data "'")
                             shadowenv-output-buffer))
        (with-current-buffer shadowenv-output-buffer
          (replace-regexp-in-string "\n$" "" (buffer-string)))
      (view-buffer-other-window shadowenv-output-buffer))))


(defun shadowenv-parse-instructions (instructions-string)
  "Parse INSTRUCTIONS-STRING returned from shadowenv."
  (save-match-data
    (let ((instructions (split-string instructions-string shadowenv--instruction-split t))
          pairs)
      (dolist (instruction instructions pairs)
        (push (split-string instruction shadowenv--operand-split) pairs))
      pairs)))


(defun shadowenv--set (instruction)
  "Set a single INSTRUCTION from shadowenv.
Instructions come in the form of (opcode variable [value])."
  (let ((opcode (car instruction))
        (variable (cadr instruction))
        (value (caddr instruction)))
    (cond
     ((string= opcode shadowenv--set-exported)
      (setenv variable value))
     ((string= opcode shadowenv--unset)
      (setenv variable))
     ((string= opcode shadowenv--set-unexported)
      (if (string= variable "__shadowenv_data")
          (setq shadowenv-data value)
        (warn "Unrecognized operand for SET_UNEXPORTED operand: %s" variable))))))


(defun shadowenv-setup ()
  "Setup shadowenv environment."
  (interactive)
  (unless shadowenv-mode
    (error "Shadowenv mode must be enabled first"))
  (make-local-variable 'process-environment)
  (let ((instructions (shadowenv-parse-instructions (shadowenv-run shadowenv-data))))
    (mapc #'shadowenv--set instructions))
  (message "Shadowenv setup complete."))


(define-minor-mode shadowenv-mode
  "Shadowenv environment shadowing."
  :init-value nil
  :lighter " Shadowenv"
  (if shadowenv-mode
      (shadowenv-setup)
    (kill-local-variable 'process-environment)
    (setq shadowenv-data nil)))

(provide'shadowenv)
;;; shadowenv.el ends here