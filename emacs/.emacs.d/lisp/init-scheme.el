(setq display-buffer-alist
      '(("\\*scheme\\*"
         (display-buffer-in-side-window)
         (side . right)
         (slot . 0)
         (window-width . 0.3)
         (preserve-size . (nil . t)))))

(defun my-run-scheme ()
  "Run Scheme in a new side window and load the current file if it is a '.scm'
  file, then keeping cursor in the original window"
  (interactive)
  (unless (get-buffer "*scheme*")
    (run-scheme scheme-program-name)
    (other-window -1))
  (let ((file (buffer-file-name)))
    (when (and file (string-match "\\.scm\\'" file))
      (comint-send-string (get-buffer-process "*scheme*")
                          (concat "(load \"" file "\" )\n")))))

(global-set-key (kbd "C-c s") 'my-run-scheme)
