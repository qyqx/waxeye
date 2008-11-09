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
java
mzscheme

(require (lib "ast.ss" "waxeye")
         (lib "fa.ss" "waxeye")
         (only (lib "list.ss" "mzlib") filter)
         "action.scm" "code.scm" "dfa.scm" "gen.scm")
(provide gen-java)


(define *gather* #t)
(define *java-parser-name* "")
(define *java-node-name* "")
(define *java-context-name* "")
(define *java-tree-type* "")
(define *num-ok* 0)
(define *num-tmp* 0)
(define *production-index* 0)


(define-syntax java:con
  (syntax-rules ()
    ((java:con (modifier ...) name arg code ...)
     (begin
       (code-i)
       (code-space modifier ...)
       (code-s name)
       (code-sn arg)
       (code-brace code ...)))))


(define-syntax java:method
  (syntax-rules ()
    ((java:method (modifier ... type) name arg code ...)
     (java:con (modifier ... type) name arg code ...))))


(define-syntax java:test-block
  (syntax-rules ()
    ((java:test-block name test code ...)
     (begin
       (code-is name)
       (code-s " (")
       (code-s test)
       (code-sn ")")
       (code-brace code ...)))))


(define-syntax java:for
  (syntax-rules ()
    ((java:for test code ...)
     (java:test-block "for" test code ...))))


(define-syntax java:while
  (syntax-rules ()
    ((java:while test code ...)
     (java:test-block "while" test code ...))))


(define-syntax java:if
  (syntax-rules ()
    ((java:if test code ...)
     (java:test-block "if" test code ...))))


(define-syntax java:else
  (syntax-rules ()
    ((java:else code ...)
     (begin
       (code-isn "else")
       (code-brace code ...)))))


(define-syntax java:ifelse
  (syntax-rules ()
    ((java:ifelse test code1 code2)
     (begin
       (java:if test code1)
       (java:else code2)))))


(define (java-comment lines)
  (comment-bookend "/*" " *" "*/" lines))


(define (code-java-doc . lines)
  (comment-bookend "/**" " *" "*/" lines))


(define (code-java-header-comment)
  (if *file-header*
      (java-comment *file-header*)
      (java-comment *default-header*)))


(define (gen-java-names)
  (set! *java-node-name* (if *name-prefix*
                             (string-append *name-prefix* "Type")
                             "Type"))
  (set! *java-parser-name* (if *name-prefix*
                               (string-append *name-prefix* "Parser")
                               "Parser"))
  (set! *java-context-name* (if *name-prefix*
                               (string-append "I" *name-prefix* "Context")
                               "IContext"))
  (set! *java-tree-type* (string-append "IAST<" *java-node-name* ">")))


(define (gen-java grammar path)
  (gen-java-names)
  (gen-java-node-type grammar)
  (dump-output (string-append path *java-node-name* ".java"))
  (clear-output)
  (gen-java-parser grammar)
  (dump-output (string-append path *java-parser-name* ".java"))
  (clear-output)
  (unless (null? *action-list*)
          (gen-java-context)
          (dump-output (string-append path *java-context-name* ".java"))
          (clear-output)))


(define (gen-java-node-type grammar)
  (let ((non-terms (get-non-terms grammar)))
    (code-java-header-comment)
    (gen-java-package)
    (code-n)
    (code-java-doc "The types of AST nodes." "" "@author Waxeye Parser Generator")
    (code-pisn "public enum " *java-node-name*)
    (code-brace
     (code-isn "_Empty,")
     (code-isn "_Char,")
     (code-isn "_Pos,")
     (code-is "_Neg")
     (for-each (lambda (a)
                 (code-sn ",")
                 (code-is (camel-case-upper a)))
               non-terms)
     (code-n))))


(define (gen-java-context)
  (code-java-header-comment)
  (gen-java-package)
  (code-n)
  (code-java-doc "The interface for the context of the parser." "" "@author Waxeye Parser Generator")
  (code-pisn "public interface " *java-context-name*)
  (code-brace
   (gen-java-context-method (car *action-list*))
   (for-each (lambda (a)
               (code-n)
               (gen-java-context-method a))
             (cdr *action-list*))
   (code-n)))


(define (gen-java-context-method exp)
  (code-is *java-context-name*)
  (code-s " ")
  (code-s (camel-case-lower (list->string (ast-c (car (ast-c exp))))))
  (code-s "(")
  (let ((labels (cdr (ast-c exp))))
    (unless (null? labels)
            (code-s *java-tree-type*)
            (code-s (list->string (ast-c (car labels))))
            (for-each (lambda (a)
                        (code-s ", ")
                        (code-s *java-tree-type*)
                        (code-s " ")
                        (code-s (list->string (ast-c a))))
                      (cdr labels))))
  (code-s ");"))


(define (gen-java-parser grammar)
  (code-java-header-comment)
  (gen-java-package)
  (code-n)
  (gen-java-imports)
  (code-java-doc "A parser generated by the Waxeye Parser Generator." "" "@author Waxeye Parser Generator")
  (code-pisn "public final class " *java-parser-name* " extends org.waxeye.parser.Parser<" *java-node-name* ">")
  (code-brace
   (code-sep
    (gen-constructor)
    (gen-make-automata (make-automata grammar)))))


(define (gen-java-package)
  (when *module-name*
        (code-pisn "package " *module-name* ";")))


(define (gen-java-imports)
  (code-esn
   "import java.util.ArrayList;"
;;   "import java.util.HashMap;"
   "import java.util.List;"
   ""
   "import org.waxeye.parser.AutomatonTransition;"
   "import org.waxeye.parser.CharTransition;"
   "import org.waxeye.parser.Edge;"
   "import org.waxeye.parser.FA;"
   "import org.waxeye.parser.State;"
   "import org.waxeye.parser.WildCardTransition;")
  (code-n))


(define (gen-constructor)
  (code-java-doc
   (string-append "Creates a new " *java-parser-name* "."))
  (java:con ('public) *java-parser-name* "()"
            (code-is "super(makeAutomata(), true, ")
            (code-s *start-index*)
            (code-s ", ")
            (code-s *java-node-name*)
            (code-s "._Empty, ")
            (code-s *java-node-name*)
            (code-s "._Char, ")
            (code-s *java-node-name*)
            (code-s "._Pos, ")
            (code-s *java-node-name*)
            (code-sn "._Neg);")))

(define (gen-make-automata automata)
  (code-java-doc
   "Builds the automata for the parser."
   ""
   "@return The automata for the parser.")
  (java:method ('private 'static "List<FA<Type>>") "makeAutomata" "()"
               (code-isn "List<Edge<Type>> edges;")
               (code-isn "List<State<Type>> states;")
               (code-isn "final List<FA<Type>> automata = new ArrayList<FA<Type>>();")
               (code-n)
               (for-each gen-fa (vector->list automata))
               (code-isn "return automata;")))


(define (gen-fa a)
  (code-is "states = new ArrayList<State<")
  (code-s *java-node-name*)
  (code-sn ">>();")
  (for-each gen-state (vector->list (fa-states a)))
  (code-is "automata.add(new FA<")
  (code-s *java-node-name*)
  (code-s ">(")
  (code-s *java-node-name*)
  (code-s ".")
  (let ((type (fa-type a)))
    (cond
     ((equal? type '&) (code-s "_Pos"))
     ((equal? type '!) (code-s "_Neg"))
     (else
      (code-s (camel-case-upper (symbol->string type))))))
  (code-s ", ")
  (code-s (case (fa-mode a)
            ((voidArrow) "FA.VOID")
            ((pruneArrow) "FA.PRUNE")
            ((leftArrow) "FA.LEFT")))
  (code-sn ", states));")
  (code-n))


(define (gen-state s)
  (code-is "edges = new ArrayList<Edge<")
  (code-s *java-node-name*)
  (code-sn ">>();")
  (for-each gen-edge (state-edges s))
  (code-is "states.add(new State<")
  (code-s *java-node-name*)
  (code-s ">(edges, ")
  (code-s (if (state-match s) "true" "false"))
  (code-sn "));"))


(define (gen-edge e)
  (code-is "edges.add(new Edge<")
  (code-s *java-node-name*)
  (code-s ">(new ")
  (gen-trans (edge-t e))
  (code-s ", ")
  (code-s (edge-s e))
  (code-s ", ")
  (code-s (if (edge-v e) "true" "false"))
  (code-sn "));"))


(define (gen-trans t)
  (cond
   ((equal? t 'wild) (gen-wild-card-trans))
   ((integer? t) (gen-automaton-trans t))
   ((char? t) (gen-char-trans t))
   ((pair? t) (gen-char-class-trans t))))


(define (gen-automaton-trans t)
  (code-s "AutomatonTransition<")
  (code-s *java-node-name*)
  (code-s ">(")
  (code-s t)
  (code-s ")"))


(define (gen-char-trans t)
  (code-s "CharTransition<")
  (code-s *java-node-name*)
  (code-s ">(new char[]{")
  (gen-char t)
  (code-s "}, new char[]{}, new char[]{})"))


(define (gen-char-class-trans t)
  (let* ((single (filter char? t))
         (ranges (filter pair? t))
         (min (map car ranges))
         (max (map cdr ranges)))
    (code-s "CharTransition<")
    (code-s *java-node-name*)
    (code-s ">(")
    (gen-char-list single)
    (code-s ", ")
    (gen-char-list min)
    (code-s ", ")
    (gen-char-list max)
    (code-s ")")))


(define (gen-char-list l)
  (code-s "new char[]{")
  (unless (null? l)
          (gen-char (car l))
          (for-each (lambda (a)
                      (code-s ", ")
                      (gen-char a))
                    (cdr l)))
  (code-s "}"))


(define (gen-char t)
  (code-s "'")
  (when (escape-for-java-char? t)
        (code-s "\\"))
  (code-s (cond
           ((equal? t #\linefeed) "\\n")
           ((equal? t #\tab) "\\t")
           ((equal? t #\return) "\\r")
           (else t)))
  (code-s "'"))


(define (gen-wild-card-trans)
  (code-s "WildCardTransition<")
  (code-s *java-node-name*)
  (code-s ">()"))

)
