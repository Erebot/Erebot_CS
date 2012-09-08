%name Erebot_CodingStandard_Parser_
%declare_class {class Erebot_CodingStandard_Parser}
%token_type {Erebot_CodingStandard_Value}
%syntax_error {
        $stack = array();
        foreach ($this->yystack as $entry) {
            $stack[] = $this->tokenName($entry->major);
        }

        $expect = array();
        foreach ($this->yy_get_expected_tokens($yymajor) as $token) {
            $expect[] = self::$yyTokenName[$token];
        }

        $position = $this->_lexer->getPosition();
        echo "Syntax Error near line " . $position->getLine() . " and " .
            "column " . $position->getColumn() . ": token '" .
            addcslashes($TOKEN->getValue(), "\r\n\t\\") .
            "' while parsing rule:\n";

        throw new Exception(
            'Syntax Error near line ' . $position->getLine() . ' and column ' .
            $position->getColumn() . ': unexpected ' .
            $this->tokenName($yymajor) . ' (' .
            addcslashes($TOKEN->getValue(), "\r\n\t\\") . '), ' .
            'expected one of: ' . implode(', ', $expect) . PHP_EOL .
            'Parser stack: ' . PHP_EOL . implode(' ', $stack) . PHP_EOL
        );
}
%include_class {
        protected $_problems;
        protected $_lexer;

        public function __construct()
        {
            $this->_problems = array();
        }

        public function setLexer(Erebot_CodingStandard_Lexer $lexer)
        {
            $this->_lexer = $lexer;
        }

        protected function _addProblem($level, $blocks, $msg, $anchor = NULL)
        {
            if (!is_array($blocks))
                $blocks = array($blocks);
            foreach ($blocks as $block) {
                if (!($block instanceof Erebot_CodingStandard_Value))
                    throw new Exception("Invalid block reference");
            }
            if ($anchor !== NULL && substr($anchor, 0, 1) == "#") {
                $anchor = substr($anchor, 1);
                if ($anchor === FALSE)
                    $anchor = NULL;
            }
            $this->_problems[] = array($level, $blocks, $msg, $anchor);
        }

        protected function addError($blocks, $msg, $anchor = NULL)
        {
            $this->_addProblem("ERROR", $blocks, $msg, $anchor);
        }

        protected function addWarning($blocks, $msg, $anchor = NULL)
        {
            $this->_addProblem("WARNING", $blocks, $msg, $anchor);
        }

        public function getProblems()
        {
            return $this->_problems;
        }

        protected function _normalizeIdentifier($identifier)
        {
            return strtr(
                $identifier,
                "abcdefghijklmnopqrstuvwxyz",
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            );
        }

        protected function _validClassObjName($varName, $isMethod)
        {
            $validChars =   "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .
                            "abcdefghijklmnopqrstuvwxyz" .
                            "1234567890_";
            $validFirst =   "abcdefghijklmnopqrstuvwxyz";
            $name       =   $varName->getValue();

            if (!$isMethod) {
                if (substr($name, 0, 1) != '$') {
                    throw new Exception(
                        "Invalid arguments"
                    );
                }
                $name = ltrim($name, '$');
            }

            $name = ltrim($name, '_');
            if ($name == '' || strpos($validFirst, $name[0]) === FALSE ||
                strspn($name, $validChars) != strlen($name)) {
                $this->addError(
                    $varName,
                    "Variable name does not match _*[a-z][A-Za-z0-9_]*",
                    "#class-methods-and-properties"
                );
            }
        }

        protected function _validConstName($constName)
        {
            $validChars =   "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .
                            "1234567890_";
            $validFirst =   "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            $name       =   $constName->getValue();
            if (strpos($validFirst, $name[0]) === FALSE ||
                strspn($name, $validChars) != strlen($name)) {
                $this->addError(
                    $constName,
                    "Constant name does not match [A-Z][A-Z0-9_]*",
                    "#constants"
                );
            }
        }
}

%left T_INCLUDE T_INCLUDE_ONCE T_EVAL T_REQUIRE T_REQUIRE_ONCE.
%left T_COMMA.
%left T_LOGICAL_OR.
%left T_LOGICAL_XOR.
%left T_LOGICAL_AND.
%right T_PRINT.
%left T_EQUAL T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL.
%left T_QUESTION T_COLON.
%left T_BOOLEAN_OR.
%left T_BOOLEAN_AND.
%left T_PIPE.
%left T_CIRCUMFLEX.
%left T_AMPERSAND.
%nonassoc T_IS_EQUAL T_IS_NOT_EQUAL T_IS_IDENTICAL T_IS_NOT_IDENTICAL.
%nonassoc T_SMALLER T_IS_SMALLER_OR_EQUAL T_GREATER T_IS_GREATER_OR_EQUAL.
%left T_SL T_SR.
%left T_PLUS T_MINUS T_DOT.
%left T_STAR T_SLASH T_PERCENT.
%right T_EXCLAMATION.
%nonassoc T_INSTANCEOF.
%right T_TILDE T_INC T_DEC T_INT_CAST T_DOUBLE_CAST T_STRING_CAST T_ARRAY_CAST T_OBJECT_CAST T_BOOL_CAST T_UNSET_CAST T_AT.
%right T_SQUARE_OPEN.
%nonassoc T_NEW T_CLONE.
%left T_ELSEIF.
%left T_ELSE.
%left T_ENDIF.
%right T_STATIC T_ABSTRACT T_FINAL T_PRIVATE T_PROTECTED T_PUBLIC.

start ::= file.

file ::= file_statements.
file ::= file_statements php_open_tag top_statement_list.

file_statements ::= .
file_statements ::= file_statements php_script.
file_statements ::= file_statements T_INLINE_HTML(tok). {
    // Ignore shebangs.
    if (tok->getLine() == 1 &&
        tok->getColumn() == 1 &&
        !strncmp('#!', tok->getValue(), 2)) {
        return;             // @TODO: check shebang syntax
    }

    $this->addError(
        tok,
        "DO NOT mix PHP code with non-PHP content in the same file",
        "#php-code-tags"    // @TODO
    );
}

php_script ::= php_open_tag top_statement_list T_CLOSE_TAG(tok). {
    $this->addError(
        tok,
        "Omit the closing '?>' at the end of the file",
        "#php-code-tags"
    );
}

php_open_tag ::= T_OPEN_TAG(tok). {
    if ($this->_normalizeIdentifier(rtrim(tok->getValue())) == "<?PHP") {
        return;
    }

    $this->addError(
        tok,
        "Always use '<?php' to start a new block of PHP code",
        "#php-code-tags"
    );
}
php_open_tag ::= T_OPEN_TAG_WITH_ECHO(tok). {
    $this->addError(
        tok,
        "Use only '<?php' to start a new block of PHP code",
        "#php-code-tags"    // @TODO
    );
}

top_statement_list ::= top_statement_list top_statement.
top_statement_list ::= .

top_statement ::= statement.
top_statement ::= function_declaration_statement.
top_statement ::= class_declaration_statement.
top_statement ::= T_HALT_COMPILER T_PAR_OPEN T_PAR_CLOSE T_SEMI_COLON.

inner_statement_list ::= inner_statement_list inner_statement.
inner_statement_list ::= .

inner_statement ::= statement.
inner_statement ::= function_declaration_statement.
inner_statement ::= class_declaration_statement.
inner_statement ::= T_HALT_COMPILER T_PAR_OPEN T_PAR_CLOSE T_SEMI_COLON.

statement ::= unticked_statement.

unticked_statement ::= T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE.
unticked_statement ::= T_IF T_PAR_OPEN expr T_PAR_CLOSE statement elseif_list else_single.
unticked_statement ::= T_PAR_OPEN expr T_PAR_CLOSE T_COLON(startTok) inner_statement_list new_elseif_list new_else_single T_ENDIF(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}
unticked_statement ::= T_WHILE T_PAR_OPEN expr T_PAR_CLOSE while_statement.
unticked_statement ::= T_DO statement T_WHILE T_PAR_OPEN expr T_PAR_CLOSE T_SEMI_COLON.
unticked_statement ::= T_FOR T_PAR_OPEN for_expr T_SEMI_COLON for_expr T_SEMI_COLON for_expr T_PAR_CLOSE for_statement.
unticked_statement ::= T_SWITCH T_PAR_OPEN expr T_PAR_CLOSE switch_case_list.
unticked_statement ::= T_BREAK T_SEMI_COLON.
unticked_statement ::= T_BREAK expr T_SEMI_COLON.
unticked_statement ::= T_CONTINUE T_SEMI_COLON.
unticked_statement ::= T_CONTINUE expr T_SEMI_COLON.
unticked_statement ::= T_RETURN T_SEMI_COLON.
unticked_statement ::= T_RETURN expr_without_variable T_SEMI_COLON.
unticked_statement ::= T_RETURN variable T_SEMI_COLON.
unticked_statement ::= T_GLOBAL(globalTok) global_var_list T_SEMI_COLON. {
    $this->addError(
        globalTok,
        "Use of global variables is strictly prohibited",
        "#global-variables"
    );
}
unticked_statement ::= T_STATIC static_var_list T_SEMI_COLON.
unticked_statement ::= T_ECHO echo_expr_list T_SEMI_COLON.
unticked_statement ::= T_INLINE_HTML.
unticked_statement ::= expr T_SEMI_COLON.
unticked_statement ::= T_UNSET T_PAR_OPEN unset_variables T_PAR_CLOSE T_SEMI_COLON.
unticked_statement ::= T_FOREACH T_PAR_OPEN variable T_AS foreach_variable foreach_optional_arg T_PAR_CLOSE foreach_statement.
unticked_statement ::= T_FOREACH T_PAR_OPEN expr_without_variable T_AS variable foreach_optional_arg T_PAR_CLOSE foreach_statement.
unticked_statement ::= T_DECLARE T_PAR_OPEN declare_list T_PAR_CLOSE declare_statement.
unticked_statement ::= T_SEMI_COLON.
unticked_statement ::= T_TRY T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE T_CATCH T_PAR_OPEN fully_qualified_class_name T_VARIABLE T_PAR_CLOSE T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE additional_catches.
unticked_statement ::= T_THROW expr T_SEMI_COLON.

additional_catches ::= non_empty_additional_catches.
additional_catches ::= .

non_empty_additional_catches ::= additional_catch.
non_empty_additional_catches ::= non_empty_additional_catches additional_catch.

additional_catch ::= T_CATCH T_PAR_OPEN fully_qualified_class_name T_VARIABLE T_PAR_CLOSE T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE.

unset_variables ::= unset_variable.
unset_variables ::= unset_variables T_COMMA unset_variable.

unset_variable ::= variable.

function_declaration_statement ::= unticked_function_declaration_statement.

class_declaration_statement ::= unticked_class_declaration_statement.

is_reference ::= .
is_reference ::= T_AMPERSAND.

unticked_function_declaration_statement ::= T_FUNCTION(startTok) is_reference T_STRING(funcName) T_PAR_OPEN parameter_list T_PAR_CLOSE T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE(endTok). {
    $this->addWarning(
        array(startTok, endTok),
        "Avoid functions and prefer static methods of a class",
        "#function-method-declarations"
    );

    $validChars = "abcdefghijklmnopqrstuvwxyz_1234567890";
    $validFirst = "abcdefghijklmnopqrstuvwxyz";
    $name       = funcName->getValue();
    if (strpos($validFirst, $name[0]) === FALSE ||
        strspn($name, $validChars) != strlen($name)) {
        $this->addError(
            funcName,
            "Function name does not match [a-z][a-z_0-9]*",
            "#functions"
        );
    }
}

unticked_class_declaration_statement ::= class_entry_type T_STRING(classDef) extends_from implements_list T_REAL_CURLY_OPEN class_statement_list(methodList) T_REAL_CURLY_CLOSE. {
    $validChars =   "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .
                    "abcdefghijklmnopqrstuvwxyz" .
                    "1234567890_";
    $validFirst = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    $name   = classDef->getValue();
    $len    = strlen($name);

    if (!$len || strspn($name, $validChars) != $len ||
        strpos($validFirst, $name[0]) === FALSE) {
        $this->addError(
            classDef,
            "Class name does not match [A-Z][A-Za-z_0-9]*",
            "#classes-and-interfaces"
        );
    }

    // Does this class belong to a file/dir layout
    // that matches our expectations?
    $suffix     = strtr(
        "_" . $name . ".php",
        array("_" => DIRECTORY_SEPARATOR)
    );
    $revSuffix  = strrev($suffix);
    $revFile    = strrev($this->_lexer->getFile());
    if (strncmp($revFile, $revSuffix, strlen($revSuffix))) {
        $this->addError(
            classDef,
            "The class named '" . $name . "' should be placed in a file " .
            "named ..." . $suffix,
            "#cs-naming-files"
        );
    }

    $reflector  = new ReflectionClass($name);
    $ctor       = $reflector->getConstructor();
    if ($ctor !== NULL) {
        $ctorName = $this->_normalizeIdentifier($ctor->name);
        if ($ctorName != "__CONSTRUCT") {
            foreach (methodList as $method) {
                $methName = $this->_normalizeIdentifier($method->getValue());
                if ($methName == $ctorName) {
                    $this->addError(
                        method,
                        "The constructor should be __construct(), '.
                        'not " . $ctor->name . "()",
                        "#class-constructors"
                    );
                    break;
                }
            }
        }
    }
    else {
        $this->addWarning(
            classDef,
            "Consider adding a __construct() method to the class " .
            "so that subclasses may call their parent's constructor " .
            "without causing a crash",
            "#class-constructors" // @TODO
        );
    }
}
unticked_class_declaration_statement ::= interface_entry T_STRING(ifaceDef) interface_extends_list T_REAL_CURLY_OPEN class_statement_list T_REAL_CURLY_CLOSE. {
    $validChars =   "ABCDEFGHIJKLMNOPQRSTUVWXYZ" .
                    "abcdefghijklmnopqrstuvwxyz" .
                    "1234567890_";
    $validFirst = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    $name   = ifaceDef->getValue();
    $len    = strlen($name);

    if (!$len || strspn($name, $validChars) != $len ||
        strpos($validFirst, $name[0]) === FALSE) {
        $this->addError(
            ifaceDef,
            "Interface name does not match [A-Z][A-Za-z_0-9]*",
            "#classes-and-interfaces"
        );
    }

    // Does this interface belong to a file/dir layout
    // that matches our expectations?
    $suffix     = strtr(
        "_" . $name . ".php",
        array("_" => DIRECTORY_SEPARATOR)
    );
    $revSuffix  = strrev($suffix);
    $revFile    = strrev($this->_lexer->getFile());
    if (strncmp($revFile, $revSuffix, strlen($revSuffix))) {
        $this->addError(
            ifaceDef,
            "The interface named '" . $name . "' belongs to a file " .
            "named ..." . $suffix,
            "#cs-naming-files"
        );
    }

    if (strpos($name, "Interface") === FALSE) {
        $this->addError(
            ifaceDef,
            "The text 'Interface' should be part of an interface's name",
            "#classes-and-interfaces"
        );
    }
}

class_entry_type ::= T_CLASS.
class_entry_type ::= T_ABSTRACT T_CLASS.
class_entry_type ::= T_FINAL T_CLASS.

extends_from ::= .
extends_from ::= T_EXTENDS fully_qualified_class_name.

interface_entry ::= T_INTERFACE.

interface_extends_list ::= .
interface_extends_list ::= T_EXTENDS interface_list.

implements_list ::= .
implements_list ::= T_IMPLEMENTS interface_list.

interface_list ::= fully_qualified_class_name.
interface_list ::= interface_list T_COMMA fully_qualified_class_name.

foreach_optional_arg ::= .
foreach_optional_arg ::= T_DOUBLE_ARROW foreach_variable.

foreach_variable ::= variable.
foreach_variable ::= T_AMPERSAND variable.

for_statement ::= statement.
for_statement ::= T_COLON(startTok) inner_statement_list T_ENDFOR(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}

foreach_statement ::= statement.
foreach_statement ::= T_COLON(startTok) inner_statement_list T_ENDFOREACH(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}

declare_statement ::= statement.
declare_statement ::= T_COLON(startTok) inner_statement_list T_ENDDECLARE(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}

declare_list ::= T_STRING T_EQUAL static_scalar.
declare_list ::= declare_list T_COMMA T_STRING T_EQUAL static_scalar.

switch_case_list ::= T_REAL_CURLY_OPEN case_list T_REAL_CURLY_CLOSE.
switch_case_list ::= T_REAL_CURLY_OPEN T_SEMI_COLON case_list T_REAL_CURLY_CLOSE.
switch_case_list ::= T_COLON(startTok) case_list T_ENDSWITCH(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}
switch_case_list ::= T_COLON(startTok) T_SEMI_COLON case_list T_ENDSWITCH(endTok) T_SEMI_COLON. {
    $this->addError(
        array(startTok, endTok),
        "Don't use the alternate syntax for control structures",
        "#control-structures"
    );
}

case_list ::= .
case_list ::= case_list T_CASE expr case_separator inner_statement_list.
case_list ::= case_list T_DEFAULT case_separator inner_statement_list.

case_separator ::= T_COLON.
case_separator ::= T_SEMI_COLON.

while_statement ::= statement.
while_statement ::= T_COLON inner_statement_list T_ENDWHILE T_SEMI_COLON.

elseif_list ::= .
elseif_list ::= elseif_list T_ELSEIF(elseifTok) T_PAR_OPEN expr T_PAR_CLOSE statement. {
    $this->addError(
        elseifTok,
        "Use 'else if' instead of 'elseif'",
        "#control-structures"
    );
}

new_elseif_list ::= .
new_elseif_list ::= new_elseif_list T_ELSEIF(elseifTok) T_PAR_OPEN expr T_PAR_CLOSE T_COLON inner_statement_list. {
    $this->addError(
        elseifTok,
        "Use 'else if' instead of 'elseif'",
        "#control-structures"
    );
}

else_single ::= .
else_single ::= T_ELSE statement.

new_else_single ::= .
new_else_single ::= T_ELSE T_COLON inner_statement_list.

parameter_list ::= non_empty_parameter_list.
parameter_list ::= .

non_empty_parameter_list ::= optional_class_type T_VARIABLE.
non_empty_parameter_list ::= optional_class_type T_AMPERSAND T_VARIABLE.
non_empty_parameter_list ::= optional_class_type T_AMPERSAND T_VARIABLE T_EQUAL static_scalar.
non_empty_parameter_list ::= optional_class_type T_VARIABLE  T_EQUAL static_scalar.
non_empty_parameter_list ::= non_empty_parameter_list T_COMMA optional_class_type T_VARIABLE.
non_empty_parameter_list ::= non_empty_parameter_list T_COMMA optional_class_type T_AMPERSAND T_VARIABLE.
non_empty_parameter_list ::= non_empty_parameter_list T_COMMA optional_class_type T_AMPERSAND T_VARIABLE T_EQUAL static_scalar.
non_empty_parameter_list ::= non_empty_parameter_list T_COMMA optional_class_type T_VARIABLE  T_EQUAL static_scalar.

optional_class_type ::= .
optional_class_type ::= T_STRING(typehint). {
    $name       = typehint->getValue();
    $normalized = $this->_normalizeIdentifier(typehint->getValue());

    // The "array" typehint does not fall under other constraints.
    if ($name == 'array') {
        return;
    }

    $classes    = get_declared_classes();
    $classes    = array_combine(
        array_map(array($this, "_normalizeIdentifier"), $classes),
        $classes
    );

    if ($classes[$normalized] != $name) {
        $this->addWarning(
            typehint,
            "The proper case for '" . $name .
            "' is '" . $classes[$normalized] . "'",
            "#function-method-calls"
        );
    }

    if (interface_exists($name, TRUE)) {
        return;
    }

    if (!class_exists($name, TRUE)) {
        $this->addError(typehint, "No such class/interface: '" . $name . "'");
        return;
    }

    $reflector = new ReflectionClass($name);
    if ($reflector->isInternal()) {
        $this->addWarning(
            typehint,
            "Consider writing an interface instead of using '" .
            $name . "' as a typehint directly",
            "#function-method-declarations"
        );
        return;
    }

    if (!$reflector->isAbstract()) {
        $this->addError(
            typehint,
            "Use interfaces in typehints instead of concrete classes",
            "#function-method-declarations"
        );
    }
}
optional_class_type ::= T_ARRAY.

function_call_parameter_list ::= non_empty_function_call_parameter_list.
function_call_parameter_list ::= .

non_empty_function_call_parameter_list ::= expr_without_variable.
non_empty_function_call_parameter_list ::= variable.
non_empty_function_call_parameter_list ::= T_AMPERSAND w_variable.
non_empty_function_call_parameter_list ::= non_empty_function_call_parameter_list T_COMMA expr_without_variable.
non_empty_function_call_parameter_list ::= non_empty_function_call_parameter_list T_COMMA variable.
non_empty_function_call_parameter_list ::= non_empty_function_call_parameter_list T_COMMA T_AMPERSAND w_variable.

global_var_list ::= global_var_list T_COMMA global_var.
global_var_list ::= global_var.

global_var ::= T_VARIABLE.
global_var ::= T_DOLLAR r_variable.
global_var ::= T_DOLLAR T_REAL_CURLY_OPEN expr T_REAL_CURLY_CLOSE.

static_var_list ::= static_var_list T_COMMA T_VARIABLE.
static_var_list ::= static_var_list T_COMMA T_VARIABLE T_EQUAL static_scalar.
static_var_list ::= T_VARIABLE.
static_var_list ::= T_VARIABLE T_EQUAL static_scalar.

class_statement_list(res) ::= class_statement_list(methods) class_statement(newMethod). {
    $newRes = methods;
    if (newMethod !== NULL) {
        $newRes[] = newMethod;
    }
    res = $newRes;
}
class_statement_list(res) ::= . {
    res = array();
}

class_statement(res) ::= non_empty_member_modifiers(mods) class_var_or_method(varOrMeth). {
    res = varOrMeth[0] ? varOrMeth[1] : NULL;

    $modifiers = array();
    foreach (mods as $mod) {
        $modifiers[] = $this->_normalizeIdentifier($mod->getValue());
    }

    // The visibility modifier must be the last modifier.
    $ppp = array('PUBLIC', 'PROTECTED', 'PRIVATE');
    if (!in_array(end($modifiers), $ppp)) {
        $this->addError(
            $lastMod,
            "The visibility modifier (public/protected/private) " .
            "MUST be the last modifier",
            "#class-methods-and-properties"
        );
    }
    if (!count(array_intersect($modifiers, $ppp))) {
        $this->addError(
            end(mods),
            "The visibility MUST be explicitely stated",
            "#class-methods-and-properties"
        );
        $modifiers[] = 'PUBLIC';
    }

    if (varOrMeth[0] === TRUE) {
        $name = $this->_normalizeIdentifier(varOrMeth[1]->getValue());

        // Method name must start with a leading "_"
        // if the method is protected or private.
        if (!in_array('PUBLIC', $modifiers)) {
            if ($name[0] != '_') {
                $this->addError(
                    varOrMeth[1],
                    "Protected/private methods MUST be prefixed with an underscore",
                    "#class-methods-and-properties"
                );
            }
        }
        else if ($name[0] == '_') {
            // Whitelist magic methods and methods that must be exposed
            // with a special name to external tools (eg. xgettext).
            // Also, flag methods that cause compatibility issues with PHP 5.2.x.
            $whitelist  = array(
                '_'             => FALSE,   // Used by xgettext.
                '__CONSTRUCT'   => FALSE,   // Constructor.
                '__DESTRUCT'    => FALSE,   // Destructor.
                '__CALL'        => FALSE,   // Magical (non-static) method call.
                '__CALLSTATIC'  => TRUE,    // Magical static method call (5.3.0+).
                '__GET'         => FALSE,   // Magical member getter.
                '__SET'         => FALSE,   // Magical member setter.
                '__ISSET'       => FALSE,   // Magical member existence test.
                '__UNSET'       => FALSE,   // Magical member unsetter.
                '__SLEEP'       => TRUE,    // Serialization (obsolete).
                '__WAKEUP'      => TRUE,    // Unserialization (obsolete).
                '__TOSTRING'    => FALSE,   // (Automatic) conversion to string.
                '__INVOKE'      => TRUE,    // Object invokation (5.3.0+).
                '__SET_STATE'   => FALSE,   // Hook for var_export().
                '__CLONE'       => FALSE,   // Cloning.
            );

            if (!isset($whitelist[$name])) {
                $this->addError(
                    varOrMeth[1],
                    "Public methods MUST NOT be prefixed with an underscore, " .
                    "except for 'magic methods' (eg. __toString())",
                    "#class-methods-and-properties"
                );
            }
            else if ($whitelist[$name]) {
                $this->addError(
                    varOrMeth[1],
                    "This magic method may not work across all PHP versions " .
                    "or is considered obsolete",
                    "#class-methods-and-properties" // @TODO
                );
            }
        }
    }

    else {
        foreach (varOrMeth[1] as $var) {
            $name = ltrim($var->getValue(), '$');

            if (in_array('PUBLIC', $modifiers)) {
                if ($name[0] == '_') {
                    $this->addError(
                        $var,
                        "Public members MUST NOT be prefixed with an underscore",
                        "#class-methods-and-properties"
                    );
                }
                $this->addWarning(
                    $var,
                    "Avoid public members (they tend to expose too much " .
                    "of what may be considered implementation details)",
                    "#class-methods-and-properties"
                );
            }

            else {
                if ($name[0] != '_') {
                    $this->addError(
                        $var,
                        "Protected/private members MUST be prefixed " .
                        "with an underscore",
                        "#class-methods-and-properties"
                    );
                }
                if (in_array("PRIVATE", $modifiers)) {
                    $this->addWarning(
                        $var,
                        "Avoid private members (they are a PITA to test)",
                        "#class-methods-and-properties"
                    );
                }
            }
        }
    }
}
class_statement(res) ::= T_VAR(varTok) class_variable_declaration(vars) T_SEMI_COLON. {
    res = NULL;

    $this->addError(
        varTok,
        "The old PHP 4 'var' keyword MUST NOT be used",
        "#class-methods-and-properties"
    );

    foreach (vars as $var) {
        $name = ltrim($var->getValue(), '$');

        if ($name[0] == '_') {
            $this->addError(
                $var,
                "Public members MUST NOT be prefixed with an underscore",
                "#class-methods-and-properties"
            );
        }
        $this->addWarning(
            $var,
            "Avoid public members (they tend to expose too much " .
            "of what may be considered implementation details)",
            "#class-methods-and-properties"
        );
    }
}
class_statement(res) ::= method_declaration(methDecl). {
    res = methDecl;
    $fakeToken = $this->_lexer->getPosition();
    $this->addError(
        methDecl,
        "The visibility MUST be explicitely stated",
        "#class-methods-and-properties"
    );

    // Whitelist magic methods and methods that must be exposed
    // with a special name to external tools (eg. xgettext).
    // Also, flag methods that cause compatibility issues with PHP 5.2.x.
    $whitelist  = array(
        '_'             => FALSE,   // Used by xgettext.
        '__CONSTRUCT'   => FALSE,   // Constructor.
        '__DESTRUCT'    => FALSE,   // Destructor.
        '__CALL'        => FALSE,   // Magical (non-static) method call.
        '__CALLSTATIC'  => TRUE,    // Magical static method call (5.3.0+).
        '__GET'         => FALSE,   // Magical member getter.
        '__SET'         => FALSE,   // Magical member setter.
        '__ISSET'       => FALSE,   // Magical member existence test.
        '__UNSET'       => FALSE,   // Magical member unsetter.
        '__SLEEP'       => TRUE,    // Serialization (obsolete).
        '__WAKEUP'      => TRUE,    // Unserialization (obsolete).
        '__TOSTRING'    => FALSE,   // (Automatic) conversion to string.
        '__INVOKE'      => TRUE,    // Object invokation (5.3.0+).
        '__SET_STATE'   => FALSE,   // Hook for var_export().
        '__CLONE'       => FALSE,   // Cloning.
    );

    $name = $this->_normalizeIdentifier(methDecl->getValue());
    if (!isset($whitelist[$name])) {
        $this->addError(
            methDecl,
            "Public methods MUST NOT be prefixed with an underscore, " .
            "except for 'magic methods' (eg. __toString())",
            "#class-methods-and-properties"
        );
    }
    else if ($whitelist[$name]) {
        $this->addError(
            methDecl,
            "This magic method may not work across all PHP versions " .
            "or is considered obsolete",
            "#class-methods-and-properties" // @TODO
        );
    }
}
class_statement(res) ::= class_constant_declaration T_SEMI_COLON. {
    res = NULL;
}

class_var_or_method(res) ::= class_variable_declaration(vars) T_SEMI_COLON. {
    res = array(FALSE, vars);
}
class_var_or_method(res) ::= method_declaration(methDecl). {
    res = array(TRUE, methDecl);
}

method_declaration(res) ::= T_FUNCTION is_reference T_STRING(funcName) T_PAR_OPEN parameter_list T_PAR_CLOSE method_body. {
    res = funcName;
    $this->_validClassObjName(funcName, TRUE);
    return;
}

method_body ::= T_SEMI_COLON.
method_body ::= T_REAL_CURLY_OPEN inner_statement_list T_REAL_CURLY_CLOSE.

non_empty_member_modifiers(res) ::= member_modifier(mod). {
    res = array(mod);
}
non_empty_member_modifiers(res) ::= non_empty_member_modifiers(mods) member_modifier(newMod). {
    $newRes     = mods;
    $newRes[]   = newMod;
    res         = $newRes;
}

member_modifier(res) ::= T_PUBLIC(tok). {
    res = tok; // @TODO: force case-sensitivity?
}
member_modifier(res) ::= T_PROTECTED(tok). {
    res = tok; // @TODO: force case-sensitivity?
}
member_modifier(res) ::= T_PRIVATE(tok). {
    res = tok; // @TODO: force case-sensitivity?
}
member_modifier(res) ::= T_STATIC(tok). {
    res = tok; // @TODO: force case-sensitivity?
}
member_modifier(res) ::= T_ABSTRACT(tok). {
    res = tok; // @TODO: force case-sensitivity?
}
member_modifier(res) ::= T_FINAL(tok). {
    res = tok; // @TODO: force case-sensitivity?
}

class_variable_declaration(res) ::= class_variable_declaration(vars) T_COMMA T_VARIABLE(varName). {
    $this->_validClassObjName(varName, FALSE);
    $newVars    = vars;
    $newVars[]  = varName;
    res = $newVars;
}
class_variable_declaration(res) ::= class_variable_declaration(vars) T_COMMA T_VARIABLE(varName) T_EQUAL static_scalar. {
    $this->_validClassObjName(varName, FALSE);
    $newVars    = vars;
    $newVars[]  = varName;
    res = $newVars;
}
class_variable_declaration(res) ::= T_VARIABLE(varName). {
    $this->_validClassObjName(varName, FALSE);
    res = array(varName);
}
class_variable_declaration(res) ::= T_VARIABLE(varName) T_EQUAL static_scalar. {
    $this->_validClassObjName(varName, FALSE);
    res = array(varName);
}

class_constant_declaration ::= class_constant_declaration T_COMMA T_STRING(constName) T_EQUAL static_scalar. {
    $this->_validConstName(constName);
}
class_constant_declaration ::= T_CONST T_STRING(constName) T_EQUAL static_scalar. {
    $this->_validConstName(constName);
}

echo_expr_list ::= echo_expr_list T_COMMA expr.
echo_expr_list ::= expr.

for_expr ::= .
for_expr ::= non_empty_for_expr.

non_empty_for_expr ::= non_empty_for_expr T_COMMA expr.
non_empty_for_expr ::= expr.

expr_without_variable ::= T_LIST T_PAR_OPEN assignment_list T_PAR_CLOSE T_EQUAL expr.
expr_without_variable ::= variable T_EQUAL expr.
expr_without_variable ::= variable T_EQUAL T_AMPERSAND variable.
expr_without_variable ::= variable T_EQUAL T_AMPERSAND(newRef) T_NEW class_name_reference ctor_arguments(hasArgs). {
    $this->addError(
        newRef,
        "Assigning the return value of new by reference is forbidden",
        "#class-constructor-calls" // @TODO
    );

    if (!hasArgs) {
        $this->addError(
            $this->_lexer->getPosition(),
            "Always use parenthesis when calling a class constructor " .
            "even if it takes no argument",
            "#class-constructor-calls"
        );
    }
}
expr_without_variable ::= T_NEW class_name_reference ctor_arguments(hasArgs). {
    if (!hasArgs) {
        $this->addError(
            $this->_lexer->getPosition(),
            "Always use parenthesis when calling a class constructor " .
            "even if it takes no argument",
            "#class-constructor-calls"
        );
    }
}
expr_without_variable ::= T_CLONE expr.
expr_without_variable ::= variable T_PLUS_EQUAL expr.
expr_without_variable ::= variable T_MINUS_EQUAL expr.
expr_without_variable ::= variable T_MUL_EQUAL expr.
expr_without_variable ::= variable T_DIV_EQUAL expr.
expr_without_variable ::= variable T_CONCAT_EQUAL expr.
expr_without_variable ::= variable T_MOD_EQUAL expr.
expr_without_variable ::= variable T_AND_EQUAL expr.
expr_without_variable ::= variable T_OR_EQUAL expr.
expr_without_variable ::= variable T_XOR_EQUAL expr.
expr_without_variable ::= variable T_SL_EQUAL expr.
expr_without_variable ::= variable T_SR_EQUAL expr.
expr_without_variable ::= rw_variable T_INC.
expr_without_variable ::= T_INC rw_variable.
expr_without_variable ::= rw_variable T_DEC.
expr_without_variable ::= T_DEC rw_variable.
expr_without_variable ::= expr T_BOOLEAN_OR expr.
expr_without_variable ::= expr T_BOOLEAN_AND expr.
expr_without_variable ::= expr T_LOGICAL_OR expr.
expr_without_variable ::= expr T_LOGICAL_AND expr.
expr_without_variable ::= expr T_LOGICAL_XOR expr.
expr_without_variable ::= expr T_PIPE expr.
expr_without_variable ::= expr T_AMPERSAND expr.
expr_without_variable ::= expr T_CIRCUMFLEX expr.
expr_without_variable ::= expr T_DOT expr.
expr_without_variable ::= expr T_PLUS expr.
expr_without_variable ::= expr T_MINUS expr.
expr_without_variable ::= expr T_STAR expr.
expr_without_variable ::= expr T_SLASH expr.
expr_without_variable ::= expr T_PERCENT expr.
expr_without_variable ::= expr T_SL expr.
expr_without_variable ::= expr T_SR expr.
expr_without_variable ::= T_PLUS expr. [T_INC]
expr_without_variable ::= T_MINUS expr. [T_INC]
expr_without_variable ::= T_EXCLAMATION expr.
expr_without_variable ::= T_TILDE expr.
expr_without_variable ::= expr T_IS_IDENTICAL expr.
expr_without_variable ::= expr T_IS_NOT_IDENTICAL expr.
expr_without_variable ::= expr T_IS_EQUAL expr.
expr_without_variable ::= expr T_IS_NOT_EQUAL expr.
expr_without_variable ::= expr T_SMALLER expr.
expr_without_variable ::= expr T_IS_SMALLER_OR_EQUAL expr.
expr_without_variable ::= expr T_GREATER expr.
expr_without_variable ::= expr T_IS_GREATER_OR_EQUAL expr.
expr_without_variable ::= expr T_INSTANCEOF class_name_reference.
expr_without_variable ::= T_PAR_OPEN expr T_PAR_CLOSE.
expr_without_variable ::= expr T_QUESTION expr T_COLON expr.
expr_without_variable ::= internal_functions_in_yacc.
expr_without_variable ::= T_INT_CAST expr.
expr_without_variable ::= T_DOUBLE_CAST expr.
expr_without_variable ::= T_STRING_CAST expr.
expr_without_variable ::= T_ARRAY_CAST expr.
expr_without_variable ::= T_OBJECT_CAST expr.
expr_without_variable ::= T_BOOL_CAST expr.
expr_without_variable ::= T_UNSET_CAST expr.
expr_without_variable ::= T_EXIT exit_expr.
expr_without_variable ::= T_AT expr.
expr_without_variable ::= scalar.
expr_without_variable ::= T_ARRAY T_PAR_OPEN array_pair_list T_PAR_CLOSE.
expr_without_variable ::= T_BACKTICK encaps_list T_BACKTICK.
expr_without_variable ::= T_PRINT expr.

function_call ::= T_STRING T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE.
function_call ::= fully_qualified_class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE.
function_call ::= fully_qualified_class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE.
function_call ::= variable_without_objects T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE.

fully_qualified_class_name ::= T_STRING.

class_name_reference ::= T_STRING.
class_name_reference ::= dynamic_class_name_reference.

dynamic_class_name_reference ::= base_variable T_OBJECT_OPERATOR object_property dynamic_class_name_variable_properties.
dynamic_class_name_reference ::= base_variable.

dynamic_class_name_variable_properties ::= dynamic_class_name_variable_properties dynamic_class_name_variable_property.
dynamic_class_name_variable_properties ::= .

dynamic_class_name_variable_property ::= T_OBJECT_OPERATOR object_property.

exit_expr ::= .
exit_expr ::= T_PAR_OPEN T_PAR_CLOSE.
exit_expr ::= T_PAR_OPEN expr T_PAR_CLOSE.

ctor_arguments(hasArgs) ::= . {
    hasArgs = FALSE;
}
ctor_arguments(hasArgs) ::= T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE. {
    hasArgs = TRUE;
}

common_scalar ::= T_LNUMBER.
common_scalar ::= T_DNUMBER.
common_scalar ::= T_CONSTANT_ENCAPSED_STRING.
common_scalar ::= T_LINE.
common_scalar ::= T_FILE.
common_scalar ::= T_CLASS_C.
common_scalar ::= T_METHOD_C.
common_scalar ::= T_FUNC_C.

static_scalar ::= common_scalar.
static_scalar ::= T_STRING.
static_scalar ::= T_PLUS static_scalar.
static_scalar ::= T_MINUS static_scalar.
static_scalar ::= T_ARRAY T_PAR_OPEN static_array_pair_list T_PAR_CLOSE.
static_scalar ::= static_class_constant.

static_class_constant ::= T_STRING T_PAAMAYIM_NEKUDOTAYIM T_STRING.

scalar ::= T_STRING.
scalar ::= T_STRING_VARNAME.
scalar ::= class_constant.
scalar ::= common_scalar.
scalar ::= T_DQUOTE encaps_list T_DQUOTE.
scalar ::= T_START_HEREDOC encaps_list T_END_HEREDOC.

static_array_pair_list ::= .
static_array_pair_list ::= non_empty_static_array_pair_list(arr) possible_comma(hasComma). {
    // @FIXME: we should try to be a little smarter about that...
    if (hasComma || arr <= 2) {
        return;
    }

    $this->addWarning(
        $this->_lexer->getPosition(),
        "Always add a comma at the end of the last array element, " .
        "unless the the whole array fits on one line (eg. callbacks)",
        "#arrays"
    );
}

possible_comma(res) ::= . {
    res = FALSE;
}
possible_comma(res) ::= T_COMMA. {
    res = TRUE;
}

non_empty_static_array_pair_list(res) ::= non_empty_static_array_pair_list(acc) T_COMMA static_scalar T_DOUBLE_ARROW static_scalar. {
    res = acc + 1;
}
non_empty_static_array_pair_list(res) ::= non_empty_static_array_pair_list(acc) T_COMMA static_scalar. {
    res = acc + 1;
}
non_empty_static_array_pair_list(res) ::= static_scalar T_DOUBLE_ARROW static_scalar. {
    res = 1;
}
non_empty_static_array_pair_list(res) ::= static_scalar. {
    res = 1;
}

expr ::= r_variable.
expr ::= expr_without_variable.

rw_variable ::= variable.

w_variable ::= variable.

r_variable ::= variable.

variable ::= base_variable_with_function_calls T_OBJECT_OPERATOR object_property method_or_not variable_properties.
variable ::= base_variable_with_function_calls.

variable_properties ::= variable_properties variable_property.
variable_properties ::= .

variable_property ::= T_OBJECT_OPERATOR object_property method_or_not.

method_or_not ::= T_PAR_OPEN function_call_parameter_list T_PAR_CLOSE.
method_or_not ::= .

variable_without_objects ::= reference_variable.
variable_without_objects ::= simple_indirect_reference reference_variable.

static_member ::= fully_qualified_class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects.

base_variable_with_function_calls ::= base_variable.
base_variable_with_function_calls ::= function_call.

base_variable ::= reference_variable.
base_variable ::= simple_indirect_reference reference_variable.
base_variable ::= static_member.

reference_variable ::= reference_variable T_SQUARE_OPEN dim_offset T_SQUARE_CLOSE.
reference_variable ::= reference_variable T_REAL_CURLY_OPEN expr T_REAL_CURLY_CLOSE.
reference_variable ::= compound_variable.

compound_variable ::= T_VARIABLE.
compound_variable ::= T_DOLLAR T_REAL_CURLY_OPEN expr T_REAL_CURLY_CLOSE.

dim_offset ::= .
dim_offset ::= expr.

object_property ::= object_dim_list.
object_property ::= variable_without_objects.

object_dim_list ::= object_dim_list T_SQUARE_OPEN dim_offset T_SQUARE_CLOSE.
object_dim_list ::= object_dim_list T_REAL_CURLY_OPEN expr T_REAL_CURLY_CLOSE.
object_dim_list ::= variable_name.

variable_name ::= T_STRING.
variable_name ::= T_REAL_CURLY_OPEN expr T_REAL_CURLY_CLOSE.

simple_indirect_reference ::= T_DOLLAR.
simple_indirect_reference ::= simple_indirect_reference T_DOLLAR.

assignment_list ::= assignment_list T_COMMA assignment_list_element.
assignment_list ::= assignment_list_element.

assignment_list_element ::= variable.
assignment_list_element ::= T_LIST T_PAR_OPEN assignment_list T_PAR_CLOSE.
assignment_list_element ::= .

array_pair_list ::= .
array_pair_list ::= non_empty_array_pair_list(arr) possible_comma(hasComma). {
    // @FIXME: we should try to be a little smarter about that...
    if (hasComma || arr <= 2) {
        return;
    }

    $this->addWarning(
        $this->_lexer->getPosition(),
        "Always add a comma at the end of the last array element, " .
        "unless the the whole array fits on one line (eg. callbacks)",
        "#arrays"
    );
}

non_empty_array_pair_list(res) ::= non_empty_array_pair_list(acc) T_COMMA expr T_DOUBLE_ARROW expr. {
    res = acc + 1;
}
non_empty_array_pair_list(res) ::= non_empty_array_pair_list(acc) T_COMMA expr. {
    res = acc + 1;
}
non_empty_array_pair_list(res) ::= expr T_DOUBLE_ARROW expr. {
    res = 1;
}
non_empty_array_pair_list(res) ::= expr. {
    res = 1;
}
non_empty_array_pair_list(res) ::= non_empty_array_pair_list(acc) T_COMMA expr T_DOUBLE_ARROW T_AMPERSAND w_variable. {
    res = acc + 1;
}
non_empty_array_pair_list(res) ::= non_empty_array_pair_list(acc) T_COMMA T_AMPERSAND w_variable. {
    res = acc + 1;
}
non_empty_array_pair_list(res) ::= expr T_DOUBLE_ARROW T_AMPERSAND w_variable. {
    res = 1;
}
non_empty_array_pair_list(res) ::= T_AMPERSAND w_variable. {
    res = 1;
}

encaps_list ::= encaps_list encaps_var.
encaps_list ::= encaps_list T_ENCAPSED_AND_WHITESPACE.
encaps_list ::= .

encaps_var ::= T_VARIABLE.
encaps_var ::= T_VARIABLE T_SQUARE_OPEN encaps_var_offset T_SQUARE_CLOSE.
encaps_var ::= T_VARIABLE T_OBJECT_OPERATOR T_STRING.
encaps_var ::= T_DOLLAR_OPEN_CURLY_BRACES expr T_REAL_CURLY_CLOSE.
encaps_var ::= T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME T_SQUARE_OPEN expr T_SQUARE_CLOSE T_REAL_CURLY_CLOSE.
encaps_var ::= T_CURLY_OPEN variable T_REAL_CURLY_CLOSE.

encaps_var_offset ::= T_STRING.
encaps_var_offset ::= T_NUM_STRING.
encaps_var_offset ::= T_VARIABLE.

internal_functions_in_yacc ::= T_ISSET T_PAR_OPEN isset_variables T_PAR_CLOSE.
internal_functions_in_yacc ::= T_EMPTY T_PAR_OPEN variable T_PAR_CLOSE.
internal_functions_in_yacc ::= T_INCLUDE(includeOp) expr. {
    $this->addError(
        includeOp,
        "Use include_once/require_once instead of include/require",
        "#including-code"
    );
}
internal_functions_in_yacc ::= T_INCLUDE_ONCE expr.
internal_functions_in_yacc ::= T_EVAL T_PAR_OPEN expr T_PAR_CLOSE.
internal_functions_in_yacc ::= T_REQUIRE expr.
internal_functions_in_yacc ::= T_REQUIRE_ONCE expr.

isset_variables ::= variable.
isset_variables ::= isset_variables T_COMMA variable.

class_constant ::= fully_qualified_class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING.

