/*
 * Copyright 2015 Coursera Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Antlr grammar for the Pegasus data language format (.pdl).
 */
grammar Pdl;

@header {
  package com.linkedin.data.grammar;

  import com.linkedin.data.schema.grammar.PdlParseUtils;
  import java.util.Arrays;
}

// Document is the top level node of this grammar.
// Each .pdl file contains exactly one document.
document: namespaceDeclaration? importDeclarations namedTypeDeclaration;

namespaceDeclaration: NAMESPACE qualifiedIdentifier;

importDeclarations: importDeclaration*;

importDeclaration: IMPORT type=qualifiedIdentifier;

// A typeReference is simply a type name that refers to a type defined elsewhere.
typeReference returns [String value]: qualifiedIdentifier {
  $value = $qualifiedIdentifier.value;
};

typeDeclaration: namedTypeDeclaration | anonymousTypeDeclaration;

// Only named declarations support schemadoc and properties.
namedTypeDeclaration: doc=schemadoc? props+=propDeclaration*
  (recordDeclaration | enumDeclaration | typerefDeclaration | fixedDeclaration);

anonymousTypeDeclaration: unionDeclaration | arrayDeclaration | mapDeclaration;

typeAssignment: typeReference | typeDeclaration;

// Each property is a node in a properties tree, keyed by it's path in the tree.
// The value of each property may be any JSON type.
// If the property does not specify a property, it defaults to JSON 'true'.
propDeclaration returns [String name, List<String> path]: propNameDeclaration propJsonValue? {
  $name = $propNameDeclaration.name;
  $path = Arrays.asList($propNameDeclaration.name.split("\\."));
};

propNameDeclaration returns [String name]: AT qualifiedIdentifier {
  $name = $qualifiedIdentifier.value;
};

propJsonValue: EQ jsonValue;

recordDeclaration returns [String name]: RECORD identifier recordDecl=fieldSelection {
  $name = $identifier.value;
};

enumDeclaration returns [String name]: ENUM identifier enumDecl=enumSymbolDeclarations {
  $name = $identifier.value;
};

enumSymbolDeclarations: OPEN_BRACE symbolDecls+=enumSymbolDeclaration* CLOSE_BRACE;

enumSymbolDeclaration: doc=schemadoc? props+=propDeclaration* symbol=enumSymbol;

enumSymbol returns [String value]: identifier {
  $value = $identifier.value;
};

typerefDeclaration returns [String name]: TYPEREF identifier EQ ref=typeAssignment {
  $name = $identifier.value;
};

fixedDeclaration returns[String name, int size]:
  FIXED identifier sizeStr=NUMBER_LITERAL {
  $name = $identifier.value;
  $size = $sizeStr.int;
};

unionDeclaration: UNION typeParams=unionTypeAssignments;

unionTypeAssignments: OPEN_BRACKET members+=unionMemberDeclaration* CLOSE_BRACKET;

unionMemberDeclaration: member=typeAssignment;

arrayDeclaration: ARRAY typeParams=arrayTypeAssignments;

arrayTypeAssignments: OPEN_BRACKET items=typeAssignment CLOSE_BRACKET;

mapDeclaration: MAP typeParams=mapTypeAssignments;

mapTypeAssignments: OPEN_BRACKET key=typeAssignment value=typeAssignment CLOSE_BRACKET;

fieldSelection: OPEN_BRACE fields+=fieldSelectionElement* CLOSE_BRACE;

fieldSelectionElement: fieldInclude | fieldDeclaration;

fieldInclude: DOTDOTDOT typeReference;

fieldDeclaration returns [String name, boolean isOptional]:
    doc=schemadoc? props+=propDeclaration* fieldName=identifier COLON type=typeAssignment QUESTION_MARK?
    fieldDefault? {
  $name = $identifier.value;
  $isOptional = $QUESTION_MARK() != null;
};

fieldDefault: EQ jsonValue;

// A qualified identifier is simply one or more '.' separated identifiers.
qualifiedIdentifier returns [String value]: ID (DOT ID)* {
  $value = PdlParseUtils.unescapeIdentifier($text);
};

identifier returns [String value]: ID {
  $value = PdlParseUtils.unescapeIdentifier($text);
};

// Schemadoc strings support markdown formatting.
schemadoc returns [String value]: SCHEMADOC_COMMENT {
  $value = PdlParseUtils.extractMarkdown($SCHEMADOC_COMMENT.text);
};

// Embedded JSON Grammar
// JSON is used both for property values and for field default values.
object: OPEN_BRACE objectEntry* CLOSE_BRACE;

objectEntry: key=string COLON value=jsonValue ;

array: OPEN_BRACKET items=jsonValue* CLOSE_BRACKET;

jsonValue: string | number | object | array | bool | nullValue;

string returns [String value]: STRING_LITERAL {
  $value = PdlParseUtils.extractString($STRING_LITERAL.text);
};

number returns [Number value]: NUMBER_LITERAL {
  $value = PdlParseUtils.toNumber($NUMBER_LITERAL.text);
};

bool returns [Boolean value]: BOOLEAN_LITERAL {
  $value = Boolean.valueOf($BOOLEAN_LITERAL.text);
};

nullValue: NULL_LITERAL;

// Tokens
// Antlr uses the below token rules to construct it the lexer for this grammar.
ARRAY: 'array';
ENUM: 'enum';
FIXED: 'fixed';
IMPORT: 'import';
MAP: 'map';
NAMESPACE: 'namespace';
RECORD: 'record';
TYPEREF: 'typeref';
UNION: 'union';

OPEN_PAREN: '(';
CLOSE_PAREN: ')';
OPEN_BRACE: '{';
CLOSE_BRACE: '}';
OPEN_BRACKET: '[';
CLOSE_BRACKET: ']';

AT: '@';
COLON: ':';
DOT: '.';
DOTDOTDOT: '...';
EQ: '=';
QUESTION_MARK: '?';

BOOLEAN_LITERAL: 'true' | 'false';
NULL_LITERAL: 'null';

SCHEMADOC_COMMENT: '/**' .*? '*/';
BLOCK_COMMENT: '/*' .*? '*/' -> skip;
LINE_COMMENT: '//' ~['\r\n']* -> skip;

NUMBER_LITERAL: '-'? ('0' | [1-9] [0-9]*) ( '.' [0-9]+)? ([eE][+-]?[0-9]+)?;

fragment HEX: [0-9a-fA-F];
fragment UNICODE: 'u' HEX HEX HEX HEX;
fragment ESC:   '\\' (["\\/bfnrt] | UNICODE);
STRING_LITERAL: '"' (ESC | ~["\\])* '"';

ID: '`'? [A-Za-z_] [A-Za-z0-9_]* '`'?; // Avro/Pegasus identifiers with Scala/Swift escaping

// "insignificant commas" are used in this grammar. Commas may be added as desired
// in source files, but they are treated as whitespace.
WS: [ \t\n\r\f,]+ -> skip;
