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
(eval-when (:load-toplevel :execute)
  (operate 'load-op 'trivial-features)
  (operate 'load-op 'cffi-grovel))

(use-package 'cffi-grovel)

(defsystem "keystone"
  :author "GrammaTech"
  :licence "MIT"
  :description "Common Lisp CLOS interface to the Keystone assembler"
  :depends-on (:gt :cffi :static-vectors :keystone/raw)
  :components ((:file "keystone"))
  :in-order-to ((test-op (load-op "keystone/test")))
  :perform (test-op (o c) (symbol-call :keystone/test '#:test)))

(defsystem "keystone/test"
  :author "GrammaTech"
  :licence "MIT"
  :depends-on (:gt :cffi :keystone/raw :keystone :stefil)
  :components ((:file "test")))

(defsystem "keystone/raw"
    :name "keystone"
    :author "GrammaTech"
    :licence "MIT"
    :description "Raw Common Lisp FFI interface to the Keystone assembler"
    :depends-on (:gt :cffi :static-vectors)
    :defsystem-depends-on (:cffi-grovel)
    :components ((:file "package")
                 (:cffi-grovel-file "grovel")
                 (:file "raw"))
    :in-order-to ((test-op (load-op "keystone/raw-test")))
    :perform (test-op (o c) (symbol-call :keystone/raw-test '#:test)))

(defsystem "keystone/raw-test"
  :author "GrammaTech"
  :licence "MIT"
  :depends-on (:gt :cffi :static-vectors :keystone/raw :stefil)
  :components ((:file "raw-test")))
