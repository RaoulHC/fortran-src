### 0.3.0 (June 13, 2019)

* Add partial Fortran2003 support.
* Introduce datatype for BBGr instead of prior type alias for Gr.
  * Now split into three fields: bbgrGr, bbgrEntries and bbgrExits
  * May require refactoring of code to use bbgrGr field where a Gr was expected before.
* Introduce pragmaOffset field for Position, allowing pragmas to specify an apparent file and line-number.
  * May require refactoring of code that uses the Position constructor.
  * Fifth field is Maybe (Int, String), containing a line-offset and a target filename when present.
  * It's designed such that most Position-based transformations are not affected by the pragmaOffset.
  * They may need to preserve the field, though, as it passes through functions.
  * Default value is 'Nothing'.
* Add --show-flows-to/--show-flows-from features
  * Visualise the dataflow use/def chains using GraphViz.
* Add --show-block-numbers feature.
  * Allows user to get AST-block numbers easily in order to use them with the above visualisation features.
* Fix several bugs with dataflow analysis that had accumulated.
* Eliminate StContinue and StEnddo are eliminated during GroupLabeledDo transformations.
  * To be consistent with unlabeled Do.
* Parse and discard C-comments as a convenience feature for when fortran-src must interact with the output of C preprocessors that insert spurious comments.
* Add type propagation into type analysis, annotating every expression with a type.
  * Additional interface: analyseTypesWithEnv to access a list of type errors found.
* Add dimensional information to CTArray and length/kind to TypeCharacter.
* Stricter checking of the grouping transform - if any statements that should be grouped are not grouped, raise an error.
* Support pragmas that alter the current 'filename and position' tracker, often used by preprocessors to help pinpoint original code locations.
  * Uses a relative offset field called 'posPragmaOffset' so that relative measures continue to function correctly.
* Add constant propagation / parameter variable analysis.
* Add -c feature to compile 'fsmod files' with renaming and type info.

### 0.2.1.1 (May 18, 2018)

* Extend Fortran 95 support
* Extend support for legacy extensions

### 0.2.1.1 (December 13, 2017)

* Fortran95Experimental module renamed to Fortran95
* No infinite loops due to symlinks.
* Fortran 95 support.
  * AST extended to support more non-standard statements internally.
