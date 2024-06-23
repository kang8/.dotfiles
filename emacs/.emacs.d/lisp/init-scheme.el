(setq display-buffer-alist
      '(("\\*scheme\\*"
         (display-buffer-in-side-window)
         (side . right)
         (slot . 0)
         (window-width . 0.3)
         (preserve-size . (nil . t)))))

(defun my-run-scheme ()
  "Run Scheme in a new side window, keeping cursor in the original window."
  (interactive)
  (run-scheme scheme-program-name)
  (other-window -1))

(global-set-key (kbd "C-c s") 'my-run-scheme)
