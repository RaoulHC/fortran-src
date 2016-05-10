-- -*- Mode: Haskell -*-
{
module Language.Fortran.Parser.Fortran66(expressionParser,
                               statementParser,
                               fortran66Parser) where

import Prelude hiding (EQ,LT,GT) -- Same constructors exist in the AST

import Data.Maybe (isNothing, fromJust)

import Language.Fortran.Util.Position
import Language.Fortran.ParserMonad
import Language.Fortran.Lexer.FixedForm
import Language.Fortran.Transformer (transform, Transformation(..))
import Language.Fortran.AST

}

%name programParser PROGRAM
%name statementParser STATEMENT
%name expressionParser EXPRESSION
%monad { LexAction }
%lexer { lexer } { TEOF _ }
%tokentype { Token }
%error { parseError }

%token
  '('                   { TLeftPar _ }
  ')'                   { TRightPar _ }
  ','                   { TComma _ }
  '.'                   { TDot _ }
  function              { TFunction _ }
  subroutine            { TSubroutine _ }
  blockData             { TBlockData _ }
  end                   { TEnd _ }
  '='                   { TOpAssign _ }
  assign                { TAssign _ }
  to                    { TTo _ }
  goto                  { TGoto _ }
  if                    { TIf _ }
  call                  { TCall _ }
  return                { TReturn _ }
  continue              { TContinue _ }
  stop                  { TStop _ }
  pause                 { TPause _ }
  do                    { TDo _ }
  read                  { TRead _ }
  write                 { TWrite _ }
  rewind                { TRewind _ }
  backspace             { TBackspace _ }
  endfile               { TEndfile _ }
  common                { TCommon _ }
  equivalence           { TEquivalence _ }
  external              { TExternal _ }
  dimension             { TDimension _ }
  integer               { TType _ "integer" }
  real                  { TType _ "real" }
  doublePrecision       { TType _ "doubleprecision" }
  logical               { TType _ "logical" }
  complex               { TType _ "complex" }
  data                  { TData _ }
  format                { TFormat _ }
  fieldDescriptorDEFG   { TFieldDescriptorDEFG _ _ _ _ _ }
  fieldDescriptorAIL    { TFieldDescriptorAIL _ _ _ _ }
  blankDescriptor       { TBlankDescriptor _ _ }
  scaleFactor           { TScaleFactor _ _ }
  int                   { TInt _ _ }
  exponent              { TExponent _ _ }
  bool                  { TBool _ _ }
  '+'                   { TOpPlus _ }
  '-'                   { TOpMinus _ }
  '**'                  { TOpExp _ }
  '*'                   { TStar _ }
  '/'                   { TSlash _ }
  or                    { TOpOr _ }
  and                   { TOpAnd _ }
  not                   { TOpNot _ }
  '<'                   { TOpLT _ }
  '<='                  { TOpLE _ }
  '>'                   { TOpGT _ }
  '>='                  { TOpGE _ }
  '=='                  { TOpEQ _ }
  '!='                  { TOpNE _ }
  id                    { TId _ _ }
  comment               { TComment _ _ }
  hollerith             { THollerith _ _ }
  label                 { TLabel _ _ }
  newline               { TNewline _ }

%left or
%left and
%right not

%nonassoc '>' '<' '>=' '<=' '==' '!='
%nonassoc RELATIONAL

%left '+' '-'
%left '*' '/'
%right NEGATION
%right '**'

%%

PROGRAM :: { ProgramFile A0 }
PROGRAM
: PROGRAM_UNITS { ProgramFile (reverse $1) [ ] }
| PROGRAM_UNITS BLOCKS { ProgramFile (reverse $1) (reverse $2) }

PROGRAM_UNITS :: { [ ([ Block A0 ], ProgramUnit A0) ] }
PROGRAM_UNITS
: PROGRAM_UNITS MAIN_PROGRAM_UNIT { ([ ], $2) : $1 }
| PROGRAM_UNITS OTHER_PROGRAM_UNIT { ([ ], $2) : $1 }
| PROGRAM_UNITS BLOCKS OTHER_PROGRAM_UNIT { (reverse $2, $3) : $1 }
| MAIN_PROGRAM_UNIT { [ ([ ], $1) ] }
| OTHER_PROGRAM_UNIT { [ ([ ], $1) ] }
| BLOCKS OTHER_PROGRAM_UNIT { [ (reverse $1, $2) ] }

MAIN_PROGRAM_UNIT :: { ProgramUnit A0 }
MAIN_PROGRAM_UNIT
: BLOCKS end NEWLINE
  { let blocks = reverse $1
    in PUMain () (getTransSpan $1 $2) Nothing blocks Nothing }

OTHER_PROGRAM_UNIT :: { ProgramUnit A0 }
OTHER_PROGRAM_UNIT
: TYPE_SPEC function NAME '(' VARIABLES ')' NEWLINE BLOCKS end NEWLINE
  { PUFunction () (getTransSpan $1 $9) (Just $1) False $3 (fromReverseList $5) Nothing (reverse $8) }
| function NAME '(' VARIABLES ')' NEWLINE BLOCKS end NEWLINE
  { PUFunction () (getTransSpan $1 $8) Nothing False $2 (fromReverseList $4) Nothing (reverse $7) }
| subroutine NAME '(' VARIABLES ')' NEWLINE BLOCKS end NEWLINE
  { PUSubroutine () (getTransSpan $1 $8) False $2 (fromReverseList $4) (reverse $7) }
| blockData NEWLINE BLOCKS end NEWLINE { PUBlockData () (getTransSpan $1 $4) Nothing (reverse $3) }

NAME :: { Name } : id { let (TId _ name) = $1 in name }

BLOCKS :: { [ Block A0 ] }
BLOCKS
: BLOCKS BLOCK { $2 : $1 }
| BLOCK { [ $1 ] }

BLOCK :: { Block A0 }
BLOCK
: LABEL_IN_6COLUMN STATEMENT NEWLINE { BlStatement () (getTransSpan $1 $2) (Just $1) $2 }
| STATEMENT NEWLINE { BlStatement () (getSpan $1) Nothing $1 }
| comment NEWLINE { let (TComment s c) = $1 in BlComment () s c }

NEWLINE :: { Token }
NEWLINE
: NEWLINE newline { $1 }
| newline { $1 }

STATEMENT :: { Statement A0 }
STATEMENT
: LOGICAL_IF_STATEMENT { $1 }
| DO_STATEMENT { $1 }
| OTHER_EXECUTABLE_STATEMENT { $1 }
| NONEXECUTABLE_STATEMENT { $1 }

LOGICAL_IF_STATEMENT :: { Statement A0 }
LOGICAL_IF_STATEMENT : if '(' EXPRESSION ')' OTHER_EXECUTABLE_STATEMENT { StIfLogical () (getTransSpan $1 $5) $3 $5 }

DO_STATEMENT :: { Statement A0 }
DO_STATEMENT
: do LABEL_IN_STATEMENT DO_SPECIFICATION { StDo () (getTransSpan $1 $3) Nothing (Just $2) $3 }

DO_SPECIFICATION :: { DoSpecification A0 }
DO_SPECIFICATION
: EXPRESSION_ASSIGNMENT_STATEMENT ',' INT_OR_VAR ',' INT_OR_VAR { DoSpecification () (getTransSpan $1 $5) $1 $3 (Just $5) }
| EXPRESSION_ASSIGNMENT_STATEMENT ',' INT_OR_VAR                { DoSpecification () (getTransSpan $1 $3) $1 $3 Nothing }

INT_OR_VAR :: { Expression A0 } : INTEGER_LITERAL { $1 } | VARIABLE { $1 }

OTHER_EXECUTABLE_STATEMENT :: { Statement A0 }
OTHER_EXECUTABLE_STATEMENT
: EXPRESSION_ASSIGNMENT_STATEMENT { $1 }
| assign LABEL_IN_STATEMENT to VARIABLE { StLabelAssign () (getTransSpan $1 $4) $2 $4 }
| goto LABEL_IN_STATEMENT { StGotoUnconditional () (getTransSpan $1 $2) $2 }
| goto VARIABLE LABELS_IN_STATEMENT { StGotoAssigned () (getTransSpan $1 $3) $2 $3 }
| goto LABELS_IN_STATEMENT VARIABLE { StGotoComputed () (getTransSpan $1 $3) $2 $3 }
| if '(' EXPRESSION ')' LABEL_IN_STATEMENT ',' LABEL_IN_STATEMENT ',' LABEL_IN_STATEMENT { StIfArithmetic () (getTransSpan $1 $9) $3 $5 $7 $9 }
| call VARIABLE ARGUMENTS
  { StCall () (getTransSpan $1 $3) $2 (Just $3) }
| call VARIABLE { StCall () (getTransSpan $1 $2) $2 Nothing }
| return { StReturn () (getSpan $1) Nothing }
| continue { StContinue () $ getSpan $1 }
| stop INTEGER_LITERAL { StStop () (getTransSpan $1 $2) $ Just $2 }
| stop { StStop () (getSpan $1) Nothing }
| pause INTEGER_LITERAL { StPause () (getTransSpan $1 $2) $ Just $2 }
| pause { StPause () (getSpan $1) Nothing }
| rewind UNIT { StRewind2 () (getTransSpan $1 $2) $2 }
| backspace UNIT { StBackspace2 () (getTransSpan $1 $2) $2 }
| endfile UNIT { StEndfile2 () (getTransSpan $1 $2) $2 }
| write READ_WRITE_ARGUMENTS { let (cilist, iolist) = $2 in StWrite () (getTransSpan $1 $2) cilist iolist }
| read READ_WRITE_ARGUMENTS { let (cilist, iolist) = $2 in StRead () (getTransSpan $1 $2) cilist iolist }

EXPRESSION_ASSIGNMENT_STATEMENT :: { Statement A0 }
EXPRESSION_ASSIGNMENT_STATEMENT : ELEMENT '=' EXPRESSION { StExpressionAssign () (getTransSpan $1 $3) $1 $3 }

NONEXECUTABLE_STATEMENT :: { Statement A0 }
NONEXECUTABLE_STATEMENT
: external FUNCTION_NAMES { StExternal () (getTransSpan $1 $2) (aReverse $2) }
| dimension ARRAY_DECLARATORS { StDimension () (getTransSpan $1 $2) (aReverse $2) }
| common COMMON_GROUPS { StCommon () (getTransSpan $1 $2) (aReverse $2) }
| equivalence EQUIVALENCE_GROUPS { StEquivalence () (getTransSpan $1 $2) (aReverse $2) }
| data DATA_GROUPS { StData () (getTransSpan $1 $2) (aReverse $2) }
| format FORMAT_ITEMS ')' { StFormat () (getTransSpan $1 $3) (aReverse $2) }
| TYPE_SPEC DECLARATORS { StDeclaration () (getTransSpan $1 $2) $1 Nothing (aReverse $2) }

READ_WRITE_ARGUMENTS :: { (AList ControlPair A0, Maybe (AList Expression A0)) }
READ_WRITE_ARGUMENTS
: '(' UNIT ')' IO_ELEMENTS { (AList () (getSpan $2) [ ControlPair () (getSpan $2) Nothing $2 ], Just (aReverse $4)) }
| '(' UNIT ',' FORM ')' IO_ELEMENTS { (AList () (getTransSpan $2 $4) [ ControlPair () (getSpan $2) Nothing $2, ControlPair () (getSpan $4) Nothing $4 ], Just (aReverse $6)) }
| '(' UNIT ')' { (AList () (getSpan $2) [ ControlPair () (getSpan $2) Nothing $2 ], Nothing) }
| '(' UNIT ',' FORM ')' { (AList () (getTransSpan $2 $4) [ ControlPair () (getSpan $2) Nothing $2, ControlPair () (getSpan $4) Nothing $4 ], Nothing) }

-- Not my terminology a VAR or an INT (probably positive) is defined as UNIT.
UNIT :: { Expression A0 } : INTEGER_LITERAL { $1 } | VARIABLE { $1 }

FORM :: { Expression A0 } : VARIABLE { $1 } | LABEL_IN_STATEMENT { $1 }

IO_ELEMENTS :: { AList Expression A0 }
IO_ELEMENTS
: IO_ELEMENTS ',' IO_ELEMENT { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1}
| IO_ELEMENT { AList () (getSpan $1) [ $1 ] }

IO_ELEMENT :: { Expression A0 }
IO_ELEMENT
: VARIABLE { $1 }
-- There should also be a caluse for variable names but not way to
-- differentiate it at this stage from VARIABLE. Hence, it is omitted to prevent
-- reduce/reduce conflict.
| SUBSCRIPT { $1 }
| '(' IO_ELEMENTS ',' DO_SPECIFICATION ')' { ExpImpliedDo () (getTransSpan $1 $5) $2 $4 }

ELEMENT :: { Expression A0 }
ELEMENT
: VARIABLE { $1 }
| SUBSCRIPT { $1 }

FORMAT_ITEMS :: { AList FormatItem A0 }
FORMAT_ITEMS
: FORMAT_ITEMS ',' FORMAT_ITEM { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| FORMAT_ITEMS ',' FORMAT_ITEM_DELIMETER { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| FORMAT_ITEMS FORMAT_ITEM { setSpan (getTransSpan $1 $2) $ $2 `aCons` $1 }
| FORMAT_ITEMS FORMAT_ITEM_DELIMETER { setSpan (getTransSpan $1 $2) $ $2 `aCons` $1 }
| '(' { AList () (getSpan $1) [ ] }

FORMAT_ITEM_DELIMETER :: { FormatItem A0 } : '/' { FIDelimiter () (getSpan $1) }

FORMAT_ITEM :: { FormatItem A0 }
FORMAT_ITEM
: int FORMAT_ITEMS ')' { FIFormatList () (getTransSpan $1 $3) (let (TInt _ s) = $1 in Just s) (aReverse $2) }
| FORMAT_ITEMS ')' { FIFormatList () (getTransSpan $1 $2) Nothing (aReverse $1) }
| HOLLERITH { let (ExpValue _ s val) = $1 in FIHollerith () s val }
| fieldDescriptorDEFG { let (TFieldDescriptorDEFG s a b c d) = $1 in FIFieldDescriptorDEFG () s a b c d }
| fieldDescriptorAIL { let (TFieldDescriptorAIL s a b c) = $1 in FIFieldDescriptorAIL () s a b c }
| blankDescriptor { let (TBlankDescriptor s w) = $1 in FIBlankDescriptor () s w }
| scaleFactor { let (TScaleFactor s sf) = $1 in FIScaleFactor () s sf }

DATA_GROUPS :: { AList DataGroup A0 }
DATA_GROUPS
: DATA_GROUPS ',' NAME_LIST  '/' DATA_ITEMS '/' { setSpan (getTransSpan $1 $6) $ (DataGroup () (getTransSpan $3 $6) (aReverse $3) (aReverse $5)) `aCons` $1 }
| NAME_LIST  '/' DATA_ITEMS '/' { AList () (getTransSpan $1 $4) [ DataGroup () (getTransSpan $1 $4) (aReverse $1) (aReverse $3) ] }

DATA_ITEMS :: { AList Expression A0 }
DATA_ITEMS
: DATA_ITEMS ',' DATA_ITEM { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1}
| DATA_ITEM { AList () (getSpan $1) [ $1 ] }

DATA_ITEM :: { Expression A0 }
DATA_ITEM
: INTEGER_LITERAL '*' DATA_ITEM_LEVEL1 { ExpBinary () (getTransSpan $1 $3) Multiplication $1 $3 }
| DATA_ITEM_LEVEL1 { $1 }

DATA_ITEM_LEVEL1 :: { Expression A0 }
DATA_ITEM_LEVEL1
: SIGNED_NUMERIC_LITERAL  { $1 }
| COMPLEX_LITERAL         { $1 }
| LOGICAL_LITERAL         { $1 }
| HOLLERITH               { $1 }

EQUIVALENCE_GROUPS :: { AList (AList Expression) A0 }
EQUIVALENCE_GROUPS
: EQUIVALENCE_GROUPS ','  '(' NAME_LIST ')' { setSpan (getTransSpan $1 $5) $ (setSpan (getTransSpan $3 $5) $ aReverse $4) `aCons` $1 }
| '(' NAME_LIST ')' { let s = (getTransSpan $1 $3) in AList () s [ setSpan s $ aReverse $2 ] }

COMMON_GROUPS :: { AList CommonGroup A0 }
COMMON_GROUPS
: COMMON_GROUPS COMMON_GROUP { setSpan (getTransSpan $1 $2) $ $2 `aCons` $1 }
| INIT_COMMON_GROUP { AList () (getSpan $1) [ $1 ] }

COMMON_GROUP :: { CommonGroup A0 }
COMMON_GROUP
: COMMON_NAME NAME_LIST
  { CommonGroup () (getTransSpan $1 $2) (Just $1) $ aReverse $2 }
| '/' '/' NAME_LIST { CommonGroup () (getTransSpan $1 $3) Nothing $ aReverse $3 }

INIT_COMMON_GROUP :: { CommonGroup A0 }
INIT_COMMON_GROUP
: COMMON_NAME NAME_LIST
  { CommonGroup () (getTransSpan $1 $2) (Just $1) $ aReverse $2 }
| '/' '/' NAME_LIST { CommonGroup () (getTransSpan $1 $3) Nothing $ aReverse $3 }
| NAME_LIST { CommonGroup () (getSpan $1) Nothing $ aReverse $1 }

COMMON_NAME :: { Expression A0 }
COMMON_NAME : '/' VARIABLE '/' { setSpan (getTransSpan $1 $3) $2 }

NAME_LIST :: { AList Expression A0 }
NAME_LIST
: NAME_LIST ',' NAME_LIST_ELEMENT { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| NAME_LIST_ELEMENT { AList () (getSpan $1) [ $1 ] }

NAME_LIST_ELEMENT :: { Expression A0 } : VARIABLE { $1 } | SUBSCRIPT { $1 }

DECLARATORS :: { AList Declarator A0 }
DECLARATORS
: DECLARATORS ',' DECLARATOR { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| DECLARATOR { AList () (getSpan $1) [ $1 ] }

-- Parses arrays as DeclVariable, otherwise we get a conflict.
DECLARATOR :: { Declarator A0 }
DECLARATOR
: ARRAY_DECLARATOR { $1 }
| VARIABLE_DECLARATOR { $1 }

ARRAY_DECLARATORS :: { AList Declarator A0 }
ARRAY_DECLARATORS
: ARRAY_DECLARATORS ',' ARRAY_DECLARATOR { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| ARRAY_DECLARATOR { AList () (getSpan $1) [ $1 ] }

ARRAY_DECLARATOR :: { Declarator A0 }
ARRAY_DECLARATOR
: VARIABLE '(' DIMENSION_DECLARATORS ')' { DeclArray () (getTransSpan $1 $4) $1 (aReverse $3) Nothing Nothing }

DIMENSION_DECLARATORS :: { AList DimensionDeclarator A0 }
DIMENSION_DECLARATORS
: DIMENSION_DECLARATORS ',' DIMENSION_DECLARATOR { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| DIMENSION_DECLARATOR { AList () (getSpan $1) [ $1 ] }

DIMENSION_DECLARATOR :: { DimensionDeclarator A0 }
DIMENSION_DECLARATOR
: EXPRESSION { DimensionDeclarator () (getSpan $1) Nothing (Just $1) }

VARIABLE_DECLARATOR :: { Declarator A0 }
VARIABLE_DECLARATOR
: VARIABLE { DeclVariable () (getSpan $1) $1 Nothing Nothing }

-- Here the procedure should be either a function or subroutine name, but
-- since they are syntactically identical at this stage subroutine names
-- are also emitted as function names.
FUNCTION_NAMES :: { AList Expression A0 }
FUNCTION_NAMES
: FUNCTION_NAMES ',' VARIABLE { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| VARIABLE { AList () (getSpan $1) [ $1 ] }

ARGUMENTS :: { AList Argument A0 }
ARGUMENTS
:  ARGUMENTS_LEVEL1 ')' { setSpan (getTransSpan $1 $2) $ aReverse $1 }

ARGUMENTS_LEVEL1 :: { AList Argument A0 }
ARGUMENTS_LEVEL1
: ARGUMENTS_LEVEL1 ',' CALLABLE_EXPRESSION { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| '(' CALLABLE_EXPRESSION { AList () (getTransSpan $1 $2) [ $2 ] }
| '(' { AList () (getSpan $1) [ ] }

-- Expression all by itself subsumes all other callable expressions.
CALLABLE_EXPRESSION :: { Argument A0 }
CALLABLE_EXPRESSION
: HOLLERITH   { Argument () (getSpan $1) Nothing $1 }
| EXPRESSION  { Argument () (getSpan $1) Nothing $1 }

EXPRESSION :: { Expression A0 }
EXPRESSION
: EXPRESSION '+' EXPRESSION { ExpBinary () (getTransSpan $1 $3) Addition $1 $3 }
| EXPRESSION '-' EXPRESSION { ExpBinary () (getTransSpan $1 $3) Subtraction $1 $3 }
| EXPRESSION '*' EXPRESSION { ExpBinary () (getTransSpan $1 $3) Multiplication $1 $3 }
| EXPRESSION '/' EXPRESSION { ExpBinary () (getTransSpan $1 $3) Division $1 $3 }
| EXPRESSION '**' EXPRESSION { ExpBinary () (getTransSpan $1 $3) Exponentiation $1 $3 }
| ARITHMETIC_SIGN EXPRESSION %prec NEGATION { ExpUnary () (getTransSpan (fst $1) $2) (snd $1) $2 }
| EXPRESSION or EXPRESSION { ExpBinary () (getTransSpan $1 $3) Or $1 $3 }
| EXPRESSION and EXPRESSION { ExpBinary () (getTransSpan $1 $3) And $1 $3 }
| not EXPRESSION { ExpUnary () (getTransSpan $1 $2) Not $2 }
| EXPRESSION RELATIONAL_OPERATOR EXPRESSION %prec RELATIONAL { ExpBinary () (getTransSpan $1 $3) $2 $1 $3 }
| '(' EXPRESSION ')' { setSpan (getTransSpan $1 $3) $2 }
| INTEGER_LITERAL               { $1 }
| REAL_LITERAL                  { $1 }
| COMPLEX_LITERAL               { $1 }
| LOGICAL_LITERAL               { $1 }
| SUBSCRIPT                     { $1 }
-- There should be FUNCTION_CALL here but as far as the parser is concerned it is same as SUBSCRIPT,
-- hence putting it here would cause a reduce/reduce conflict.
| VARIABLE                      { $1 }

RELATIONAL_OPERATOR :: { BinaryOp }
RELATIONAL_OPERATOR
: '=='  { EQ }
| '!='  { NE }
| '>'   { GT }
| '>='  { GTE }
| '<'   { LT }
| '<='  { LTE }

SUBSCRIPT :: { Expression A0 }
SUBSCRIPT
: VARIABLE '(' INDICIES ')'
  { ExpSubscript () (getTransSpan $1 $4) $1 (fromReverseList $3) }

INDICIES :: { [ Index A0 ] }
INDICIES
: INDICIES ',' EXPRESSION { IxSingle () (getSpan $3) $3 : $1 }
| EXPRESSION { [ IxSingle () (getSpan $1) $1 ] }

ARITHMETIC_SIGN :: { (SrcSpan, UnaryOp) }
ARITHMETIC_SIGN
: '-' { (getSpan $1, Minus) }
| '+' { (getSpan $1, Plus) }

VARIABLES :: { [ Expression A0 ] }
VARIABLES : VARIABLES ',' VARIABLE { $3 : $1 } | VARIABLE { [ $1 ] }

-- This may also be used to parse a function name, or an array name. Since when
-- are valid options in a production there is no way of differentiating them at
-- this stage.
-- This at least reduces reduce/reduce conflicts.
VARIABLE :: { Expression A0 }
VARIABLE
: id { ExpValue () (getSpan $1) $ let (TId _ s) = $1 in ValVariable () s }

SIGNED_INTEGER_LITERAL :: { Expression A0 }
SIGNED_INTEGER_LITERAL
: ARITHMETIC_SIGN INTEGER_LITERAL { ExpUnary () (getTransSpan (fst $1) $2) (snd $1) $2 }
| INTEGER_LITERAL { $1 }

INTEGER_LITERAL :: { Expression A0 } : int { ExpValue () (getSpan $1) $ let (TInt _ i) = $1 in ValInteger i }

SIGNED_REAL_LITERAL :: { Expression A0 }
SIGNED_REAL_LITERAL
: ARITHMETIC_SIGN REAL_LITERAL { ExpUnary () (getTransSpan (fst $1) $2) (snd $1) $2 }
| REAL_LITERAL { $1 }

REAL_LITERAL :: { Expression A0 }
REAL_LITERAL
: int EXPONENT { makeReal (Just $1) Nothing Nothing (Just $2) }
| int '.' MAYBE_EXPONENT { makeReal (Just $1) (Just $2) Nothing $3 }
| '.' int MAYBE_EXPONENT { makeReal Nothing (Just $1) (Just $2) $3 }
| int '.' int MAYBE_EXPONENT { makeReal (Just $1) (Just $2) (Just $3) $4 }

MAYBE_EXPONENT :: { Maybe (SrcSpan, String) }
MAYBE_EXPONENT
: EXPONENT { Just $1 }
| {-EMPTY-} { Nothing }

EXPONENT :: { (SrcSpan, String) }
EXPONENT
: exponent { let (TExponent s exp) = $1 in (s, exp) }

SIGNED_NUMERIC_LITERAL :: { Expression A0 }
SIGNED_NUMERIC_LIETERAL
: SIGNED_INTEGER_LITERAL { $1 }
| SIGNED_REAL_LITERAL    { $1 }

COMPLEX_LITERAL :: { Expression A0 }
COMPLEX_LITERAL
:  '(' SIGNED_NUMERIC_LITERAL ',' SIGNED_NUMERIC_LITERAL ')' { ExpValue () (getTransSpan $1 $5) (ValComplex $2 $4)}

LOGICAL_LITERAL :: { Expression A0 }
LOGICAL_LITERAL : bool { let TBool s b = $1 in ExpValue () s $ ValLogical b }

HOLLERITH :: { Expression A0 } : hollerith { ExpValue () (getSpan $1) $ let (THollerith _ h) = $1 in ValHollerith h }

LABELS_IN_STATEMENT :: { AList Expression A0 }
LABELS_IN_STATEMENT
: LABELS_IN_STATEMENT_LEVEL1 ')' { setSpan (getTransSpan $1 $2) $ aReverse $1 }

LABELS_IN_STATEMENT_LEVEL1 :: { AList Expression A0 }
LABELS_IN_STATEMENT_LEVEL1
: LABELS_IN_STATEMENT_LEVEL1 ',' LABEL_IN_STATEMENT { setSpan (getTransSpan $1 $3) $ $3 `aCons` $1 }
| '(' LABEL_IN_STATEMENT { AList () (getTransSpan $1 $2) [ $2 ] }

-- Labels that occur in the first 6 columns
LABEL_IN_6COLUMN :: { Expression A0 } : label { ExpValue () (getSpan $1) (let (TLabel _ l) = $1 in ValLabel l) }

-- Labels that occur in statements
LABEL_IN_STATEMENT :: { Expression A0 } : int { ExpValue () (getSpan $1) (let (TInt _ l) = $1 in ValLabel l) }

TYPE_SPEC :: { TypeSpec A0 }
TYPE_SPEC
: integer           { TypeSpec () (getSpan $1) TypeInteger Nothing }
| real              { TypeSpec () (getSpan $1) TypeReal Nothing }
| doublePrecision   { TypeSpec () (getSpan $1) TypeDoublePrecision Nothing }
| logical           { TypeSpec () (getSpan $1) TypeLogical Nothing }
| complex           { TypeSpec () (getSpan $1) TypeComplex Nothing }

{

makeReal :: Maybe Token -> Maybe Token -> Maybe Token -> Maybe (SrcSpan, String) -> Expression A0
makeReal i1 dot i2 exp =
  let span1   = getSpan (i1, dot, i2)
      span2   = case exp of
                  Just e -> getTransSpan span1 (fst e)
                  Nothing -> span1
      i1Str   = case i1 of { Just (TInt _ s) -> s ; _ -> "" }
      dotStr  = case dot of { Just (TDot _) -> "." ; _ -> "" }
      i2Str   = case i2 of { Just (TInt _ s) -> s ; _ -> "" }
      expStr  = case exp of { Just (_, s) -> s ; _ -> "" } in
    ExpValue () span2 (ValReal $ i1Str ++ dotStr ++ i2Str ++ expStr)

transformations66 =
  [ GroupLabeledDo
  , DisambiguateFunction
  ]

fortran66Parser :: String -> String -> ProgramFile A0
fortran66Parser sourceCode filename =
    transform transformations66 $ parse parseState
  where
    parse = evalParse programParser
    parseState = initParseState sourceCode Fortran66 filename

parseError :: Token -> LexAction a
parseError _ = fail "Parsing failed."

}