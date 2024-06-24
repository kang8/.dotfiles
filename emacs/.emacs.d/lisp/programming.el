; Auto-complete the other half of the parentheses
(electric-pair-mode 1)

(unless window-system
  (setq interprogram-cut-function
        (lambda (text &optional push)
          (let* ((process-connection-type nil)
                 (pbproxy (start-process "pbcopy" "pbcopy" "/usr/bin/pbcopy")))
            (process-send-string pbproxy text)
            (process-send-eof pbproxy)))))
