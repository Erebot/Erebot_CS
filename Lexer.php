#!/usr/bin/env php
<?php

include_once("Parser.php");

class Erebot_CodingStandard_Value
{
    protected $_line;
    protected $_column;
    protected $_value;

    public function __construct($line, $column, $value)
    {
        $this->_line    = $line;
        $this->_column  = $column;
        $this->_value   = $value;
    }

    public function getValue()
    {
        return $this->_value;
    }

    public function getLine()
    {
        return $this->_line;
    }

    public function getColumn()
    {
        return $this->_column;
    }
}

class Erebot_CodingStandard_Lexer
{
    protected $_parser;
    protected $_tokmap;
    protected $_line;
    protected $_column;
    protected $_file;

    public function __construct(Erebot_CodingStandard_Parser $parser)
    {
        $this->_parser  = $parser;
        $this->_tokmap  = array(
            ',' => Erebot_CodingStandard_Parser::T_COMMA,
            '=' => Erebot_CodingStandard_Parser::T_EQUAL,
            '?' => Erebot_CodingStandard_Parser::T_QUESTION,
            ':' => Erebot_CodingStandard_Parser::T_COLON,
            '|' => Erebot_CodingStandard_Parser::T_PIPE,
            '^' => Erebot_CodingStandard_Parser::T_CIRCUMFLEX,
            '&' => Erebot_CodingStandard_Parser::T_AMPERSAND,
            '<' => Erebot_CodingStandard_Parser::T_SMALLER,
            '>' => Erebot_CodingStandard_Parser::T_GREATER,
            '+' => Erebot_CodingStandard_Parser::T_PLUS,
            '-' => Erebot_CodingStandard_Parser::T_MINUS,
            '.' => Erebot_CodingStandard_Parser::T_DOT,
            '*' => Erebot_CodingStandard_Parser::T_STAR,
            '/' => Erebot_CodingStandard_Parser::T_SLASH,
            '%' => Erebot_CodingStandard_Parser::T_PERCENT,
            '!' => Erebot_CodingStandard_Parser::T_EXCLAMATION,
            '~' => Erebot_CodingStandard_Parser::T_TILDE,
            '@' => Erebot_CodingStandard_Parser::T_AT,
            '[' => Erebot_CodingStandard_Parser::T_SQUARE_OPEN,
            '(' => Erebot_CodingStandard_Parser::T_PAR_OPEN,
            ')' => Erebot_CodingStandard_Parser::T_PAR_CLOSE,
            ';' => Erebot_CodingStandard_Parser::T_SEMI_COLON,
            '{' => Erebot_CodingStandard_Parser::T_REAL_CURLY_OPEN,
            '}' => Erebot_CodingStandard_Parser::T_REAL_CURLY_CLOSE,
            '$' => Erebot_CodingStandard_Parser::T_DOLLAR,
            '`' => Erebot_CodingStandard_Parser::T_BACKTICK,
            '"' => Erebot_CodingStandard_Parser::T_DQUOTE,
            ']' => Erebot_CodingStandard_Parser::T_SQUARE_CLOSE,
        );

        $constants  = get_defined_constants(TRUE);
        $php_tokens = $constants["tokenizer"];
        $reflector  = new ReflectionClass("Erebot_CodingStandard_Parser");
        $constants  = $reflector->getConstants();
        foreach ($php_tokens as $tokname => $tokvalue) {
            if (strncmp($tokname, "T_", 2))
                continue;
            if (isset($constants[$tokname]))
                $this->_tokmap[$tokvalue] = $constants[$tokname];
        }
    }

    protected function _doLex(array $tokens)
    {
        $this->_line    = 1;
        $this->_column  = 1;

        foreach ($tokens as $token) {
            if (is_array($token)) {
                $value = $token[1];
                $token = $token[0];
            }
            else {
                $value = $token;
            }

            // Line/column for the current token.
            $currentLine    = $this->_line;
            $currentColumn  = $this->_column;

            /* Update $this->_line/_column with the position
             * of the next token. Must be done before doParse()
             * is called in case a rule calls getPosition(). */
            $this->_line   += (int) preg_match_all(
                                        '/\\r\\n?|\\n/',
                                        $value, $m
                                    );
            $lastCR         = strrpos($value, "\r");
            $lastLF         = strrpos($value, "\n");
            if ($lastCR !== FALSE || $lastLF !== FALSE) {
                $first = max((int) $lastCR, (int) $lastLF);
                $this->_column  = strlen((string) substr($value, $first));
            }
            else {
                $this->_column += strlen($value);
            }

            if (!isset($this->_tokmap[$token])) {
                $name = token_name($token);
                echo "Unknown token ($token / $name) at " .
                     "$currentLine:$currentColumn " .
                     "with value: '$value'\n";
                continue;
            }

            $this->_parser->doParse(
                $this->_tokmap[$token],
                new Erebot_CodingStandard_Value(
                    $currentLine,
                    $currentColumn,
                    $value
                )
            );
        }

        // Send EOF signal.
        $this->_parser->doParse(0, $this->getPosition());
    }

    public function getPosition($value = NULL)
    {
        return new Erebot_CodingStandard_Value(
            $this->_line,
            $this->_column,
            $value
        );
    }

    public function getFile()
    {
        return $this->_file;
    }

    public function lex($file, &$problems)
    {
        $file           = realpath($file);
        $this->_file    = $file;

        $tokens = token_get_all(file_get_contents($file));
        $this->_parser->setLexer($this);
        $this->_doLex($tokens);

        $problems = $this->_parser->getProblems();
    }
}

$parser     = new Erebot_CodingStandard_Parser();
$lexer      = new Erebot_CodingStandard_Lexer($parser);
$problems   = array();
$file       = __FILE__;
#$file       = dirname(__FILE__) . DIRECTORY_SEPARATOR . "Parser.php";
try {
    $lexer->lex($file, $problems);
}
catch (Exception $e) {
    echo $e->getMessage().PHP_EOL;
}

$file       = $lexer->getFile();
$baseUrl    = "http://erebot.github.com/Erebot/Coding_Standard.html";
foreach ($problems as $problem) {
    $line   = $problem[1][0]->getLine();
    $column = $problem[1][0]->getColumn();
    if ($problem[3] === NULL) {
        echo "${problem[0]}:$file:$line:$column:${problem[2]}\n";
    }
    else {
        $url = $baseUrl . '#' . $problem[3];
        echo "${problem[0]}:$file:$line:$column:${problem[2]} ($url)\n";
    }
}

