;;; helm-source.el --- Helm source creation.

;; Copyright (C) 2014  Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; Author: Thierry Volpiatto <thierry.volpiatto@gmail.com>
;; URL: http://github.com/emacs-helm/helm

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Interface to create helm sources easily.
;; Actually the eieo object are transformed in alist for compatibility.
;; In the future this package should allow creating source as eieo objects
;; without conversion to alist, teaching helm to read such a structure.
;; The compatibility with alists would be kept.
;; This would allow faster access to sources, getting rid of the actual hackish
;; plugin interface (the plugins will be embeded in classes) and a better
;; access to documentation.

;;; Code:

(require 'cl-lib)
(require 'eieio)

(defclass helm-source ()
  ((name
    :initarg :name
    :initform ""
    :custom string
    :documentation
    "  The name of the source.
  A string which is also the heading which appears
  above the list of matches from the source. Must be unique.")

   (header-name
    :initarg :header-name
    :initform nil
    :custom function
    :documentation
    "  A function returning the display string of the header.
  Its argument is the name of the source. This attribute is useful to
  add an additional information with the source name.
  It doesn't modify the name of the source.")
   
   (init
    :initarg :init
    :initform nil
    :custom function
    :documentation
    "  Function called with no parameters when helm is started.
  It is useful for collecting current state information which can be
  used to create the list of candidates later.
  Initialization of `candidates-in-buffer' is done here
  with `helm-init-candidates-in-buffer'.")

   (candidates
    :initarg :candidates
    :initform nil
    :custom (choice function list)
    :documentation
    "  Specifies how to retrieve candidates from the source.
  It can either be a variable name, a function called with no parameters
  or the actual list of candidates.
  
  The list must be a list whose members are strings, symbols
  or (DISPLAY . REAL) pairs.
  
  In case of (DISPLAY . REAL) pairs, the DISPLAY string is shown
  in the Helm buffer, but the REAL one is used as action
  argument when the candidate is selected. This allows a more
  readable presentation for candidates which would otherwise be,
  for example, too long or have a common part shared with other
  candidates which can be safely replaced with an abbreviated
  string for display purposes.
  
  Note that if the (DISPLAY . REAL) form is used then pattern
  matching is done on the displayed string, not on the real
  value.")
   
   (update
    :initarg :update
    :initform nil
    :custom function
    :documentation
    "  Function called with no parameters at end of reinitialization
  when `helm-force-update' is called.")

   (cleanup
    :initarg :cleanup
    :initform nil
    :custom function
    :documentation
    "  Function called with no parameters when *helm* buffer is
  closed. It is useful for killing unneeded candidates buffer.

  Note that the function is executed BEFORE performing action.")
   
   (delayed
    :initarg :delayed
    :initform nil
    :custom (choice null integer)
    :documentation
    "  Candidates from the source are shown only if the user stops
  typing and is idle for `helm-idle-delay' seconds.
  If a value is given to delayed attr, this value is used instead only
  if it is > to `helm-idle-delay'.")
   
   (keymap
    :initarg :keymap
    :initform nil
    :custom sexp
    :documentation
    "  Specific keymap for this source.
  It is useful to have a keymap per source when using more than
  one source.  Otherwise, a keymap can be set per command with
  `helm' argument KEYMAP.  NOTE: when a source have `helm-map' as
  keymap attr, the global value of `helm-map' will override the
  actual local one.")
   
   (action
    :initarg :action
    :initform 'identity
    :custom (alist :key-type string
                   :value-type function)
    :documentation
      "  It is a list of (DISPLAY . FUNCTION) pairs or FUNCTION.
  FUNCTION is called with one parameter: the selected candidate.

  An action other than the default can be chosen from this list
  of actions for the currently selected candidate (by default
  with TAB). The DISPLAY string is shown in the completions
  buffer and the FUNCTION is invoked when an action is
  selected. The first action of the list is the default.

  You should use `helm-make-actions' to build this alist easily.")

   (persistent-action
    :initarg :persistent-action
    :initform nil
    :custom function
    :documentation
      "  Can be a either a Function called with one parameter (the
  selected candidate) or a cons cell where first element is this
  same function and second element a symbol (e.g never-split)
  that inform `helm-execute-persistent-action'to not split his
  window to execute this persistent action.")

   (persistent-help
    :initarg :persistent-help
    :initform nil
    :custom string
    :documentation
    "  A string to explain persistent-action of this source. It also
  accepts a function or a variable name.
  It will be displayed in source header.")

   (help-message
    :initarg :help-message
    :initform nil
    :custom (choice string function)
    :documentation
    "  Help message for this source.
  If not present, `helm-help-message' value will be used.")
   
   (type
    :initarg :type
    :initform nil
    :type symbol
    :documentation
    "  Indicates the type of the items the source returns.

  Merge attributes not specified in the source itself from
  `helm-type-attributes'.

  This attribute is implemented by plug-in.")

   (multiline
    :initarg :multiline
    :initform nil
    :custom boolean
    :documentation
    "  Enable to selection multiline candidates.")
   
   (requires-pattern
    :initarg :requires-pattern
    :initform nil
    :custom integer
    :documentation
      "  If present matches from the source are shown only if the
  pattern is not empty. Optionally, it can have an integer
  parameter specifying the required length of input which is
  useful in case of sources with lots of candidates.")

   (candidate-transformer
    :initarg :candidate-transformer
    :initform nil
    :custom (choice function list)
    :documentation
  "  It's a function or a list of functions called with one argument
  when the completion list from the source is built. The argument
  is the list of candidates retrieved from the source. The
  function should return a transformed list of candidates which
  will be used for the actual completion.  If it is a list of
  functions, it calls each function sequentially.

  This can be used to transform or remove items from the list of
  candidates.

  Note that `candidates' is run already, so the given transformer
  function should also be able to handle candidates with (DISPLAY
  . REAL) format.")
    
   (filtered-candidate-transformer
    :initarg :filtered-candidate-transformer
    :initform nil
    :custom (choice function list)
    :documentation
      "  It has the same format as `candidate-transformer', except the
  function is called with two parameters: the candidate list and
  the source.

  This transformer is run on the candidate list which is already
  filtered by the current pattern. While `candidate-transformer'
  is run only once, it is run every time the input pattern is
  changed.

  It can be used to transform the candidate list dynamically, for
  example, based on the current pattern.

  In some cases it may also be more efficent to perform candidate
  transformation here, instead of with `candidate-transformer'
  even if this transformation is done every time the pattern is
  changed.  For example, if a candidate set is very large then
  `candidate-transformer' transforms every candidate while only
  some of them will actually be displayed due to the limit
  imposed by `helm-candidate-number-limit'.

  Note that `candidates' and `candidate-transformer' is run
  already, so the given transformer function should also be able
  to handle candidates with (DISPLAY . REAL) format.")

   (filter-one-by-one
    :initarg :filter-one-by-one
    :initform nil
    :custom (choice function list)
    :documentation
      "  A transformer function that treat candidates one by one.
  It is called with one arg the candidate.
  It is faster than `filtered-candidate-transformer' or `candidates-transformer',
  but should be used only in sources that recompute constantly their candidates,
  e.g `helm-source-find-files'.
  Filtering happen early and candidates are treated
  one by one instead of re-looping on the whole list.
  If used with `filtered-candidate-transformer' or `candidates-transformer'
  these functions should treat the candidates transformed by the `filter-one-by-one'
  function in consequence.")

   (display-to-real
    :initarg :display-to-real
    :initform nil
    :custom function
    :documentation
    "  Function called with one parameter; the selected candidate.

  The function transforms the selected candidate, and the result
  is passed to the action function.  The display-to-real
  attribute provides another way to pass to action other string than
  the one shown in Helm buffer.

  Traditionally, it is possible to make candidates,
  candidate-transformer or filtered-candidate-transformer
  function return a list with (DISPLAY . REAL) pairs. But if REAL
  can be generated from DISPLAY, display-to-real is more
  convenient and faster.

  NOTE: This is deprecated and you have better time using `filter-one-by-one'.")

   (real-to-display
    :initarg :real-to-display
    :initform nil
    :custom function
    :documentation
    "  Function called with one parameter; the selected candidate.
  The real value of candidates will be shown in display.
  See `display-to-real'.")

   (action-transformer
    :initarg :action-transformer
    :initform nil
    :custom (choice function list)
    :documentation
      "  It's a function or a list of functions called with two
  arguments when the action list from the source is
  assembled. The first argument is the list of actions, the
  second is the current selection.  If it is a list of functions,
  it calls each function sequentially.

  The function should return a transformed action list.

  This can be used to customize the list of actions based on the
  currently selected candidate.")

   (pattern-transformer
    :initarg :pattern-transformer
    :initform nil
    :custom (choice function list)
    :documentation
      "  It's a function or a list of functions called with one argument
  before computing matches. Its argument is `helm-pattern'.
  Functions should return transformed `helm-pattern'.

  It is useful to change interpretation of `helm-pattern'.")

   (candidate-number-limit
    :initarg :candidate-number-limit
    :initform nil
    :custom integer
    :documentation
    "  Override `helm-candidate-number-limit' only for this source.")

   (volatile
    :initarg :volatile
    :initform nil
    :custom boolean
    :documentation
      "  Indicates the source assembles the candidate list dynamically,
  so it shouldn't be cached within a single Helm
  invocation. It is only applicable to synchronous sources,
  because asynchronous sources are not cached.")

   (match
    :initarg :match
    :initform nil
    :custom (choice function list)
    :documentation
      "  List of functions called with one parameter: a candidate. The
  function should return non-nil if the candidate matches the
  current pattern (see variable `helm-pattern').

  When using `candidates-in-buffer' its default value is `identity' and
  don't have to be changed, use the `search' slot instead.

  This attribute allows the source to override the default
  pattern matching based on `string-match'. It can be used, for
  example, to implement a source for file names and do the
  pattern matching on the basename of files, since it's more
  likely one is typing part of the basename when searching for a
  file, instead of some string anywhere else in its path.

  If the list contains more than one function then the list of
  matching candidates from the source is constructed by appending
  the results after invoking the first function on all the
  potential candidates, then the next function, and so on. The
  matching candidates supplied by the first function appear first
  in the list of results and then results from the other
  functions, respectively.

  This attribute has no effect for asynchronous sources (see
  attribute `candidates'), since they perform pattern matching
  themselves.")

   (nomark
    :initarg :nomark
    :initform nil
    :custom boolean
    :documentation
    "  Don't allow marking candidates when this attribute is present.")
   
   (nohighlight
    :initarg :nohighlight
    :initform nil
    :custom boolean
    :documentation
    "  Disable highlight match in this source.")
   
   (no-matchplugin
    :initarg :no-matchplugin
    :initform nil
    :custom boolean
    :documentation
    "  Disable matchplugin for this source.")

   (allow-dups
    :initarg :allow-dups
    :initform nil
    :custom boolean
    :documentation
    "  Allow helm collecting duplicates candidates.")

   (recenter
    :initarg :recenter
    :initform nil
    :custom boolean
    :documentation
    "  `recenter' after jumping to candidate.")

   (history
    :initarg :history
    :initform nil
    :custom symbol
    :documentation
    "  Allow passing history variable to helm from source.
  It should be a quoted symbol.")
   
   (coerce
    :initarg :coerce
    :initform nil
    :custom function
    :documentation
      "  It's a function called with one argument: the selected candidate.

  This function is intended for type convertion. In normal case,
  the selected candidate (string) is passed to action
  function. If coerce function is specified, it is called just
  before action function.

  Example: converting string to symbol
    (coerce . intern)")

   (mode-line
    :initarg :mode-line
    :initform nil
    :custom (choice string sexp)
    :documentation
    "  Source local `helm-mode-line-string' (included in
  `mode-line-format'). It accepts also variable/function name.")

   (header-line
    :initarg :header-line
    :initform 'helm-persistent-help-string
    :custom (choice string function)
    :documentation
    "  Source local `header-line-format'.
  It accepts also variable/function name.")

   (resume
    :initarg :resume
    :initform nil
    :custom function
    :documentation
      "  Function called with no parameters at end of initialization
  when `helm-resume' is started.
  If this function try to do something against `helm-buffer', \(e.g updating,
  searching etc...\) probably you should run it in a timer to ensure
  `helm-buffer' is ready.")

   (follow
    :initarg :follow
    :initform nil
    :custom integer
    :documentation
    "  Enable `helm-follow-mode' for this source only.
  You must give it a value of 1 or -1, though giving a -1 value
  is surely not what you want, e.g: (follow . 1)

  See `helm-follow-mode' for more infos.")

   (follow-delay
    :initarg :follow-delay
    :initform nil
    :custom integer
    :documentation
    "  `helm-follow-mode' will execute persistent-action after this delay.
Otherwise value of `helm-follow-input-idle-delay' is used if non--nil,
If none of these are found fallback to `helm-input-idle-delay'.")

   (dont-plug
    :initarg :dont-plug
    :initform nil
    :custom list
    :documentation
    "  A list of compile functions plugin to ignore.")

   (migemo
    :initarg :migemo
    :initform nil
    :custom boolean
    :documentation
    "If you are not Japonese, ignore this."))
  
  "Main interface to define helm sources."
  :abstract t)

(defclass helm-source-sync (helm-source)
  ((candidates
    :initform '("ERROR: You must specify the `candidates' slot, either with a list or a function"))
   
   (match-strict
    :initarg :match-strict
    :initform nil
    :custom function
    :documentation
    "  When specifying a match function within a source and
  helm-match-plugin is enabled, the result of all matching
  functions will be concatened, which in some cases is not what
  is wanted. When using `match-strict' only this or these
  functions will be used. You can specify those functions as a
  list of functions or a single symbol function.")))

(defclass helm-source-async (helm-source)
  ((candidates-process
    :initarg :candidates-process
    :initform nil
    :custom function
    :documentation
    "  You should use this attribute when using a function involving
  an async process instead of `candidates'.
  The function must return a process.")))

(defclass helm-source-in-buffer (helm-source)
  ((candidates-in-buffer
    :initarg :candidates-in-buffer
    :initform t
    :custom boolean
    :documentation
    "It is just here to notify to the match-plugin we are using
`candidates-in-buffer',so there is no need to change the value of this slot.")

   (init
    :initform (lambda ()
                (helm-init-candidates-in-buffer 'global
                  '("ERROR: You must build a buffer handling your data with a function in the `init' slot or use the `data' slot."))))

   (data
    :initarg :data
    :initform nil
    :custom (choice list string)
    :documentation
    "  A string or a list that will be used to initialize the buffer that handle this data.
  This data will be passed to the init slot function and the buffer will be build with
  `helm-init-candidates-in-buffer'.")
   
   (dont-plug
    :initform '(helm-compile-source--candidates-in-buffer))
   
   (candidates
    :initform 'helm-candidates-in-buffer)

   (volatile
    :initform t)
   
   (match
    :initform '(identity))
   
   (get-line
    :initarg :get-line
    :initform 'buffer-substring-no-properties
    :custom function
    :documentation
    "  A function like `buffer-substring-no-properties' or `buffer-substring'.
  This function converts point of line-beginning and point of line-end,
  which represents a candidate computed by `helm-candidates-in-buffer'.
  By default, `helm-candidates-in-buffer' uses
  `buffer-substring-no-properties'.")

   (search
    :initarg :search
    :initform '(helm-candidates-in-buffer-search-from-start)
    :custom (choice function list)
    :documentation
    "  List of functions like `re-search-forward' or `search-forward'.
  Buffer search function used by `helm-candidates-in-buffer'.
  By default, `helm-candidates-in-buffer' uses `re-search-forward'.")

   (search-from-end
    :initarg :search-from-end
    :initform nil
    :custom boolean
    :documentation
    "  Make `helm-candidates-in-buffer' search from the end of buffer.
  If this attribute is specified, `helm-candidates-in-buffer'
  uses `re-search-backward' instead.

  NOTE: This is here for compatibilty, but it is not used anymore.")

   (search-strict
    :initarg :search-strict
    :initform nil
    :custom function
    :documentation
    "  When specifying a search function within a source and
  helm-match-plugin is enabled, the result of all searching
  functions will be concatened, which in some cases is not what
  is wanted. When using `search-strict' only this or these
  functions will be used. You can specify those functions as a
  list of functions or a single symbol function.")

   (match-part
    :initarg :match-part
    :initform nil
    :custom function
    :documentation
    "  Allow matching candidate in the line with `candidates-in-buffer'.
  In candidates-in-buffer sources, match is done with
  `re-search-forward' which allow matching only a regexp on the
  `helm-buffer'; when this search is done, match-part allow
  matching only a specific part of the current line e.g with a
  line like this:

  filename:candidate-containing-the-word-filename

  What you want is to ignore "filename" part and match only
  "candidate-containing-the-word-filename"

  So give a function matching only the part of candidate after ":"

  If source contain match-part attribute, match is computed only
  on part of candidate returned by the call of function provided
  by this attribute. The function should have one arg, candidate,
  and return only a specific part of candidate.")))

(defclass helm-source-dummy (helm-source)
  ((candidates
    :initform '("dummy"))

   (filtered-candidate-transformer
    :initform 'helm-dummy-candidate)
   
   (accept-empty
    :initarg :accept-empty
    :initform t
    :custom boolean
    :documentation
    "  Allow exiting with an empty string.
  You should keep the default value.")

   (match
    :initform 'identity)
   
   (volatile
    :initform t)))

(defun helm--create-source (object class)
  "[INTERNAL] Build a helm source from a CLASS OBJECT."
  (cl-loop for s in (object-slots object)
           for slot = (class-slot-initarg class s)
           for slot-val = (slot-value object slot)
           when slot-val
           collect (cons s (unless (eq t slot-val) slot-val))))

(defmethod helm--setup-source ((source helm-source-sync)))

(defmethod helm--setup-source ((source helm-source-in-buffer))
  (helm-aif (slot-value source :data)
      (oset source :init `(lambda ()
                            (helm-init-candidates-in-buffer
                                'global
                              ',it))))
  (let ((mtc (slot-value source :match)))
    (cl-assert (or (equal '(identity) mtc)
                   (eq 'identity mtc))
               nil "Invalid slot value for `match'")
    (cl-assert (eq (slot-value source :candidates-in-buffer) t)
               nil "Invalid slot value for `candidates-in-buffer'")
    (cl-assert (eq (slot-value source :volatile) t)
               nil "Invalid slot value for `volatile'")))

(defmethod helm--setup-source ((source helm-source-async))
  (cl-assert (null (slot-value source :candidates))
             nil "Incorrect use of `candidates' use `candidates-process' instead"))

(defmethod helm--setup-source ((source helm-source-dummy)))

(defun helm--make-source (name class &rest args)
  "Build a `helm' source named NAME with ARGS for CLASS.
Argument NAME is a string which define the source name, so no need to use
the keyword :name in your source, NAME will be used instead.
Argument CLASS is an eieio class object.
Arguments ARGS are keyword value pairs as defined in CLASS."
  (let ((source (apply #'make-instance class name args)))
    (oset source :name name)
    (helm--setup-source source)
    (helm--create-source source (eieio-object-class source))))

(defmacro helm-build-sync-source (name &rest args)
  "Build a synchronous helm source with name NAME.
Args ARGS are keywords provided by `helm-source-sync'."
  `(helm--make-source ,name 'helm-source-sync ,@args))

(defmacro helm-build-async-source (name &rest args)
  "Build a asynchronous helm source with name NAME.
Args ARGS are keywords provided by `helm-source-async'."
  `(helm--make-source ,name 'helm-source-async ,@args))

(defmacro helm-build-in-buffer-source (name &rest args)
  "Build a helm source with name NAME using `candidates-in-buffer' method.
Args ARGS are keywords provided by `helm-source-in-buffer'."
  `(helm--make-source ,name 'helm-source-in-buffer ,@args))

(defmacro helm-build-dummy-source (name &rest args)
  "Build a helm source with name NAME using `dummy' method.
Args ARGS are keywords provided by `helm-source-dummy'."
  `(helm--make-source ,name 'helm-source-dummy ,@args))

(provide 'helm-source)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-source ends here
