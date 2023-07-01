;; -*- lexical-binding: t; -*-
(defun foo ()
  (cl-case t
    (null 'null)
    (foo 'foo)
    ('t 'true)
    (t 'union)))

(aio-with-async
  (pcase-let* ((`(,callback . ,first-promise) (aio-make-callback)))
    (aio-wait-for (aio-wait-for (aio-wait-for (aio-await (funcall callback 'foo)))))))


(let ((buffer (get-buffer-create "*aio test*"))
      (url-format "http://localhost/delay/2?foo=%s"))
  ;; This runs the requests in sequence, not in parallel.
  (with-current-buffer buffer
    (aio-with-async
      (dotimes (i 3)
        (goto-char (point-max))
        (insert (format-time-string "%F %T: ")
                (aio-await (aio-plz 'get (format url-format i)))
                "\n"))))
  (pop-to-buffer buffer))

(aio-with-async
  (let* ((buffer (get-buffer-create "*aio test*"))
         (url-format "http://localhost/delay/2?foo=%s")
         (callback (lambda (result)
                     (with-current-buffer buffer
                       (goto-char (point-max))
                       (insert (format-time-string "%F %T: ")
                               result "\n"))))
         (promises (cl-loop for i below 3
                            collect (aio-plz 'get (format url-format i))))
         (select (aio-make-select promises)))
    ;; This works.
    (pop-to-buffer buffer)
    (cl-loop for result = (aio-await (aio-await (aio-select select)))
             while result
             do (funcall callback result))))

;; Does NOT WORK.
;; (aio-defun aio-await* (promise depth)
;;   (message "DEPTH:%s  PROMISE:%S" depth promise)
;;   (let ((result (aio-await promise)))
;;     (message "DEPTH:%s  RESULT:%S" depth result)
;;     (cl-typecase result
;;       (aio-promise (aio-await* result (1+ depth)))
;;       (t (message "Returning: %S" result)
;;          result))))

;; Seems to work.
(defmacro aio-await* (expr)
  `(let ((result (aio-await ,expr)))
     (cl-typecase result
       (aio-promise (cl-loop while (aio-promise-p result)
                             do (setf result (aio-await result))
                             finally return result))
       (t result))))

;; (defmacro aio-any (promise ))

(aio-with-async
  (let* ((buffer (get-buffer-create "*aio test*"))
         (url-format "http://localhost/delay/2?foo=%s")
         (callback (lambda (result)
                     ;; (message "CALLBACK: RESULT:%S" result)
                     (with-current-buffer buffer
                       (goto-char (point-max))
                       (insert (format-time-string "%F %T: ")
                               result "\n"))))
         (promises (cl-loop for i below 3
                            collect (aio-plz 'get (format url-format i))))
         (select (aio-make-select promises)))
    (pop-to-buffer buffer)
    (cl-loop for result = (aio-await* (aio-select select))
             while result
             do (cl-typecase result
                  (aio-promise nil)
                  (t (funcall callback result))))))
