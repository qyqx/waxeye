;;; Waxeye Parser Generator
;;; www.waxeye.org
;;; Copyright (C) 2008 Orlando D. A. R. Hill
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy of
;;; this software and associated documentation files (the "Software"), to deal in
;;; the Software without restriction, including without limitation the rights to
;;; use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
;;; of the Software, and to permit persons to whom the Software is furnished to do
;;; so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.

(module
make
mzscheme

(require (only (lib "list.ss") foldr) (lib "process.ss"))
(provide ^ $ ++ cd cd$ run-cmd run-make target)

(define *target-table* (make-hash-table))
(define *dep-table* (make-hash-table))

(define ++ string-append)

(define-syntax target
  (syntax-rules ()
    ((_ name (deps ...) code ...)
     (hash-table-put! *target-table* 'name (lambda () (for-each run-target '(deps ...)) code ...)))))


(define (run-target t)
  (let ((t-code (hash-table-get *target-table* t #f)))
    (if t-code
        (unless (hash-table-get *dep-table* t #f)
                (hash-table-put! *dep-table* t #t)
                (apply t-code ()))
        (error 'make (++ "target doesn't exist - " (symbol->string t))))))


(define (run-make)
  (for-each (lambda (a)
              (run-target (string->symbol a)))
            (vector->list (current-command-line-arguments))))


(define (run-cmd prog args)
  (define (as-string s)
    (cond
     ((symbol? s) (symbol->string s))
     ((char? s) (list->string (list s)))
     ((number? s) (number->string s))
     (else s)))
  (let ((cmd (++ (as-string prog)
                 (foldr (lambda (a b)
                          (++ " " (as-string a) b))
                        ""
                        args))))
    (display cmd)
    (newline)
    (system cmd)))


(define-syntax $
  (syntax-rules ()
    ((_ prog arg ...)
     (run-cmd 'prog (list arg ...)))))


(define-syntax ^
  (syntax-rules ()
    ((_ prog arg ...)
     (run-cmd 'prog '(arg ...)))))


(define-syntax cd$
  (syntax-rules ()
    ((_ dir code ...)
     (parameterize ((current-directory (let ((d dir))
                                         (if (symbol? d)
                                             (symbol->string d)
                                             d))))
                   code ...))))


(define-syntax cd
  (syntax-rules ()
    ((_ dir code ...)
     (cd$ 'dir code ...))))

)
