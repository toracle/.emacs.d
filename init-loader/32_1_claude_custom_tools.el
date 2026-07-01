;;; 32_1_claude_custom_tools.el --- Custom MCP tools for Claude Code IDE  -*- lexical-binding: t; -*-

;; This file provides custom buffer-related MCP tools for Claude Code IDE

(require 'claude-code-ide-mcp)
(require 'claude-code-ide-diagnostics)
(require 'claude-code-ide-mcp-server)

;;; Tool Functions

(defun my-list-buffers ()
  "List all open buffers with metadata.
Returns a list of buffers with their names, file paths, modes, and status."
  (claude-code-ide-mcp-server-with-session-context nil
    (let ((results '()))
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (let* ((buffer-name (buffer-name))
                 ;; Skip internal buffers (starting with space)
                 (is-internal (string-prefix-p " " buffer-name)))
            (unless is-internal
              (let ((file-path (buffer-file-name))
                    (mode-name (format "%s" major-mode))
                    (modified (if (buffer-modified-p) "modified" "saved"))
                    (read-only (if buffer-read-only "read-only" "writable"))
                    (size (buffer-size)))
                (push (format "Buffer: %s\n  File: %s\n  Mode: %s\n  Status: %s, %s\n  Size: %d chars"
                              buffer-name
                              (or file-path "(no file)")
                              mode-name
                              modified
                              read-only
                              size)
                      results))))))
      (if results
          (mapconcat #'identity (nreverse results) "\n\n")
        "No buffers open"))))

(defun my-get-buffer-content (buffer-name &optional start-line end-line)
  "Get content from BUFFER-NAME.
Optional START-LINE and END-LINE specify a region (1-based, inclusive).
If not specified, returns entire buffer content."
  (claude-code-ide-mcp-server-with-session-context nil
    (if (not buffer-name)
        (error "buffer_name parameter is required")
      (let ((buffer (get-buffer buffer-name)))
        (if (not buffer)
            (format "Buffer '%s' not found. Use list_buffers to see available buffers." buffer-name)
          (with-current-buffer buffer
            (let* ((start-pos (if start-line
                                  (save-excursion
                                    (goto-char (point-min))
                                    (forward-line (1- start-line))
                                    (point))
                                (point-min)))
                   (end-pos (if end-line
                                (save-excursion
                                  (goto-char (point-min))
                                  (forward-line end-line)
                                  (point))
                              (point-max)))
                   (content (buffer-substring-no-properties start-pos end-pos))
                   (file-path (buffer-file-name))
                   (mode-name (format "%s" major-mode))
                   (line-range (if (and start-line end-line)
                                   (format " (lines %d-%d)" start-line end-line)
                                 "")))
              (format "Buffer: %s%s\nFile: %s\nMode: %s\n\n%s"
                      buffer-name
                      line-range
                      (or file-path "(no file)")
                      mode-name
                      content))))))))

;;; Tool Definitions

(claude-code-ide-make-tool
 :function #'my-list-buffers
 :name "list_buffers"
 :description "List all open buffers in Emacs with their metadata (name, file path, mode, status, size). Use this to discover what buffers are available before getting their content"
 :args nil)


(claude-code-ide-make-tool
 :function #'my-get-buffer-content
 :name "get_buffer_content"
 :description "Get the content of a specific Emacs buffer by name. Can retrieve entire buffer or a specific line range. Use list_buffers first to see available buffer names"
 :args '((:name "buffer_name"
                :type string
                :description "Name of the buffer to get content from (e.g., 'init.el', '*scratch*')")
         (:name "start_line"
                :type integer
                :description "Optional starting line number (1-based, inclusive). If omitted, starts from beginning"
                :optional t)
         (:name "end_line"
                :type integer
                :description "Optional ending line number (1-based, inclusive). If omitted, goes to end"
                :optional t)))

(provide '32_1_claude_custom_tools)
;;; 32_1_claude_custom_tools.el ends here
