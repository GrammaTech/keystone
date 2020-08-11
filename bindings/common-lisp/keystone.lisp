;;;; clos.lisp --- CLOS interface to the Keystone assembler
;;;;
;;;; Copyright (C) 2020 GrammaTech, Inc.
;;;;
;;;; This code is licensed under the MIT license. See the LICENSE file
;;;; in the project root for license terms.
;;;;
;;;; This project is sponsored by the Office of Naval Research, One
;;;; Liberty Center, 875 N. Randolph Street, Arlington, VA 22203 under
;;;; contract # N68335-17-C-0700.  The content of the information does
;;;; not necessarily reflect the position or policy of the Government
;;;; and no official endorsement should be inferred.
(defpackage :keystone
  (:use :gt :cffi :keystone/raw)
  (:export :version
           :keystone
           :assembly
           ;; KEYSTONE-ENGINE class and accessors
           :keystone-engine
           :architecture
           :mode
           ;; Assembler functionality
           :set-option
           :asm))
(in-package :keystone)
(in-readtable :curry-compose-reader-macros)
#+debug (declaim (optimize (debug 3)))

(defun version ()
  "Return the KEYSTONE version as two values MAJOR and MINOR."
  (let* ((encoded-version (ks-version 0 0))
         (major (ash encoded-version -8)))
    (values major (- encoded-version (ash major 8)))))

(define-condition keystone (error)
  ((code :initarg :code :initform nil :reader code)
   (strerr :initarg :strerr :initform nil :reader strerr))
  (:report (lambda (condition stream)
             (format stream "Keystone error ~S." (strerr condition))))
  (:documentation "Keystone error."))

(define-condition assembly (keystone)
  ((instructions :initarg :instructions :initform nil :reader instructions))
  (:report (lambda (condition stream)
             (format stream "Assembly error ~S on ~S."
                     (strerr condition) (bytes condition))))
  (:documentation "Keystone assembly error."))

(defclass keystone-engine ()
  ((architecture :initarg :architecture :reader architecture :type keyword
                 :initform (required-argument :architecture))
   (mode :initarg :mode :reader mode :type keyword
         :initform (required-argument :mode))
   (handle)))

(defmethod initialize-instance :after ((engine keystone-engine) &key)
  (with-slots (architecture mode handle) engine
    (setf handle (foreign-alloc 'ks-engine))
    (let* ((actual-mode (if (listp mode)
                           (reduce #'logior mode
                                   :key {foreign-enum-value 'ks-mode}
                                   :initial-value 0)
                           mode))
           (errno (ks-open architecture actual-mode handle)))
      (unless (eql :ok errno)
        (error (make-condition 'keystone
                               :code errno
                               :strerr (ks-strerror errno)))))
    #+sbcl (sb-impl::finalize engine
                              (lambda ()
                                (with-slots (handle) engine
                                  (ks-close handle))))))

(defmethod print-object ((obj keystone-engine) stream)
  (print-unreadable-object (obj stream :type t :identity t)
    (format stream "~a ~a" (architecture obj) (mode obj))))

(defgeneric set-option (engine type value)
  (:documentation "Set ENGINE's option TYPE to VALUE.")
  (:method ((engine keystone-engine) (type symbol) (value symbol))
    (ks-option (mem-ref (slot-value engine 'handle) 'ks-engine) type value)))

(defgeneric asm (engine code &key address)
  (:documentation
   "Assemble CODE into machine code using options set in ENGINE.
Use ; or \n to separate statements.  ADDRESS may be provided to give
the address of the first assembly instruction.  Returns the bytes of
the resulting machine code instructions, the size of the resulting
instructions and the number of statements are returned as additional
values.")
  (:method ((engine keystone-engine) code &key address)
    (nest
     (with-slots (handle) engine)
     (with-foreign-object (encode '(:pointer :unsigned-char)))
     (with-foreign-object (size 'size-t))
     (with-foreign-object (count 'size-t)
       (unless (eql :ok (ks-asm (mem-ref handle 'ks-engine)
                                code
                                (or address 0)
                                encode
                                size
                                count))
         (error (make-condition 'assembly
                                :instructions code
                                :code (ks-errno handle)
                                :strerr (ks-strerror (ks-errno handle)))))
       (unwind-protect
            (let* ((cl-size (mem-ref size 'size-t))
                   (out (make-array cl-size :element-type '(unsigned-byte 8))))
              (dotimes (n cl-size)
                (setf (aref out n)
                      (mem-aref (mem-ref encode :pointer) :unsigned-char n)))
              (values out cl-size (mem-ref count 'size-t)))
         (ks-free (mem-ref encode :pointer)))))))
