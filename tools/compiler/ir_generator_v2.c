/* ============================================================
   PaTLang IR Generator in C - COMPLETE VERSION
   Supports: variables, operators, functions, lambdas, control flow, exceptions
   ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>

#define MAX_INSTRUCTIONS 10000
#define MAX_LABELS 1000
#define MAX_STRING_LEN 4096
#define MAX_TOKEN_LEN 256
#define MAX_TOKENS 2000

/* ============================================================
   UTILITIES
   ============================================================ */

static void *xmalloc(size_t size) {
  void *p = malloc(size);
  if (!p) { fprintf(stderr, "malloc failed\n"); exit(1); }
  return p;
}

static void *xrealloc(void *p, size_t size) {
  void *np = realloc(p, size);
  if (!np) { fprintf(stderr, "realloc failed\n"); exit(1); }
  return np;
}

static char *xstrdup(const char *s) {
  if (!s) return NULL;
  char *p = (char*)xmalloc(strlen(s) + 1);
  strcpy(p, s);
  return p;
}

/* ============================================================
   LEXER
   ============================================================ */

typedef enum {
  TOK_EOF, TOK_NUMBER, TOK_STRING, TOK_IDENT,
  TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH, TOK_PERCENT,
  TOK_EQ, TOK_NEQ, TOK_LT, TOK_GT, TOK_LEQ, TOK_GEQ,
  TOK_AND, TOK_OR, TOK_NOT,
  TOK_LPAREN, TOK_RPAREN, TOK_LBRACE, TOK_RBRACE, TOK_LBRACKET, TOK_RBRACKET,
  TOK_COMMA, TOK_SEMICOLON, TOK_COLON, TOK_DOT, TOK_ASSIGN,
  TOK_IF, TOK_ELSE, TOK_WHILE, TOK_FOR, TOK_IN,
  TOK_DEF, TOK_FN, TOK_RETURN, TOK_PRINT,
  TOK_LET, TOK_VAR, TOK_TRY, TOK_CATCH, TOK_THROW, TOK_FINALLY,
  TOK_TRUE, TOK_FALSE, TOK_NIL, TOK_THEN, TOK_END, TOK_DO
} TokenType;

typedef struct {
  TokenType type;
  char *value;
  double num_value;
} Token;

typedef struct {
  const char *input;
  size_t pos;
  size_t len;
} Lexer;

static void lex_init(Lexer *l, const char *input) {
  l->input = input;
  l->pos = 0;
  l->len = strlen(input);
}

static char lex_peek(Lexer *l) {
  if (l->pos >= l->len) return '\0';
  return l->input[l->pos];
}

static char lex_advance(Lexer *l) {
  if (l->pos >= l->len) return '\0';
  return l->input[l->pos++];
}

static void lex_skip_whitespace(Lexer *l) {
  while (l->pos < l->len && isspace(lex_peek(l))) {
    lex_advance(l);
  }
}

static void lex_skip_comment(Lexer *l) {
  if (lex_peek(l) == '#') {
    while (l->pos < l->len && lex_peek(l) != '\n') {
      lex_advance(l);
    }
  }
}

static Token lex_next(Lexer *l) {
  Token tok = {0};
  
  while (1) {
    lex_skip_whitespace(l);
    if (lex_peek(l) == '#') {
      lex_skip_comment(l);
    } else {
      break;
    }
  }
  
  char c = lex_peek(l);
  
  if (c == '\0') {
    tok.type = TOK_EOF;
    return tok;
  }
  
  /* Single character tokens */
  if (c == '+') { lex_advance(l); tok.type = TOK_PLUS; return tok; }
  if (c == '-') { lex_advance(l); tok.type = TOK_MINUS; return tok; }
  if (c == '*') { lex_advance(l); tok.type = TOK_STAR; return tok; }
  if (c == '/') { lex_advance(l); tok.type = TOK_SLASH; return tok; }
  if (c == '%') { lex_advance(l); tok.type = TOK_PERCENT; return tok; }
  if (c == '(') { lex_advance(l); tok.type = TOK_LPAREN; return tok; }
  if (c == ')') { lex_advance(l); tok.type = TOK_RPAREN; return tok; }
  if (c == '{') { lex_advance(l); tok.type = TOK_LBRACE; return tok; }
  if (c == '}') { lex_advance(l); tok.type = TOK_RBRACE; return tok; }
  if (c == '[') { lex_advance(l); tok.type = TOK_LBRACKET; return tok; }
  if (c == ']') { lex_advance(l); tok.type = TOK_RBRACKET; return tok; }
  if (c == ',') { lex_advance(l); tok.type = TOK_COMMA; return tok; }
  if (c == ';') { lex_advance(l); tok.type = TOK_SEMICOLON; return tok; }
  if (c == ':') { lex_advance(l); tok.type = TOK_COLON; return tok; }
  if (c == '.') { lex_advance(l); tok.type = TOK_DOT; return tok; }
  
  /* Multi-character operators */
  if (c == '=') {
    lex_advance(l);
    tok.type = lex_peek(l) == '=' ? (lex_advance(l), TOK_EQ) : TOK_ASSIGN;
    return tok;
  }
  if (c == '!') {
    lex_advance(l);
    tok.type = lex_peek(l) == '=' ? (lex_advance(l), TOK_NEQ) : TOK_NOT;
    return tok;
  }
  if (c == '<') {
    lex_advance(l);
    tok.type = lex_peek(l) == '=' ? (lex_advance(l), TOK_LEQ) : TOK_LT;
    return tok;
  }
  if (c == '>') {
    lex_advance(l);
    tok.type = lex_peek(l) == '=' ? (lex_advance(l), TOK_GEQ) : TOK_GT;
    return tok;
  }
  if (c == '&' && lex_peek(l) == '&') { lex_advance(l); lex_advance(l); tok.type = TOK_AND; return tok; }
  if (c == '|' && lex_peek(l) == '|') { lex_advance(l); lex_advance(l); tok.type = TOK_OR; return tok; }
  
  /* String literals */
  if (c == '"' || c == '\'') {
    char quote = c;
    lex_advance(l);
    char str_buf[MAX_STRING_LEN] = {0};
    size_t str_pos = 0;
    while (l->pos < l->len && lex_peek(l) != quote) {
      if (lex_peek(l) == '\\' && str_pos < MAX_STRING_LEN - 2) {
        lex_advance(l);
        char esc = lex_peek(l) ? lex_advance(l) : '\\';
        if (esc == 'n') str_buf[str_pos++] = '\n';
        else if (esc == 't') str_buf[str_pos++] = '\t';
        else if (esc == 'r') str_buf[str_pos++] = '\r';
        else str_buf[str_pos++] = esc;
      } else if (str_pos < MAX_STRING_LEN - 1) {
        str_buf[str_pos++] = lex_advance(l);
      }
    }
    if (lex_peek(l) == quote) lex_advance(l);
    tok.type = TOK_STRING;
    tok.value = xstrdup(str_buf);
    return tok;
  }
  
  /* Numbers */
  if (isdigit(c)) {
    char num_buf[MAX_TOKEN_LEN] = {0};
    size_t num_pos = 0;
    while (l->pos < l->len && (isdigit(lex_peek(l)) || lex_peek(l) == '.')) {
      num_buf[num_pos++] = lex_advance(l);
    }
    tok.type = TOK_NUMBER;
    tok.num_value = atof(num_buf);
    tok.value = xstrdup(num_buf);
    return tok;
  }
  
  /* Identifiers and keywords */
  if (isalpha(c) || c == '_') {
    char id_buf[MAX_TOKEN_LEN] = {0};
    size_t id_pos = 0;
    while (l->pos < l->len && (isalnum(lex_peek(l)) || lex_peek(l) == '_')) {
      id_buf[id_pos++] = lex_advance(l);
    }
    tok.value = xstrdup(id_buf);
    
    if (strcmp(id_buf, "if") == 0) tok.type = TOK_IF;
    else if (strcmp(id_buf, "else") == 0) tok.type = TOK_ELSE;
    else if (strcmp(id_buf, "then") == 0) tok.type = TOK_THEN;
    else if (strcmp(id_buf, "end") == 0) tok.type = TOK_END;
    else if (strcmp(id_buf, "do") == 0) tok.type = TOK_DO;
    else if (strcmp(id_buf, "while") == 0) tok.type = TOK_WHILE;
    else if (strcmp(id_buf, "for") == 0) tok.type = TOK_FOR;
    else if (strcmp(id_buf, "in") == 0) tok.type = TOK_IN;
    else if (strcmp(id_buf, "def") == 0) tok.type = TOK_DEF;
    else if (strcmp(id_buf, "fn") == 0) tok.type = TOK_FN;
    else if (strcmp(id_buf, "return") == 0) tok.type = TOK_RETURN;
    else if (strcmp(id_buf, "print") == 0) tok.type = TOK_PRINT;
    else if (strcmp(id_buf, "let") == 0) tok.type = TOK_LET;
    else if (strcmp(id_buf, "var") == 0) tok.type = TOK_VAR;
    else if (strcmp(id_buf, "try") == 0) tok.type = TOK_TRY;
    else if (strcmp(id_buf, "catch") == 0) tok.type = TOK_CATCH;
    else if (strcmp(id_buf, "throw") == 0) tok.type = TOK_THROW;
    else if (strcmp(id_buf, "finally") == 0) tok.type = TOK_FINALLY;
    else if (strcmp(id_buf, "true") == 0) tok.type = TOK_TRUE;
    else if (strcmp(id_buf, "false") == 0) tok.type = TOK_FALSE;
    else if (strcmp(id_buf, "nil") == 0) tok.type = TOK_NIL;
    else tok.type = TOK_IDENT;
    
    return tok;
  }
  
  /* Skip unknown */
  lex_advance(l);
  return lex_next(l);
}

/* ============================================================
   IR BUILDER
   ============================================================ */

typedef struct {
  FILE *out;
  size_t label_counter;
  size_t lambda_counter;
  int first_instruction;
} IRGen;

static IRGen irgen_init(FILE *out) {
  IRGen gen;
  gen.out = out;
  gen.label_counter = 0;
  gen.lambda_counter = 0;
  gen.first_instruction = 1;
  fprintf(out, "[");
  return gen;
}

static void irgen_close(IRGen *gen) {
  fprintf(gen->out, "]\n");
}

static char *irgen_next_label(IRGen *gen) {
  static char label[32];
  snprintf(label, sizeof(label), "L%zu", ++gen->label_counter);
  return xstrdup(label);
}

static char *irgen_next_lambda_name(IRGen *gen) {
  static char name[64];
  snprintf(name, sizeof(name), "__lambda_%zu", ++gen->lambda_counter);
  return xstrdup(name);
}

static void irgen_emit_raw(IRGen *gen, const char *ir_str) {
  if (!gen->first_instruction) fprintf(gen->out, ",");
  fprintf(gen->out, "%s", ir_str);
  gen->first_instruction = 0;
}

static void irgen_emit_const_num(IRGen *gen, double num) {
  char buf[128];
  snprintf(buf, sizeof(buf), "[\"IR_CONST\",%.17g]", num);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_const_str(IRGen *gen, const char *str) {
  char buf[4096];
  snprintf(buf, sizeof(buf), "[\"IR_CONST\",\"%s\"]", str);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_print(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_PRINT\"]");
}

static void irgen_emit_op(IRGen *gen, const char *op) {
  char buf[128];
  snprintf(buf, sizeof(buf), "[\"%s\"]", op);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_label(IRGen *gen, const char *label) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_LABEL\",\"%s\"]", label);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_jump(IRGen *gen, const char *label) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_JUMP\",\"%s\"]", label);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_jump_if(IRGen *gen, const char *label) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_JUMP_IF\",\"%s\"]", label);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_jump_if_false(IRGen *gen, const char *label) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_NOT\"]");
  irgen_emit_raw(gen, buf);
  snprintf(buf, sizeof(buf), "[\"IR_JUMP_IF\",\"%s\"]", label);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_load(IRGen *gen, const char *var) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_LOAD\",\"%s\"]", var);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_assign(IRGen *gen, const char *var) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_ASSIGN\",\"%s\"]", var);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_call(IRGen *gen, const char *func, int argc) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_CALL\",\"%s\",%d]", func, argc);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_return(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_RETURN\"]");
}

static void irgen_emit_def(IRGen *gen, const char *name, int pcount, const char *label, const char *params) {
  char buf[4096];
  snprintf(buf, sizeof(buf), "[\"IR_DEF\",\"%s\",%d,\"%s\",\"%s\"]", name, pcount, label, params);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_try(IRGen *gen, const char *label) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_TRY\",\"%s\"]", label);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_catch(IRGen *gen, const char *var) {
  char buf[256];
  snprintf(buf, sizeof(buf), "[\"IR_CATCH\",\"%s\"]", var);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_throw(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_THROW\"]");
}

static void irgen_emit_list(IRGen *gen, int count) {
  char buf[128];
  snprintf(buf, sizeof(buf), "[\"IR_LIST\",%d]", count);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_length(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_LENGTH\"]");
}

static void irgen_emit_index(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_INDEX\"]");
}

static void irgen_emit_geq(IRGen *gen) {
  irgen_emit_raw(gen, "[\"IR_GEQ\"]");
}

static void irgen_emit_call_indirect(IRGen *gen, int argc) {
  char buf[128];
  snprintf(buf, sizeof(buf), "[\"IR_CALL_INDIRECT\",%d]", argc);
  irgen_emit_raw(gen, buf);
}

static void irgen_emit_for_loop_start(IRGen *gen) {
  /* For loop setup: store iterable, initialize counter */
  irgen_emit_assign(gen, "__iterable");
  irgen_emit_const_num(gen, 0);
  irgen_emit_assign(gen, "__index");
}

/* ============================================================
   PARSER
   ============================================================ */

typedef struct {
  Token tokens[MAX_TOKENS];
  size_t len, pos;
  IRGen gen;
  char *defined_vars[1000];  /* Track variable names */
  int var_count;             /* Number of defined variables */
} Parser;

static void parser_init(Parser *p, Token *tokens, size_t len, FILE *out) {
  for (size_t i = 0; i < len; i++) {
    p->tokens[i] = tokens[i];
  }
  p->len = len;
  p->pos = 0;
  p->gen = irgen_init(out);
  p->var_count = 0;
}

static void parser_add_var(Parser *p, const char *name) {
  if (p->var_count < 999) {
    p->defined_vars[p->var_count] = xstrdup(name);
    p->var_count++;
  }
}

static int parser_has_var(Parser *p, const char *name) {
  for (int i = 0; i < p->var_count; i++) {
    if (strcmp(p->defined_vars[i], name) == 0) {
      return 1;
    }
  }
  return 0;
}

static Token parser_peek(Parser *p) {
  if (p->pos >= p->len) {
    Token tok = {0};
    tok.type = TOK_EOF;
    return tok;
  }
  return p->tokens[p->pos];
}

static Token parser_advance(Parser *p) {
  Token tok = parser_peek(p);
  if (p->pos < p->len) p->pos++;
  return tok;
}

static int parser_match(Parser *p, TokenType type) {
  if (parser_peek(p).type == type) {
    parser_advance(p);
    return 1;
  }
  return 0;
}

static Token parser_expect(Parser *p, TokenType type) {
  return parser_advance(p);
}

/* Forward declarations */
static void parse_statement_impl(Parser *p, int print_expr);
static void parse_statement(Parser *p);
static void parse_expression(Parser *p);
static void parse_or_expression(Parser *p);
static void parse_and_expression(Parser *p);
static void parse_equality_expression(Parser *p);
static void parse_comparison_expression(Parser *p);
static void parse_additive_expression(Parser *p);
static void parse_multiplicative_expression(Parser *p);
static void parse_unary_expression(Parser *p);
static void parse_primary_expression(Parser *p);

/* Check if token terminates an expression */
static int is_expression_terminator(TokenType type) {
  return type == TOK_THEN || type == TOK_ELSE || type == TOK_END ||
         type == TOK_DO || type == TOK_SEMICOLON || type == TOK_RBRACE ||
         type == TOK_COMMA || type == TOK_RPAREN || type == TOK_RBRACKET ||
         type == TOK_COLON || type == TOK_EOF;
}

static void parse_program(Parser *p) {
  while (parser_peek(p).type != TOK_EOF) {
    parse_statement_impl(p, 1);  /* Print top-level expressions */
  }
}

static void parse_block(Parser *p) {
  if (parser_match(p, TOK_LBRACE)) {
    while (parser_peek(p).type != TOK_RBRACE && parser_peek(p).type != TOK_EOF) {
      parse_statement_impl(p, 0);  /* Don't print block expressions */
    }
    parser_expect(p, TOK_RBRACE);
  } else {
    parse_statement_impl(p, 0);  /* Don't print block expressions */
  }
}

/* Internal statement parser with print_expr parameter */
static void parse_statement_impl(Parser *p, int print_expr) {
  Token tok = parser_peek(p);
  
  /* Check if we've reached a block terminator (END, ELSE, etc.) */
  if (is_expression_terminator(tok.type)) {
    return;  /* Don't try to parse terminators as statements */
  }
  
  if (tok.type == TOK_PRINT) {
    parser_advance(p);
    /* print can be: print(expr) or print "string" or print expr */
    if (parser_peek(p).type == TOK_LPAREN) {
      parser_advance(p);
      parse_expression(p);
      parser_expect(p, TOK_RPAREN);
    } else {
      /* No parens - just parse expression */
      parse_expression(p);
    }
    irgen_emit_print(&p->gen);
    parser_match(p, TOK_SEMICOLON);  /* Optional semicolon */
  }
  else if (tok.type == TOK_LET || tok.type == TOK_VAR) {
    parser_advance(p);
    Token name = parser_expect(p, TOK_IDENT);
    parser_add_var(p, name.value);  /* Track this variable */
    parser_expect(p, TOK_ASSIGN);
    parse_expression(p);
    irgen_emit_assign(&p->gen, name.value);
    parser_match(p, TOK_SEMICOLON);  /* Optional semicolon */
  }
  else if (tok.type == TOK_RETURN) {
    parser_advance(p);
    if (parser_peek(p).type != TOK_SEMICOLON && 
        parser_peek(p).type != TOK_RBRACE && 
        parser_peek(p).type != TOK_EOF) {
      parse_expression(p);
    }
    irgen_emit_return(&p->gen);
    parser_match(p, TOK_SEMICOLON);  /* Optional semicolon */
  }
  else if (tok.type == TOK_IF) {
    parser_advance(p);
    
    /* Support both: if (expr) and if expr then */
    int has_parens = (parser_peek(p).type == TOK_LPAREN);
    if (has_parens) {
      parser_advance(p);  /* consume '(' */
    }
    
    parse_expression(p);
    
    if (has_parens) {
      parser_expect(p, TOK_RPAREN);
    } else {
      parser_match(p, TOK_THEN);  /* Optional 'then' keyword */
    }
    
    char *else_label = irgen_next_label(&p->gen);
    char *end_label = irgen_next_label(&p->gen);
    
    /* Condition on stack - if FALSE, jump to else_label */
    irgen_emit_jump_if_false(&p->gen, else_label);
    
    /* Then block (when condition was TRUE) */
    /* Check if block is delimited by braces or end keyword */
    if (parser_peek(p).type == TOK_LBRACE) {
      parse_block(p);
    } else {
      /* Parse statements until 'end' or 'else' */
      int stmt_count = 0;
      while (parser_peek(p).type != TOK_END && 
             parser_peek(p).type != TOK_ELSE &&
             parser_peek(p).type != TOK_EOF) {
        parse_statement_impl(p, 0);
        stmt_count++;
        if (stmt_count > 100) {
          break;
        }
      }
    }
    
    /* Jump over else block */
    irgen_emit_jump(&p->gen, end_label);
    
    /* Else block (when condition was FALSE) */
    irgen_emit_label(&p->gen, else_label);
    
    /* Check for else block */
    if (parser_peek(p).type == TOK_ELSE) {
      parser_advance(p);  /* consume 'else' */
      if (parser_peek(p).type == TOK_IF) {
        /* else if - recursively parse as if */
        parse_statement_impl(p, 0);
      } else {
        /* Parse else block */
        if (parser_peek(p).type == TOK_LBRACE) {
          parse_block(p);
        } else {
          int stmt_count = 0;
          while (parser_peek(p).type != TOK_END &&
                 parser_peek(p).type != TOK_EOF) {
            parse_statement_impl(p, 0);
            stmt_count++;
            if (stmt_count > 100) {
              break;
            }
          }
        }
      }
    }
    
    /* Consume 'end' keyword if present */
    parser_match(p, TOK_END);
    
    /* End of if/else */
    irgen_emit_label(&p->gen, end_label);
    
    free(else_label);
    free(end_label);
  }
  else if (tok.type == TOK_WHILE) {
    parser_advance(p);
    /* while condition do body end */
    
    char *loop_label = irgen_next_label(&p->gen);
    char *end_label = irgen_next_label(&p->gen);
    
    /* Loop start label */
    irgen_emit_label(&p->gen, loop_label);
    
    /* Parse condition */
    parse_expression(p);
    
    /* Jump to end if condition is false (negate and jump if true) */
    irgen_emit_op(&p->gen, "IR_NOT");
    irgen_emit_jump_if(&p->gen, end_label);
    
    /* Consume optional 'do' keyword */
    parser_match(p, TOK_DO);
    
    /* Parse loop body */
    if (parser_peek(p).type == TOK_LBRACE) {
      parse_block(p);
    } else {
      while (parser_peek(p).type != TOK_END && 
             parser_peek(p).type != TOK_EOF) {
        parse_statement_impl(p, 0);
      }
    }
    
    /* Consume 'end' keyword */
    parser_match(p, TOK_END);
    
    /* Jump back to loop condition */
    irgen_emit_jump(&p->gen, loop_label);
    
    /* End label */
    irgen_emit_label(&p->gen, end_label);
    
    free(loop_label);
    free(end_label);
  }
  else if (tok.type == TOK_FOR) {
    parser_advance(p);
    /* for identifier in expression { body } */
    Token iter = parser_expect(p, TOK_IDENT);
    parser_expect(p, TOK_IN);
    parse_expression(p);
    
    char *loop_label = irgen_next_label(&p->gen);
    char *end_label = irgen_next_label(&p->gen);
    
    /* Store iterable in temporary variable */
    irgen_emit_assign(&p->gen, "__iterable");
    
    /* Initialize index to 0 */
    irgen_emit_const_num(&p->gen, 0);
    irgen_emit_assign(&p->gen, "__index");
    
    /* Loop start label */
    irgen_emit_label(&p->gen, loop_label);
    
    /* Check if index >= length(iterable), if so jump to end */
    irgen_emit_load(&p->gen, "__index");
    irgen_emit_load(&p->gen, "__iterable");
    irgen_emit_op(&p->gen, "IR_LENGTH");
    irgen_emit_op(&p->gen, "IR_GEQ");
    irgen_emit_jump_if(&p->gen, end_label);
    
    /* Load element at current index into iterator variable */
    irgen_emit_load(&p->gen, "__iterable");
    irgen_emit_load(&p->gen, "__index");
    irgen_emit_op(&p->gen, "IR_INDEX");
    irgen_emit_assign(&p->gen, iter.value);
    
    /* Execute loop body */
    parse_block(p);
    
    /* Increment index */
    irgen_emit_load(&p->gen, "__index");
    irgen_emit_const_num(&p->gen, 1);
    irgen_emit_op(&p->gen, "IR_ADD");
    irgen_emit_assign(&p->gen, "__index");
    
    /* Jump back to loop condition */
    irgen_emit_jump(&p->gen, loop_label);
    
    /* End label */
    irgen_emit_label(&p->gen, end_label);
    
    free(loop_label);
    free(end_label);
  }
  else if (tok.type == TOK_DEF) {
    parser_advance(p);
    Token func_name = parser_expect(p, TOK_IDENT);
    parser_expect(p, TOK_LPAREN);
    
    char params_str[MAX_STRING_LEN] = {0};
    int pcount = 0;
    while (parser_peek(p).type != TOK_RPAREN) {
      Token param = parser_expect(p, TOK_IDENT);
      if (pcount > 0) strcat(params_str, ",");
      strcat(params_str, param.value);
      pcount++;
      if (parser_match(p, TOK_COMMA)) {}
    }
    parser_expect(p, TOK_RPAREN);
    
    char *func_label = irgen_next_label(&p->gen);
    char *skip_label = irgen_next_label(&p->gen);
    
    irgen_emit_def(&p->gen, func_name.value, pcount, func_label, params_str);
    irgen_emit_jump(&p->gen, skip_label);
    irgen_emit_label(&p->gen, func_label);
    
    parser_expect(p, TOK_LBRACE);
    while (parser_peek(p).type != TOK_RBRACE && parser_peek(p).type != TOK_EOF) {
      parse_statement_impl(p, 0);  /* Don't print expressions inside functions */
    }
    parser_expect(p, TOK_RBRACE);
    
    irgen_emit_return(&p->gen);
    irgen_emit_label(&p->gen, skip_label);
    
    free(func_label);
    free(skip_label);
  }
  else if (tok.type == TOK_THROW) {
    parser_advance(p);  /* consume 'throw' */
    parser_expect(p, TOK_LPAREN);
    parse_expression(p);
    parser_expect(p, TOK_RPAREN);
    irgen_emit_throw(&p->gen);
    parser_match(p, TOK_SEMICOLON);
  }
  else if (tok.type == TOK_TRY) {
    parser_advance(p);  /* consume 'try' */
    
    char *catch_label = irgen_next_label(&p->gen);
    char *finally_label = irgen_next_label(&p->gen);
    char *end_label = irgen_next_label(&p->gen);
    
    /* Set up try/catch handler */
    irgen_emit_try(&p->gen, catch_label);
    
    /* Parse try block */
    parse_block(p);
    
    /* Jump to finally on success */
    irgen_emit_jump(&p->gen, finally_label);
    
    /* Catch block */
    irgen_emit_label(&p->gen, catch_label);
    if (parser_peek(p).type == TOK_CATCH) {
      parser_advance(p);  /* consume 'catch' */
      parser_expect(p, TOK_LPAREN);
      Token catch_var = parser_expect(p, TOK_IDENT);
      parser_expect(p, TOK_RPAREN);
      
      /* Assign exception to catch variable */
      irgen_emit_catch(&p->gen, catch_var.value);
      
      parse_block(p);
    }
    
    /* Finally block */
    irgen_emit_label(&p->gen, finally_label);
    if (parser_peek(p).type == TOK_FINALLY) {
      parser_advance(p);  /* consume 'finally' */
      parse_block(p);
    }
    
    irgen_emit_label(&p->gen, end_label);
    
    free(catch_label);
    free(finally_label);
    free(end_label);
  }
  else if (tok.type == TOK_LBRACE) {
    parser_advance(p);
    while (parser_peek(p).type != TOK_RBRACE && parser_peek(p).type != TOK_EOF) {
      parse_statement_impl(p, 0);  /* Don't print expressions in blocks */
    }
    parser_expect(p, TOK_RBRACE);
  }
  else if (tok.type == TOK_SEMICOLON) {
    /* Empty statement - just skip the semicolon */
    parser_advance(p);
  }
  else if (tok.type == TOK_EOF) {
    /* End of input - don't process */
    return;
  }
  else if (tok.type == TOK_IDENT) {
    /* Check if this is an assignment (identifier followed by =) by peeking ahead */
    /* Current token is IDENT at p->pos, next token is at p->pos+1 */
    TokenType next_type = TOK_EOF;
    if (p->pos + 1 < p->len) {
      next_type = p->tokens[p->pos + 1].type;
    }
    
    if (next_type == TOK_ASSIGN) {
      /* It's an assignment */
      Token ident = parser_advance(p);  /* consume identifier */
      parser_advance(p);  /* consume '=' */
      parse_expression(p);
      irgen_emit_assign(&p->gen, ident.value);
    } else {
      /* Not an assignment, parse as expression statement */
      parse_expression(p);
      /* Automatically print top-level expression values (REPL-style) */
      if (print_expr) {
        irgen_emit_print(&p->gen);
      }
    }
  }
  else {
    /* Fallback: try to parse as expression statement */
    parse_expression(p);
    /* Automatically print top-level expression values (REPL-style) */
    if (print_expr) {
      irgen_emit_print(&p->gen);
    }
  }
  
  parser_match(p, TOK_SEMICOLON);
}

/* Public parse_statement wrapper - don't print expressions by default */
static void parse_statement(Parser *p) {
  parse_statement_impl(p, 0);
}

static void parse_expression(Parser *p) {
  parse_or_expression(p);
}

static void parse_or_expression(Parser *p) {
  parse_and_expression(p);
  int loop_count = 0;
  while (parser_match(p, TOK_OR)) {
    if (++loop_count > 100) {
      break;
    }
    parse_and_expression(p);
    irgen_emit_op(&p->gen, "IR_OR");
  }
}

static void parse_and_expression(Parser *p) {
  parse_equality_expression(p);
  int loop_count = 0;
  while (parser_match(p, TOK_AND)) {
    if (++loop_count > 100) {
      break;
    }
    parse_equality_expression(p);
    irgen_emit_op(&p->gen, "IR_AND");
  }
}

static void parse_equality_expression(Parser *p) {
  parse_comparison_expression(p);
  Token op = parser_peek(p);
  if (op.type == TOK_EQ || op.type == TOK_NEQ) {
    parser_advance(p);
    parse_comparison_expression(p);
    irgen_emit_op(&p->gen, op.type == TOK_EQ ? "IR_EQ" : "IR_NEQ");
  }
}

static void parse_comparison_expression(Parser *p) {
  parse_additive_expression(p);
  Token op = parser_peek(p);
  if (op.type == TOK_LT || op.type == TOK_GT || op.type == TOK_LEQ || op.type == TOK_GEQ) {
    parser_advance(p);
    parse_additive_expression(p);
    const char *op_name = 
      op.type == TOK_LT ? "IR_LT" :
      op.type == TOK_GT ? "IR_GT" :
      op.type == TOK_LEQ ? "IR_LEQ" : "IR_GEQ";
    irgen_emit_op(&p->gen, op_name);
  }
}

static void parse_additive_expression(Parser *p) {
  parse_multiplicative_expression(p);
  while (!is_expression_terminator(parser_peek(p).type) &&
         (parser_peek(p).type == TOK_PLUS || parser_peek(p).type == TOK_MINUS)) {
    Token op = parser_advance(p);
    parse_multiplicative_expression(p);
    irgen_emit_op(&p->gen, op.type == TOK_PLUS ? "IR_ADD" : "IR_SUB");
  }
}

static void parse_multiplicative_expression(Parser *p) {
  parse_unary_expression(p);
  while (!is_expression_terminator(parser_peek(p).type) &&
         (parser_peek(p).type == TOK_STAR || parser_peek(p).type == TOK_SLASH || parser_peek(p).type == TOK_PERCENT)) {
    Token op = parser_advance(p);
    parse_unary_expression(p);
    const char *op_name = 
      op.type == TOK_STAR ? "IR_MULTIPLY" :
      op.type == TOK_SLASH ? "IR_DIVIDE" : "IR_MODULO";
    irgen_emit_op(&p->gen, op_name);
  }
}

static void parse_unary_expression(Parser *p) {
  if (parser_match(p, TOK_NOT)) {
    parse_unary_expression(p);
    irgen_emit_op(&p->gen, "IR_NOT");
  } else {
    parse_primary_expression(p);
  }
}

static void parse_primary_expression(Parser *p) {
  Token tok = parser_peek(p);
  
  if (tok.type == TOK_NUMBER) {
    parser_advance(p);
    irgen_emit_const_num(&p->gen, tok.num_value);
  }
  else if (tok.type == TOK_STRING) {
    parser_advance(p);
    irgen_emit_const_str(&p->gen, tok.value);
  }
  else if (tok.type == TOK_TRUE) {
    parser_advance(p);
    irgen_emit_const_num(&p->gen, 1);
  }
  else if (tok.type == TOK_FALSE) {
    parser_advance(p);
    irgen_emit_const_num(&p->gen, 0);
  }
  else if (tok.type == TOK_NIL) {
    parser_advance(p);
    irgen_emit_raw(&p->gen, "[\"IR_CONST\",nil]");
  }
  else if (tok.type == TOK_IDENT) {
    parser_advance(p);
    if (parser_match(p, TOK_LPAREN)) {
      /* Function or lambda call */
      int arg_count = 0;
      while (parser_peek(p).type != TOK_RPAREN) {
        parse_expression(p);
        arg_count++;
        if (parser_match(p, TOK_COMMA)) {}
      }
      parser_expect(p, TOK_RPAREN);
      
      /* Check if this is a variable holding a lambda (not a defined function) */
      if (parser_has_var(p, tok.value)) {
        /* Lambda call via variable - load the function name, then call indirect */
        irgen_emit_load(&p->gen, tok.value);
        irgen_emit_call_indirect(&p->gen, arg_count);
      } else {
        /* Direct function call */
        irgen_emit_call(&p->gen, tok.value, arg_count);
      }
    } else {
      /* Variable load */
      irgen_emit_load(&p->gen, tok.value);
    }
  }
  else if (tok.type == TOK_LPAREN) {
    parser_advance(p);
    parse_expression(p);
    parser_expect(p, TOK_RPAREN);
  }
  else if (tok.type == TOK_FN) {
    /* Lambda expression: fn(params) { body } */
    parser_advance(p);  /* consume 'fn' */
    parser_expect(p, TOK_LPAREN);
    
    /* Parse parameters */
    char params_str[MAX_STRING_LEN] = {0};
    int pcount = 0;
    while (parser_peek(p).type != TOK_RPAREN) {
      Token param = parser_expect(p, TOK_IDENT);
      if (pcount > 0) strcat(params_str, ",");
      strcat(params_str, param.value);
      pcount++;
      if (parser_match(p, TOK_COMMA)) {}
    }
    parser_expect(p, TOK_RPAREN);
    
    /* Generate unique lambda name */
    char *lambda_name = irgen_next_lambda_name(&p->gen);
    char *func_label = irgen_next_label(&p->gen);
    char *skip_label = irgen_next_label(&p->gen);
    
    /* Emit function definition */
    irgen_emit_def(&p->gen, lambda_name, pcount, func_label, params_str);
    irgen_emit_jump(&p->gen, skip_label);
    irgen_emit_label(&p->gen, func_label);
    
    /* Parse lambda body */
    parser_expect(p, TOK_LBRACE);
    while (parser_peek(p).type != TOK_RBRACE && parser_peek(p).type != TOK_EOF) {
      parse_statement(p);
    }
    parser_expect(p, TOK_RBRACE);
    
    irgen_emit_return(&p->gen);
    irgen_emit_label(&p->gen, skip_label);
    
    /* Push lambda name as a string value (for assignment) */
    irgen_emit_const_str(&p->gen, lambda_name);
    
    free(lambda_name);
    free(func_label);
    free(skip_label);
  }
  else if (tok.type == TOK_LBRACKET) {
    /* Array literal [elem1, elem2, ...] */
    parser_advance(p);
    int elem_count = 0;
    while (parser_peek(p).type != TOK_RBRACKET && parser_peek(p).type != TOK_EOF) {
      parse_expression(p);
      elem_count++;
      if (parser_match(p, TOK_COMMA)) {}
    }
    parser_expect(p, TOK_RBRACKET);
    /* Emit IR_LIST with element count */
    char buf[64];
    snprintf(buf, sizeof(buf), "[\"IR_LIST\",%d]", elem_count);
    irgen_emit_raw(&p->gen, buf);
  }
  else if (tok.type == TOK_EOF) {
    /* End of input - don't advance */
    return;
  }
  else if (is_expression_terminator(tok.type)) {
    /* Expression terminator - gracefully stop parsing */
    return;
  }
  else {
    /* Unknown token in expression - skip it to prevent infinite loop */
    fprintf(stderr, "[WARN] Skipping unexpected token in expression: %d\n", tok.type);
    parser_advance(p);
  }
}

/* ============================================================
   MAIN
   ============================================================ */

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: ir_generator <input.patlang> [output.ir]\n");
    return 1;
  }
  
  const char *input_file = argv[1];
  const char *output_file = argc > 2 ? argv[2] : "out.ir";
  
  /* Read source file */
  FILE *f = fopen(input_file, "rb");
  if (!f) {
    fprintf(stderr, "[ERR] Cannot open %s\n", input_file);
    return 1;
  }
  fseek(f, 0, SEEK_END);
  size_t size = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *source = (char*)xmalloc(size + 1);
  fread(source, 1, size, f);
  source[size] = '\0';
  fclose(f);
  
  /* Tokenize */
  Lexer lex;
  lex_init(&lex, source);
  Token tokens[MAX_TOKENS];
  size_t token_count = 0;
  while (token_count < MAX_TOKENS) {
    tokens[token_count] = lex_next(&lex);
    if (tokens[token_count].type == TOK_EOF) break;
    token_count++;
  }
  tokens[token_count].type = TOK_EOF;
  
  /* Parse and generate IR */
  FILE *out = fopen(output_file, "w");
  if (!out) {
    fprintf(stderr, "[ERR] Cannot write %s\n", output_file);
    return 1;
  }
  
  Parser parser;
  parser_init(&parser, tokens, token_count, out);
  parse_program(&parser);
  irgen_close(&parser.gen);
  
  fclose(out);
  fflush(stdout);
  fflush(stderr);
  
  fprintf(stderr, "[INFO] Generated IR: %s\n", output_file);
  
  free(source);
  return 0;
}
