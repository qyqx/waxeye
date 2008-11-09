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
c
mzscheme

(require (lib "ast.ss" "waxeye")
         (lib "fa.ss" "waxeye")
         "code.scm" "dfa.scm" "gen.scm")
(provide gen-c)


(define *c-prefix* "")
(define *c-parser-name* "")
(define *c-type-name* "")
(define *c-header-name* "")
(define *c-source-name* "")


(define (gen-c-names)
  (set! *c-prefix* (if *name-prefix*
                       (string-append (camel-case-lower *name-prefix*) "_")
                       ""))
  (set! *c-parser-name* (string-append *c-prefix* "parser"))
  (set! *c-type-name* (string-append *c-prefix* "node_type"))
  (set! *c-header-name* (string-append *c-parser-name* ".h"))
  (set! *c-source-name* (string-append *c-parser-name* ".c")))


(define (gen-c grammar path)
  (gen-c-names)
  (code-indent-unit! "  ")
  (gen-header grammar)
  (dump-output (string-append path *c-header-name*))
  (clear-output)
  (gen-parser grammar)
  (dump-output (string-append path *c-source-name*))
  (clear-output))


(define (bool->string b)
  (if b
      "true"
      "false"))


(define (c-comment lines)
  (comment-base "/*" lines))


(define (gen-trans a)
(define (gen-char t)
  (code-s "\"")
  (when (escape-for-java-char? t)
        (code-s "\\"))
  (code-s (cond
           ((equal? t #\") "\\\"")
           ((equal? t #\linefeed) "\\n")
           ((equal? t #\tab) "\\t")
           ((equal? t #\return) "\\r")
           (else t)))
  (code-s "\""))
  (define (gen-char-class-item a)
    (if (char? a)
        (gen-char a)
        (begin
          (code-s (char->integer (car a)))
          (code-s "..")
          (code-s (char->integer (cdr a))))))
  (cond
   ((symbol? a) (code-s (format ":_~a" a)))
   ((list? a)
    (code-s "[")
    (gen-char-class-item (car a))
    (for-each (lambda (b)
                (code-s ", ")
                (gen-char-class-item b))
              (cdr a))
    (code-s "]"))
   ((char? a) (gen-char a))
   (else (code-s a))))


(define (gen-edge a)
  (code-s "Waxeye::Edge.new")
  (code-paren
   (gen-trans (edge-t a))
   (code-s ", ")
   (code-s (edge-s a))
   (code-s ", ")
   (code-s (bool->string (edge-v a)))))


(define (gen-edges d)
  (gen-array gen-edge (list->vector d)))


(define (gen-state a)
  (code-s "Waxeye::State.new")
  (code-paren
   (gen-edges (state-edges a))
   (code-s ", ")
   (code-s (bool->string (state-match a)))))


(define (gen-states d)
  (gen-array gen-state d))


(define (gen-fa a)
  (code-s "Waxeye::Automaton.new")
  (code-paren
   (code-s ":")
   (let ((type (camel-case-lower (symbol->string (fa-type a)))))
     (cond
      ((equal? type "!") (code-s "_not"))
      ((equal? type "&") (code-s "_and"))
      (else (code-s type))))
   (code-s ", ")
   (gen-states (fa-states a))
   (code-s ", :")
   (code-s (case (fa-mode a)
             ((voidArrow) "void")
             ((pruneArrow) "prune")
             ((leftArrow) "left")))))


(define (gen-fas d)
  (gen-array gen-fa d))


(define (gen-array fn data)
  (let ((ss (vector->list data)))
    (code-s "[")
    (code-iu
    (unless (null? ss)
            (fn (car ss))
            (for-each (lambda (a)
                        (code-s ",\n")
                        (code-i)
                        (fn a))
                      (cdr ss))))
    (code-s "]")))


(define (code-c-header-comment)
  (if *file-header*
      (c-comment *file-header*)
      (c-comment *default-header*)))


(define (gen-header grammar)
  (let ((non-terms (get-non-terms grammar))
        (parser-name (if *name-prefix*
                         (string-append (camel-case-upper *name-prefix*) "parser")
                         "parser")))
    (code-c-header-comment)
    (code-n)

    (code-psn "#ifndef " (string->upper *c-parser-name*) "_H_")
    (code-psn "#define " (string->upper *c-parser-name*) "_H_")
    (code-n)
    (code-sn "#include \"waxeye.h\"")
    (code-n)
    (code-psn "enum " *c-type-name* " {")
    (code-iu
     (code-is (string->upper (car non-terms)))
     (for-each (lambda (a)
                 (code-sn ",")
                 (code-is (string->upper a)))
               (cdr non-terms))
     (code-n))
    (code-sn "};")
    (code-n)
    (code-psn "#ifndef " (string->upper *c-parser-name*) "_C_")
    (code-n)
    (code-psn "extern struct parser_t* make_" *c-parser-name* "();")
    (code-n)
    (code-psn "#endif /* " (string->upper *c-parser-name*) "_C_ */")
    (code-psn "#endif /* " (string->upper *c-parser-name*) "_H_ */")))


(define (gen-parser grammar)
  (define (gen-parser-class)
    (code-i)
    (code-psn "struct parser_t* make_" *c-parser-name* "() {")
    (code-iu
     (code-pisn "const size_t start = " (number->string *start-index*) ";")
     (code-pisn "const bool eof_check = " (bool->string *eof-check*) ";")
     (let ((automata (make-automata grammar)))
       (code-pisn "const size_t num_automata = " (number->string (vector-length automata)) ";")
       (code-is "const fa_t *automata = ")
       (gen-fas automata))
     (code-n)
     (code-n)
     (code-isn "return parser_new(start, automata, num_automata, eof_check);"))
    (code-isn "}"))

  (code-c-header-comment)
  (code-n)
  (code-psn "#define " (string->upper *c-parser-name*) "_C_")
  (code-psn "#include \"" *c-header-name* "\"")
  (code-n)

  (if *module-name*
      (begin
        (code-s "module ")
        (code-sn *module-name*)
        (code-n)
        (code-iu
         (gen-parser-class))
        (code-sn "end"))
      (gen-parser-class)))

)
