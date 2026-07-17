/*
  Patlang Native IR Runtime (canonical minimal implementation)
  -------------------------------------------------------------
  This file is the authoritative minimal native runtime used by the test
  harness and CI. It intentionally implements only the small set of IR
  operations required by the translator and tests (const, print, arithmetic,
  assigns, control flow, lists and basic file IO) and is kept compact.

  Regeneration / maintenance:
  - Prefer to update higher-level generator templates or lowerers (e.g.
    tools/lower_patlang_to_c.py) when making large structural changes.
  - If you must edit this file directly, add a short note describing why
    the change is necessary and where the corresponding generator lives.
  - On Windows, linking with `-static` can lead to MinGW/clang linker
    issues (undefined WinMain). Use a non-static link strategy for CI
    Windows jobs or add an environment-specific build wrapper.

  Format / contract:
    - Input: IR file is a Ruby-style array literal of arrays, e.g.
        [["IR_CONST",2],["IR_CONST",3],["IR_ADD"],["IR_PRINT"],["IR_RETURN",nil]]
    - Output: Each IR_PRINT prints to stdout as:  [OUT] <value>\n
    - Diagnostics: use stderr prefixes like [INFO] / [ERR].
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <sys/types.h>
#include <unistd.h>

/* ======================= Generic Helpers ======================= */
static void *xmalloc(size_t n){ void *p = malloc(n); if(!p){ fprintf(stderr,"[ERR] OOM allocating %zu bytes\n", n); exit(1);} return p; }
static void *xrealloc(void *p,size_t n){ void *r = realloc(p,n); if(!r){ fprintf(stderr,"[ERR] OOM realloc %zu bytes\n", n); exit(1);} return r; }
static char *xstrdup(const char *s){ if(!s) return NULL; size_t n=strlen(s)+1; char *p=(char*)xmalloc(n); memcpy(p,s,n); return p; }

/* ======================= Event System Stubs ======================= */
/* Minimal event system support (Phase 5.4 integration) */
typedef struct {
  char *name;
  void *handlers;
} EventType;

static EventType *global_events = NULL;
static int event_count = 0;

static void event_init(void) { 
  /* Initialize event system - TODO: full implementation when event_runtime.h integrated */
}

static void event_create_scope(void) {
  /* Create scope context - TODO: full implementation */
}

static EventType *event_create(const char *name) {
  /* Create event - simplified stub */
  return (EventType*)xmalloc(sizeof(EventType));
}

static int event_emit(const char *name, const char *payload) {
  /* Emit event - returns handler count (stub: 0) */
  (void)name; (void)payload;
  return 0;
}

static int event_on(const char *name, void *handler) {
  /* Subscribe to event - returns handler ID (stub: 1) */
  (void)name; (void)handler;
  return 1;
}

static int event_once(const char *name, void *handler) {
  /* Subscribe once to event - returns handler ID (stub: 2) */
  (void)name; (void)handler;
  return 2;
}

static int event_off(int handler_id) {
  /* Unsubscribe handler - returns success */
  (void)handler_id;
  return 1;
}

static void event_clear_all(void) {
  /* Clean up all events - stub */
}

/* ======================= Value Representation ======================= */
typedef enum { V_NIL, V_NUM, V_STR, V_LIST } VType;
typedef struct Value Value;
struct Value {
  VType t;
  double num;
  char *s;
  Value **list;     /* for V_LIST: heap-allocated array of Value* */
  size_t list_len;  /* current element count */
  size_t list_cap;  /* allocated capacity */
};

static Value make_nil(){ Value v; v.t=V_NIL; v.num=0; v.s=NULL; v.list=NULL; v.list_len=0; v.list_cap=0; return v; }
static Value make_num(double d){ Value v; v.t=V_NUM; v.num=d; v.s=NULL; v.list=NULL; v.list_len=0; v.list_cap=0; return v; }
static Value make_str_owned(char *s){ Value v; v.t=V_STR; v.num=0; v.s=s; v.list=NULL; v.list_len=0; v.list_cap=0; return v; }
static Value make_str_dup(const char *s){ return make_str_owned(xstrdup(s?s:"")); }
static Value make_list(){ Value v; v.t=V_LIST; v.num=0; v.s=NULL; v.list=NULL; v.list_len=0; v.list_cap=0; return v; }

static void value_free(Value *v){
  if(!v) return;
  if(v->t==V_STR && v->s){ free(v->s); v->s=NULL; }
  if(v->t==V_LIST && v->list){
    for(size_t i=0; i<v->list_len; i++){
      if(v->list[i]){
        value_free(v->list[i]);
        free(v->list[i]);
      }
    }
    free(v->list);
    v->list=NULL;
  }
}

static char *value_to_new_cstr(const Value *v){
  if(!v) return xstrdup("");
  char buf[1024];
  switch(v->t){
    case V_NIL: return xstrdup("nil");
    case V_NUM: snprintf(buf,sizeof(buf),"%g", v->num); return xstrdup(buf);
    case V_STR: return xstrdup(v->s ? v->s : "");
    case V_LIST: {
      /* Format list as [elem1, elem2, ...] */
      size_t pos = 0;
      buf[pos++] = '[';
      for(size_t i = 0; i < v->list_len && pos < sizeof(buf) - 10; i++){
        if(i > 0){
          buf[pos++] = ',';
          buf[pos++] = ' ';
        }
        if(v->list[i]){
          char *elem_str = value_to_new_cstr((const Value*)v->list[i]);
          size_t elem_len = strlen(elem_str);
          if(pos + elem_len < sizeof(buf) - 2){
            strcpy(&buf[pos], elem_str);
            pos += elem_len;
          }
          free(elem_str);
        }
      }
      buf[pos++] = ']';
      buf[pos] = '\0';
      return xstrdup(buf);
    }
  }
  return xstrdup("");
}

static void list_append(Value *list, Value *item){
  if(!list || list->t!=V_LIST || !item) return;
  if(list->list_len==list->list_cap){
    size_t nc = list->list_cap ? list->list_cap*2 : 16;
    list->list = (Value**)xrealloc(list->list, nc*sizeof(Value*));
    list->list_cap = nc;
  }
  Value *copy = (Value*)xmalloc(sizeof(Value));
  *copy = *item;  /* shallow copy for now */
  list->list[list->list_len++] = copy;
}

static Value *list_index(Value *list, double idx){
  if(!list || list->t!=V_LIST) return NULL;
  size_t i = (size_t)idx;
  if(i >= list->list_len) return NULL;
  return list->list[i];
}

static size_t list_length(Value *list){
  if(!list || list->t!=V_LIST) return 0;
  return list->list_len;
}

static int value_truthy(const Value *v){
  if(!v) return 0;
  switch(v->t){
    case V_NIL: return 0;
    case V_NUM: return v->num!=0;
    case V_STR: return v->s && v->s[0]!='\0';
    case V_LIST: return v->list_len > 0;
  }
  return 0;
}

static Value value_concat(const Value *a, const Value *b){
  char *sa = value_to_new_cstr(a);
  char *sb = value_to_new_cstr(b);
  size_t la=strlen(sa), lb=strlen(sb);
  char *res=(char*)xmalloc(la+lb+1);
  memcpy(res,sa,la); memcpy(res+la,sb,lb); res[la+lb]='\0';
  free(sa); free(sb);
  return make_str_owned(res);
}
/* ======================= Environment (forward decl) ======================= */
typedef struct Value Value;  /* Forward declaration */
typedef struct { char *name; Value val; } Binding;
typedef struct { Binding *items; size_t len, cap; } Env;

/* Forward declarations for env functions */
static void env_init(Env *e);
static void env_free(Env *e);
static Value *env_lookup(Env *e, const char *name);
static void env_set(Env *e, const char *name, Value v);

/* ======================= Call Frame Management ======================= */
typedef struct {
  size_t return_pc;      /* instruction pointer to return to */
  size_t saved_stack_len; /* stack length when function was called */
  Env saved_env;         /* saved environment for this scope */
} CallFrame;

typedef struct {
  CallFrame *frames;
  size_t len, cap;
} CallStack;

static void callstack_init(CallStack *cs){ cs->frames=NULL; cs->len=cs->cap=0; }
static void callstack_push(CallStack *cs, CallFrame frame){
  if(cs->len==cs->cap){
    size_t nc = cs->cap ? cs->cap*2 : 8;
    cs->frames = (CallFrame*)xrealloc(cs->frames, nc*sizeof(CallFrame));
    cs->cap = nc;
  }
  cs->frames[cs->len++] = frame;
}
static CallFrame callstack_pop(CallStack *cs){
  if(cs->len == 0){
    fprintf(stderr,"[ERR] call stack underflow\n");
    CallFrame cf; cf.return_pc=0; env_init(&cf.saved_env); cf.saved_stack_len=0;
    return cf;
  }
  return cs->frames[--cs->len];
}
static void callstack_free(CallStack *cs){
  if(!cs) return;
  for(size_t i=0; i<cs->len; i++){
    env_free(&cs->frames[i].saved_env);
  }
  free(cs->frames);
}

/* ======================= Stack ======================= */
typedef struct { Value *data; size_t len, cap; } Stack;
static void stack_init(Stack *s){ s->data=NULL; s->len=s->cap=0; }
static void stack_push(Stack *s, Value v){ if(s->len==s->cap){ size_t nc=s->cap? s->cap*2:16; s->data=(Value*)xrealloc(s->data,nc*sizeof(Value)); s->cap=nc;} s->data[s->len++]=v; }
static Value stack_pop(Stack *s){ if(!s->len){ fprintf(stderr,"[ERR] pop from empty stack\n"); return make_nil(); } return s->data[--s->len]; }
static void stack_free(Stack *s){ for(size_t i=0;i<s->len;i++) value_free(&s->data[i]); free(s->data); }

/* ======================= Environment Functions ======================= */static void env_init(Env *e){ e->items=NULL; e->len=e->cap=0; }
static Value *env_lookup(Env *e,const char *name){ for(size_t i=0;i<e->len;i++) if(strcmp(e->items[i].name,name)==0) return &e->items[i].val; return NULL; }
static void env_set(Env *e,const char *name, Value v){ Value *slot=env_lookup(e,name); if(slot){ value_free(slot); *slot=v; return; } if(e->len==e->cap){ size_t nc=e->cap? e->cap*2:16; e->items=(Binding*)xrealloc(e->items,nc*sizeof(Binding)); e->cap=nc; } e->items[e->len].name=xstrdup(name); e->items[e->len].val=v; e->len++; }
static int env_get_copy(Env *e,const char *name, Value *out){ 
  Value *slot=env_lookup(e,name); 
  if(!slot){ *out=make_nil(); return 0; } 
  if(slot->t==V_STR){ 
    *out=make_str_dup(slot->s); 
  } else if(slot->t==V_LIST){ 
    *out=make_list();
    for(size_t i=0; i<slot->list_len; i++){
      list_append(out, slot->list[i]);
    }
  } else { 
    *out=*slot; 
  }
  return 1; 
}
static void env_free(Env *e){ if(!e) return; for(size_t i=0;i<e->len;i++){ free(e->items[i].name); value_free(&e->items[i].val);} free(e->items); }

/* ======================= Parsing (Ruby-like array literal) ======================= */
typedef enum { N_NIL, N_STRING, N_NUMBER, N_ARRAY, N_IDENT } NType; typedef struct Node Node; struct Node { NType t; char *s; double num; Node **kids; size_t len, cap; };
static Node *node_new(NType t){ Node *n=(Node*)xmalloc(sizeof(Node)); n->t=t; n->s=NULL; n->num=0; n->kids=NULL; n->len=n->cap=0; return n; }
static void node_add(Node *n, Node *child){ if(n->t!=N_ARRAY) return; if(n->len==n->cap){ size_t nc=n->cap? n->cap*2:4; n->kids=(Node**)xrealloc(n->kids,nc*sizeof(Node*)); n->cap=nc;} n->kids[n->len++]=child; }
static void node_free(Node *n){ if(!n) return; if(n->t==N_STRING || n->t==N_IDENT) free(n->s); if(n->t==N_ARRAY){ for(size_t i=0;i<n->len;i++) node_free(n->kids[i]); free(n->kids);} free(n); }

typedef enum { TK_EOF, TK_LB, TK_RB, TK_COMMA, TK_STR, TK_IDENT, TK_NUM, TK_ERR } TType;
typedef struct { TType t; char *lex; double num; } Tok;
typedef struct { const char *src; size_t pos, len; int line; } Lex;
static void lx_init(Lex *l,const char *src){ l->src=src; l->pos=0; l->len=strlen(src); l->line=1; }
static int lx_peek(Lex *l){ return (l->pos<l->len)? (unsigned char)l->src[l->pos] : -1; }
static int lx_get(Lex *l){ if(l->pos>=l->len) return -1; unsigned char c=(unsigned char)l->src[l->pos++]; if(c=='\n') l->line++; return c; }
static void tk_free(Tok *t){ if(t->lex) free(t->lex); }
static Tok lx_string(Lex *l){ Tok tk={TK_STR,NULL,0}; size_t cap=32,len=0; char *buf=(char*)xmalloc(cap); int c; while((c=lx_get(l))!=-1){ if(c=='"') break; if(c=='\\'){ int n=lx_get(l); if(n==-1) break; switch(n){ case 'n': c='\n';break; case 't': c='\t';break; case 'r': c='\r';break; case '\\': c='\\';break; case '"': c='"';break; default: c=n;break;} } if(len+1>=cap){ cap*=2; buf=(char*)xrealloc(buf,cap); } buf[len++]=(char)c; }
  buf[len]='\0'; tk.lex=buf; return tk; }
static Tok lx_ident(Lex *l,int first){ Tok tk={TK_IDENT,NULL,0}; size_t cap=16,len=0; char *buf=(char*)xmalloc(cap); buf[len++]=(char)first; while(1){ int c=lx_peek(l); if(c==-1 || !(isalnum(c)||c=='_'||c=='-')) break; c=lx_get(l); if(len+1>=cap){ cap*=2; buf=(char*)xrealloc(buf,cap);} buf[len++]=(char)c; } buf[len]='\0'; tk.lex=buf; return tk; }
static Tok lx_number(Lex *l,int first){ Tok tk={TK_NUM,NULL,0}; char buf[64]; size_t len=0; buf[len++]=(char)first; int c; while((c=lx_peek(l))!=-1 && (isdigit(c) || c=='.')){ buf[len++]=(char)lx_get(l); if(len+1>=sizeof(buf)) break; } buf[len]='\0'; tk.num = strtod(buf,NULL); return tk; }
static Tok lx_next(Lex *l){ for(;;){ int c=lx_peek(l); if(c==-1){ Tok t={TK_EOF,NULL,0}; return t;} if(isspace(c)){ lx_get(l); continue;} break;} int c=lx_get(l); if(c=='['){ Tok t={TK_LB,NULL,0}; return t;} if(c==']'){ Tok t={TK_RB,NULL,0}; return t;} if(c==','){ Tok t={TK_COMMA,NULL,0}; return t;} if(c=='"') return lx_string(l); if(isdigit(c)) return lx_number(l,c); if(isalpha(c)||c=='_') return lx_ident(l,c); Tok t={TK_ERR,NULL,0}; return t; }
static Node *parse_node(Lex *l, Tok *cur); static void advance(Lex *l, Tok *cur){ tk_free(cur); *cur=lx_next(l); }
static Node *parse_array(Lex *l, Tok *cur){ Node *arr=node_new(N_ARRAY); advance(l,cur); while(cur->t!=TK_EOF && cur->t!=TK_RB){ Node *e=parse_node(l,cur); if(!e){ node_free(arr); return NULL; } node_add(arr,e); if(cur->t==TK_COMMA){ advance(l,cur); continue;} else if(cur->t==TK_RB) break; else { node_free(arr); return NULL; } } if(cur->t==TK_RB) advance(l,cur); else { node_free(arr); return NULL; } return arr; }
static Node *parse_node(Lex *l, Tok *cur){ if(cur->t==TK_LB) return parse_array(l,cur); if(cur->t==TK_STR){ Node *n=node_new(N_STRING); n->s=xstrdup(cur->lex?cur->lex:"" ); advance(l,cur); return n;} if(cur->t==TK_IDENT){ if(cur->lex && strcmp(cur->lex,"nil")==0){ Node *n=node_new(N_NIL); advance(l,cur); return n;} Node *n=node_new(N_IDENT); n->s=xstrdup(cur->lex); advance(l,cur); return n;} if(cur->t==TK_NUM){ Node *n=node_new(N_NUMBER); n->num=cur->num; advance(l,cur); return n;} return NULL; }
static Node *parse_ir_text(const char *text){ Lex lx; lx_init(&lx,text); Tok cur=lx_next(&lx); Node *root=parse_node(&lx,&cur); tk_free(&cur); return root; }

/* ======================= Program Representation ======================= */
typedef enum { 
  OP_CONST, OP_PRINT, 
  OP_ADD, OP_SUB, OP_MULTIPLY, OP_DIVIDE, OP_MODULO,
  OP_EQ, OP_NEQ, OP_LT, OP_GT, OP_LEQ, OP_GEQ,
  OP_AND, OP_OR, OP_NOT,
  OP_LIST, OP_APPEND, OP_INDEX, OP_LENGTH,
  OP_ASSIGN, OP_LOAD, OP_LABEL, OP_JUMP, OP_JUMP_IF, OP_RETURN,
  OP_CALL, OP_CALL_INDIRECT, OP_DEF, OP_SWAP, OP_DUP, OP_POP,
  /* Event-driven paradigm opcodes */
  OP_EMIT, OP_ON, OP_ONCE, OP_OFF, OP_ATTACH, OP_DETACH,
  /* Exception handling opcodes */
  OP_TRY, OP_THROW, OP_CATCH
} Op;
typedef struct { Op op; char *a; /* label / variable / string literal / identifier */ char *b; /* auxiliary string (e.g., parameter list) */ double num; int has_num; int is_nil; } Instr;
typedef struct { Instr *code; size_t len, cap; } Program;
static void prog_init(Program *p){ p->code=NULL; p->len=p->cap=0; }
static void prog_add(Program *p, Instr in){ if(p->len==p->cap){ size_t nc=p->cap? p->cap*2:32; p->code=(Instr*)xrealloc(p->code,nc*sizeof(Instr)); p->cap=nc;} p->code[p->len++]=in; }
static void prog_free(Program *p){ if(!p) return; for(size_t i=0;i<p->len;i++){ free(p->code[i].a); } free(p->code); }

static int build_program(Node *root, Program *out){ if(!root || root->t!=N_ARRAY) return 0; prog_init(out); for(size_t i=0;i<root->len;i++){ Node *ins=root->kids[i]; if(!ins||ins->t!=N_ARRAY||ins->len==0) continue; Node *opn=ins->kids[0]; if(!opn || (opn->t!=N_STRING && opn->t!=N_IDENT)) continue; const char *op=opn->s; Instr in; memset(&in,0,sizeof(in)); if(strcmp(op,"IR_CONST")==0){ in.op=OP_CONST; in.a=NULL; in.has_num=0; in.is_nil=0; if(ins->len>=2){ Node *arg=ins->kids[1]; if(arg->t==N_STRING || arg->t==N_IDENT){ in.a=xstrdup(arg->s?arg->s:""); } else if(arg->t==N_NUMBER){ in.num=arg->num; in.has_num=1; } else if(arg->t==N_NIL){ in.is_nil=1; } } } 
else if(strcmp(op,"IR_PRINT")==0){ in.op=OP_PRINT; } 
else if(strcmp(op,"IR_ADD")==0){ in.op=OP_ADD; } 
else if(strcmp(op,"IR_SUB")==0){ in.op=OP_SUB; } 
else if(strcmp(op,"IR_MULTIPLY")==0){ in.op=OP_MULTIPLY; } 
else if(strcmp(op,"IR_DIVIDE")==0){ in.op=OP_DIVIDE; } 
else if(strcmp(op,"IR_MODULO")==0){ in.op=OP_MODULO; } 
else if(strcmp(op,"IR_EQ")==0){ in.op=OP_EQ; } 
else if(strcmp(op,"IR_NEQ")==0){ in.op=OP_NEQ; } 
else if(strcmp(op,"IR_LT")==0){ in.op=OP_LT; } 
else if(strcmp(op,"IR_GT")==0){ in.op=OP_GT; } 
else if(strcmp(op,"IR_LEQ")==0){ in.op=OP_LEQ; } 
else if(strcmp(op,"IR_GEQ")==0){ in.op=OP_GEQ; } 
else if(strcmp(op,"IR_AND")==0){ in.op=OP_AND; } 
else if(strcmp(op,"IR_OR")==0){ in.op=OP_OR; } 
else if(strcmp(op,"IR_NOT")==0){ in.op=OP_NOT; } 
else if(strcmp(op,"IR_LIST")==0){ in.op=OP_LIST; if(ins->len>=2 && ins->kids[1]->t==N_NUMBER){ in.num=ins->kids[1]->num; in.has_num=1; } } 
else if(strcmp(op,"IR_APPEND")==0){ in.op=OP_APPEND; } 
else if(strcmp(op,"IR_INDEX")==0){ in.op=OP_INDEX; } 
else if(strcmp(op,"IR_LENGTH")==0){ in.op=OP_LENGTH; } 
else if(strcmp(op,"IR_ASSIGN")==0){ in.op=OP_ASSIGN; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); } 
else if(strcmp(op,"IR_LOAD")==0){ in.op=OP_LOAD; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); } 
else if(strcmp(op,"IR_LABEL")==0){ in.op=OP_LABEL; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); } 
else if(strcmp(op,"IR_JUMP")==0){ in.op=OP_JUMP; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); } 
else if(strcmp(op,"IR_JUMP_IF")==0){ in.op=OP_JUMP_IF; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); } 
else if(strcmp(op,"IR_RETURN")==0){ in.op=OP_RETURN; } 
else if(strcmp(op,"IR_CALL")==0){ in.op=OP_CALL; if(ins->len>=2){ if(ins->kids[1]->t==N_NUMBER){ in.num=ins->kids[1]->num; in.has_num=1; } else if(ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT){ in.a=xstrdup(ins->kids[1]->s?ins->kids[1]->s:""); } } }
else if(strcmp(op,"IR_CALL_INDIRECT")==0){ in.op=OP_CALL_INDIRECT; if(ins->len>=2){ if(ins->kids[1]->t==N_NUMBER){ in.num=ins->kids[1]->num; in.has_num=1; } } }
else if(strcmp(op,"IR_DEF")==0){ in.op=OP_DEF; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); if(ins->len>=3 && ins->kids[2]->t==N_NUMBER){ in.num=(double)((int)ins->kids[2]->num); in.has_num=1; } if(ins->len>=5){ char *label_str = (ins->kids[3]->t==N_STRING||ins->kids[3]->t==N_IDENT) ? ins->kids[3]->s : ""; char *params_str = (ins->kids[4]->t==N_STRING||ins->kids[4]->t==N_IDENT) ? ins->kids[4]->s : ""; char *full_data=(char*)xmalloc(2048); snprintf(full_data, 2048, "%s|%s", label_str, params_str); in.b=full_data; } else if(ins->len>=4 && (ins->kids[3]->t==N_STRING||ins->kids[3]->t==N_IDENT)) { char *full_data=(char*)xmalloc(2048); snprintf(full_data, 2048, "%s|", ins->kids[3]->s); in.b=full_data; } }
else if(strcmp(op,"IR_SWAP")==0){ in.op=OP_SWAP; }
else if(strcmp(op,"IR_DUP")==0){ in.op=OP_DUP; }
else if(strcmp(op,"IR_POP")==0){ in.op=OP_POP; }
else if(strcmp(op,"IR_EMIT")==0){ in.op=OP_EMIT; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_ON")==0){ in.op=OP_ON; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_ONCE")==0){ in.op=OP_ONCE; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_OFF")==0){ in.op=OP_OFF; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_ATTACH")==0){ in.op=OP_ATTACH; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_DETACH")==0){ in.op=OP_DETACH; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_TRY")==0){ in.op=OP_TRY; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else if(strcmp(op,"IR_THROW")==0){ in.op=OP_THROW; }
else if(strcmp(op,"IR_CATCH")==0){ in.op=OP_CATCH; if(ins->len>=2 && (ins->kids[1]->t==N_STRING||ins->kids[1]->t==N_IDENT)) in.a=xstrdup(ins->kids[1]->s); }
else { /* skip unknown */ continue; } prog_add(out,in); } return 1; }

/* ======================= Label Table ======================= */
typedef struct { char *name; size_t pc; } Label;
typedef struct { Label *items; size_t len, cap; } LabelTable;
static void labels_init(LabelTable *t){ t->items=NULL; t->len=t->cap=0; }
static void labels_add(LabelTable *t,const char *name,size_t pc){ if(!name) return; if(t->len==t->cap){ size_t nc=t->cap? t->cap*2:16; t->items=(Label*)xrealloc(t->items,nc*sizeof(Label)); t->cap=nc;} t->items[t->len].name=xstrdup(name); t->items[t->len].pc=pc; t->len++; }
static ssize_t labels_find(LabelTable *t,const char *name){ for(size_t i=0;i<t->len;i++) if(strcmp(t->items[i].name,name)==0) return (ssize_t)t->items[i].pc; return -1; }
static void labels_free(LabelTable *t){ for(size_t i=0;i<t->len;i++) free(t->items[i].name); free(t->items); }

/* ======================= Function Definition Table ======================= */
typedef struct { char *name; char **params; size_t param_count; char *label; } FuncDef;
typedef struct { FuncDef *items; size_t len, cap; } FuncDefTable;
static void funcdef_init(FuncDefTable *t){ t->items=NULL; t->len=t->cap=0; }
static void funcdef_add(FuncDefTable *t, const char *name, char **params, size_t param_count, const char *label){
  if(!name) return;
  if(t->len==t->cap){
    size_t nc = t->cap ? t->cap*2 : 16;
    t->items = (FuncDef*)xrealloc(t->items, nc*sizeof(FuncDef));
    t->cap = nc;
  }
  t->items[t->len].name = xstrdup(name);
  t->items[t->len].params = (char**)xmalloc(param_count*sizeof(char*));
  for(size_t i=0; i<param_count; i++){
    t->items[t->len].params[i] = params ? xstrdup(params[i]) : NULL;
  }
  t->items[t->len].param_count = param_count;
  t->items[t->len].label = label ? xstrdup(label) : NULL;
  t->len++;
}
static FuncDef* funcdef_lookup(FuncDefTable *t, const char *name){
  for(size_t i=0; i<t->len; i++){
    if(strcmp(t->items[i].name, name)==0) return &t->items[i];
  }
  return NULL;
}
static void funcdef_free(FuncDefTable *t){
  for(size_t i=0; i<t->len; i++){
    free(t->items[i].name);
    for(size_t j=0; j<t->items[i].param_count; j++){
      free(t->items[i].params[j]);
    }
    free(t->items[i].params);
    free(t->items[i].label);
  }
  free(t->items);
}

/* ======================= Execution ======================= */
static void exec_program(const Program *p, FILE *out_raw){
  Stack st; stack_init(&st); 
  Env env; env_init(&env); 
  CallStack cs; callstack_init(&cs);
  LabelTable lt; labels_init(&lt);
  FuncDefTable ft; funcdef_init(&ft);
  
  /* Exception handling state */
  int exception_active = 0;
  char *exception_message = NULL;
  ssize_t exception_catch_pc = -1;  /* PC of active catch handler (-1 = none) */
  
  /* Initialize event system */
  event_init();
  event_create_scope();
  
  /* Pass 1: collect labels (their pc is their index in program) */
  for(size_t i=0;i<p->len;i++){ 
    if(p->code[i].op==OP_LABEL && p->code[i].a) 
      labels_add(&lt,p->code[i].a,i); 
  }
  
  /* Pass 2: collect function definitions (parameter names and labels) */
  for(size_t i=0;i<p->len;i++){
    if(p->code[i].op==OP_DEF && p->code[i].a){
      /* Parse parameter names from comma-separated string in code[i].b */
      /* Format of in.b: "label|param1,param2,..." */
      char *label_str = NULL;
      char *params_str = NULL;
      if(p->code[i].b && strlen(p->code[i].b) > 0){
        char *b_copy = xstrdup(p->code[i].b);
        char *pipe = strchr(b_copy, '|');
        if(pipe){
          *pipe = '\0';
          label_str = b_copy;
          params_str = pipe + 1;
        } else {
          label_str = b_copy;
          params_str = "";
        }
      }
      
      char **params = NULL;
      size_t param_count = 0;
      if(p->code[i].has_num){
        param_count = (size_t)p->code[i].num;
      }
      if(param_count > 0 && params_str && strlen(params_str) > 0){
        /* Parse comma-separated parameter list */
        char *param_str = xstrdup(params_str);
        params = (char**)xmalloc(param_count * sizeof(char*));
        char *saveptr = NULL;
        char *tok = strtok_r(param_str, ",", &saveptr);
        for(size_t j = 0; j < param_count && tok; j++){
          /* Skip whitespace */
          while(*tok == ' ' || *tok == '\t') tok++;
          size_t len = strlen(tok);
          while(len > 0 && (tok[len-1] == ' ' || tok[len-1] == '\t')) len--;
          params[j] = (char*)xmalloc(len + 1);
          strncpy(params[j], tok, len);
          params[j][len] = '\0';
          tok = strtok_r(NULL, ",", &saveptr);
        }
        free(param_str);
      }
      funcdef_add(&ft, p->code[i].a, params, param_count, label_str);
      /* Free temporary params array */
      if(params){
        for(size_t j = 0; j < param_count; j++) free(params[j]);
        free(params);
      }
      if(label_str) free(label_str);
    }
  }
  
  size_t pc = 0;
  while(pc < p->len){
    Instr in=p->code[pc]; 
    switch(in.op){
      case OP_CONST: {
        if(in.is_nil){ stack_push(&st, make_nil()); }
        else if(in.has_num){ stack_push(&st, make_num(in.num)); }
        else if(in.a){ stack_push(&st, make_str_dup(in.a)); }
        else { stack_push(&st, make_nil()); }
      } break;
      case OP_PRINT: {
        Value v=stack_pop(&st); char *s=value_to_new_cstr(&v); if(out_raw){ fputs(s,out_raw); fputc('\n',out_raw);} printf("[OUT] %s\n", s); fflush(stdout); free(s); value_free(&v); }
        break;
      case OP_ADD: {
        Value b=stack_pop(&st), a=stack_pop(&st); if(a.t==V_NIL || b.t==V_NIL){ fprintf(stderr,"[ERR] IR_ADD nil operand\n"); value_free(&a); value_free(&b); stack_push(&st, make_nil()); break; }
        if(a.t==V_STR || b.t==V_STR){ Value r=value_concat(&a,&b); value_free(&a); value_free(&b); stack_push(&st,r); }
        else if(a.t==V_NUM && b.t==V_NUM){ double r=a.num + b.num; value_free(&a); value_free(&b); stack_push(&st, make_num(r)); }
        else { fprintf(stderr,"[ERR] IR_ADD incompatible types\n"); value_free(&a); value_free(&b); stack_push(&st, make_nil()); }
      } break;
      case OP_SUB: {
        Value b=stack_pop(&st), a=stack_pop(&st); if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num - b.num)); } else { fprintf(stderr,"[ERR] IR_SUB non-numeric\n"); stack_push(&st, make_nil()); } value_free(&a); value_free(&b); }
        break;
      case OP_MULTIPLY: {
        Value b=stack_pop(&st), a=stack_pop(&st); if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num * b.num)); } else { fprintf(stderr,"[ERR] IR_MULTIPLY non-numeric\n"); stack_push(&st, make_nil()); } value_free(&a); value_free(&b); }
        break;
      case OP_DIVIDE: {
        Value b=stack_pop(&st), a=stack_pop(&st); if(a.t==V_NUM && b.t==V_NUM){ if(b.num==0){ fprintf(stderr,"[ERR] IR_DIVIDE divide by zero\n"); stack_push(&st, make_nil()); } else stack_push(&st, make_num(a.num / b.num)); } else { fprintf(stderr,"[ERR] IR_DIVIDE non-numeric\n"); stack_push(&st, make_nil()); } value_free(&a); value_free(&b); }
        break;
      case OP_MODULO: {
        Value b=stack_pop(&st), a=stack_pop(&st); if(a.t==V_NUM && b.t==V_NUM){ if(b.num==0){ fprintf(stderr,"[ERR] IR_MODULO divide by zero\n"); stack_push(&st, make_nil()); } else { long ai=(long)a.num, bi=(long)b.num; stack_push(&st, make_num(bi==0?0:(ai % bi))); } } else { fprintf(stderr,"[ERR] IR_MODULO non-numeric\n"); stack_push(&st, make_nil()); } value_free(&a); value_free(&b); }
        break;
      case OP_EQ: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        int eq=0;
        if(a.t==V_NUM && b.t==V_NUM){ eq=(a.num==b.num); }
        else if(a.t==V_STR && b.t==V_STR){ eq=(strcmp(a.s?a.s:"",b.s?b.s:"")==0); }
        else if(a.t==V_NIL && b.t==V_NIL){ eq=1; }
        else { eq=0; }
        stack_push(&st, make_num(eq?1:0));
        value_free(&a); value_free(&b);
      } break;
      case OP_NEQ: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        int eq=0;
        if(a.t==V_NUM && b.t==V_NUM){ eq=(a.num==b.num); }
        else if(a.t==V_STR && b.t==V_STR){ eq=(strcmp(a.s?a.s:"",b.s?b.s:"")==0); }
        else if(a.t==V_NIL && b.t==V_NIL){ eq=1; }
        else { eq=0; }
        stack_push(&st, make_num(eq?0:1));
        value_free(&a); value_free(&b);
      } break;
      case OP_LT: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num<b.num?1:0)); }
        else if(a.t==V_STR && b.t==V_STR){ stack_push(&st, make_num(strcmp(a.s?a.s:"",b.s?b.s:"")<0?1:0)); }
        else { fprintf(stderr,"[ERR] IR_LT incompatible types\n"); stack_push(&st, make_nil()); }
        value_free(&a); value_free(&b);
      } break;
      case OP_GT: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num>b.num?1:0)); }
        else if(a.t==V_STR && b.t==V_STR){ stack_push(&st, make_num(strcmp(a.s?a.s:"",b.s?b.s:"")>0?1:0)); }
        else { fprintf(stderr,"[ERR] IR_GT incompatible types\n"); stack_push(&st, make_nil()); }
        value_free(&a); value_free(&b);
      } break;
      case OP_LEQ: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num<=b.num?1:0)); }
        else if(a.t==V_STR && b.t==V_STR){ stack_push(&st, make_num(strcmp(a.s?a.s:"",b.s?b.s:"")<= 0?1:0)); }
        else { fprintf(stderr,"[ERR] IR_LEQ incompatible types\n"); stack_push(&st, make_nil()); }
        value_free(&a); value_free(&b);
      } break;
      case OP_GEQ: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        if(a.t==V_NUM && b.t==V_NUM){ stack_push(&st, make_num(a.num>=b.num?1:0)); }
        else if(a.t==V_STR && b.t==V_STR){ stack_push(&st, make_num(strcmp(a.s?a.s:"",b.s?b.s:"")>=0?1:0)); }
        else { fprintf(stderr,"[ERR] IR_GEQ incompatible types\n"); stack_push(&st, make_nil()); }
        value_free(&a); value_free(&b);
      } break;
      case OP_AND: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        int at=value_truthy(&a), bt=value_truthy(&b);
        stack_push(&st, make_num((at&&bt)?1:0));
        value_free(&a); value_free(&b);
      } break;
      case OP_OR: {
        Value b=stack_pop(&st), a=stack_pop(&st);
        int at=value_truthy(&a), bt=value_truthy(&b);
        stack_push(&st, make_num((at||bt)?1:0));
        value_free(&a); value_free(&b);
      } break;
      case OP_NOT: {
        Value a=stack_pop(&st);
        int at=value_truthy(&a);
        stack_push(&st, make_num(at?0:1));
        value_free(&a);
      } break;
      case OP_LIST: {
        /* Pop N items from stack and create a list with them (in reverse order) */
        int count = (int)in.num;
        Value result = make_list();
        
        Value *items = NULL;
        if(count > 0){
          items = (Value*)xmalloc(count * sizeof(Value));
          for(int i = count - 1; i >= 0 && st.len > 0; i--){
            items[i] = stack_pop(&st);
          }
          for(int i = 0; i < count; i++){
            list_append(&result, &items[i]);
          }
          free(items);
        }
        
        stack_push(&st, result);
      } break;
      case OP_APPEND: {
        Value item=stack_pop(&st), list=stack_pop(&st);
        if(list.t==V_LIST){
          list_append(&list, &item);
          stack_push(&st, list);
        } else {
          fprintf(stderr,"[ERR] IR_APPEND not a list\n");
          value_free(&list); value_free(&item);
          stack_push(&st, make_nil());
        }
      } break;
      case OP_INDEX: {
        Value idx=stack_pop(&st), list=stack_pop(&st);
        if(list.t==V_LIST && idx.t==V_NUM){
          Value *elem = list_index(&list, idx.num);
          if(elem){
            Value copy = *elem;
            stack_push(&st, copy);
          } else {
            fprintf(stderr,"[ERR] IR_INDEX out of bounds\n");
            stack_push(&st, make_nil());
          }
          value_free(&list);
        } else {
          fprintf(stderr,"[ERR] IR_INDEX invalid operands\n");
          value_free(&list); value_free(&idx);
          stack_push(&st, make_nil());
        }
      } break;
      case OP_LENGTH: {
        Value list=stack_pop(&st);
        if(list.t==V_LIST){
          size_t len = list_length(&list);
          stack_push(&st, make_num((double)len));
        } else {
          fprintf(stderr,"[ERR] IR_LENGTH not a list\n");
          stack_push(&st, make_nil());
        }
        value_free(&list);
      } break;
      case OP_ASSIGN: {
        Value v=stack_pop(&st); if(!in.a){ fprintf(stderr,"[ERR] IR_ASSIGN missing name\n"); value_free(&v); stack_push(&st, make_nil()); break; } /* store copy */ if(v.t==V_STR) env_set(&env,in.a, make_str_dup(v.s)); else env_set(&env,in.a, v); /* env owns copy for numbers directly */ if(v.t==V_STR) value_free(&v); /* original freed */ stack_push(&st, make_nil()); }
        break;
      case OP_LOAD: {
        Value v; env_get_copy(&env, in.a?in.a:"", &v); stack_push(&st, v); }
        break;
      case OP_LABEL: /* no-op */ break;
      case OP_JUMP: {
        if(!in.a){ fprintf(stderr,"[ERR] IR_JUMP missing label\n"); break; } ssize_t target=labels_find(&lt,in.a); if(target<0){ fprintf(stderr,"[ERR] IR_JUMP unknown label %s\n", in.a); break; } pc=(size_t)target; continue; }
      case OP_JUMP_IF: {
        if(!in.a){ fprintf(stderr,"[ERR] IR_JUMP_IF missing label\n"); break; } Value cond=stack_pop(&st); int tr=value_truthy(&cond); value_free(&cond); if(tr){ ssize_t target=labels_find(&lt,in.a); if(target<0){ fprintf(stderr,"[ERR] IR_JUMP_IF unknown label %s\n", in.a); } else { pc=(size_t)target; continue; } } }
        break;
      case OP_DEF: {
        /* IR_DEF just marks a function definition; skip to next non-label instruction */
        /* For now, we treat it as a no-op; function calls will jump to labels */
      } break;
      case OP_CALL: {
        /* IR_CALL function_name - look up function in FuncDefTable to get label and params */
        if(!in.a){
          fprintf(stderr,"[ERR] IR_CALL missing function name\n");
          break;
        }
        
        /* Look up function definition to get parameters and label */
        FuncDef *func = funcdef_lookup(&ft, in.a);
        if(!func){
          fprintf(stderr,"[ERR] IR_CALL unknown function %s\n", in.a);
          break;
        }
        
        int param_count = (int)func->param_count;
        
        /* Get target label from function definition */
        ssize_t target = labels_find(&lt, func->label);
        if(target < 0){
          fprintf(stderr,"[ERR] IR_CALL unknown label %s\n", func->label);
          break;
        }
        
        /* Pop arguments and bind to parameters (in reverse order) */
        Value *args = NULL;
        if(param_count > 0){
          args = (Value*)xmalloc(param_count * sizeof(Value));
          for(int i = param_count - 1; i >= 0; i--){
            if(st.len == 0){
              fprintf(stderr,"[ERR] Not enough arguments for function call\n");
              for(int j = i + 1; j < param_count; j++) value_free(&args[j]);
              free(args);
              args = NULL;
              break;
            }
            args[i] = stack_pop(&st);
          }
        }
        
        /* Push call frame with return address and saved environment */
        CallFrame frame;
        frame.return_pc = pc + 1;
        frame.saved_stack_len = st.len;
        env_init(&frame.saved_env);
        /* Copy current environment to saved environment */
        for(size_t i=0; i<env.len; i++){
          env_set(&frame.saved_env, env.items[i].name, env.items[i].val);
        }
        
        /* Bind arguments to parameters in new environment */
        if(func && param_count > 0){
          for(int i = 0; i < param_count; i++){
            if(func->params && func->params[i]){
              env_set(&env, func->params[i], args[i]);
            } else {
              value_free(&args[i]);
            }
          }
          free(args);
        }
        
        callstack_push(&cs, frame);
        pc = (size_t)target;
        continue;
      } break;
      case OP_CALL_INDIRECT: {
        /* IR_CALL_INDIRECT arg_count - function name on stack, call it dynamically */
        int arg_count = (int)in.num;
        if(st.len < 1 + arg_count){
          fprintf(stderr,"[ERR] IR_CALL_INDIRECT requires function name and %d args on stack\n", arg_count);
          break;
        }
        /* Stack layout before: [arg1 arg2 ... argN func_name]
           After pop: [arg1 arg2 ... argN] */
        Value fn_val = stack_pop(&st);
        if(fn_val.t != V_STR){
          fprintf(stderr,"[ERR] IR_CALL_INDIRECT function name must be string, got type %d\n", fn_val.t);
          value_free(&fn_val);
          break;
        }
        const char *fn_name = fn_val.s;
        
        /* Look up function definition to get parameter names and label */
        FuncDef *func = funcdef_lookup(&ft, fn_name);
        if(!func){
          fprintf(stderr,"[ERR] IR_CALL_INDIRECT unknown function '%s'\n", fn_name);
          value_free(&fn_val);
          break;
        }
        
        /* Get the label from the function definition */
        ssize_t target = labels_find(&lt, func->label);
        if(target < 0){
          fprintf(stderr,"[ERR] IR_CALL_INDIRECT label not found for function '%s' label '%s'\n", fn_name, func->label);
          value_free(&fn_val);
          break;
        }
        
        int param_count_def = (int)func->param_count;
        
        /* If arg_count doesn't match, issue warning but continue */
        if(arg_count != param_count_def){
          fprintf(stderr,"[WARN] Function '%s' expects %d args, got %d\n", fn_name, param_count_def, arg_count);
        }
        
        /* Pop arguments and bind to parameters (in reverse order) */
        Value *args = NULL;
        if(arg_count > 0){
          args = (Value*)xmalloc(arg_count * sizeof(Value));
          for(int i = arg_count - 1; i >= 0; i--){
            if(st.len == 0){
              fprintf(stderr,"[ERR] Not enough arguments for function call\n");
              for(int j = 0; j < i; j++) value_free(&args[j]);
              free(args);
              value_free(&fn_val);
              break;
            }
            args[i] = stack_pop(&st);
          }
        }
        
        /* Push call frame with return address and saved environment */
        CallFrame frame;
        frame.return_pc = pc + 1;
        frame.saved_stack_len = st.len;
        env_init(&frame.saved_env);
        /* Copy current environment to saved environment */
        for(size_t i=0; i<env.len; i++){
          env_set(&frame.saved_env, env.items[i].name, env.items[i].val);
        }
        
        /* Bind arguments to parameters in new environment */
        if(func && arg_count > 0){
          for(int i = 0; i < arg_count && i < param_count_def; i++){
            if(func->params && func->params[i]){
              env_set(&env, func->params[i], args[i]);
            } else {
              value_free(&args[i]);
            }
          }
          /* Free any extra args that weren't bound */
          for(int i = param_count_def; i < arg_count; i++){
            value_free(&args[i]);
          }
          free(args);
        }
        
        callstack_push(&cs, frame);
        value_free(&fn_val);
        pc = (size_t)target;
        continue;
      } break;
      case OP_RETURN: {
        /* Pop call frame and return to caller */
        if(cs.len == 0){
          /* No call frame - end program */
          pc = p->len;
        } else {
          CallFrame frame = callstack_pop(&cs);
          /* Save return value and make it independent of the function's environment */
          Value return_val = make_nil();
          if(st.len > 0){
            Value orig = st.data[st.len - 1];
            /* Deep copy the value so it survives environment restoration */
            if(orig.t == V_STR && orig.s){
              return_val = make_str_owned(xstrdup(orig.s));
            } else {
              return_val = orig;  /* Numbers, nil, lists are handled differently */
            }
          }
          /* Restore caller's environment and stack */
          env_free(&env);
          env = frame.saved_env;
          /* Clear stack to saved level */
          st.len = frame.saved_stack_len;
          /* Push return value back on restored stack */
          stack_push(&st, return_val);
          pc = frame.return_pc;
          continue;  // Skip the normal pc++ increment
        }
      } break;
      case OP_SWAP: {
        /* Swap top two stack values: [... a b] -> [... b a] */
        if(st.len < 2){
          fprintf(stderr,"[ERR] SWAP requires at least 2 stack values\n");
          break;
        }
        Value tmp = st.data[st.len-1];
        st.data[st.len-1] = st.data[st.len-2];
        st.data[st.len-2] = tmp;
      } break;
      case OP_DUP: {
        /* Duplicate top stack value: [... a] -> [... a a] */
        if(st.len == 0){
          fprintf(stderr,"[ERR] DUP on empty stack\n");
          break;
        }
        Value top = st.data[st.len-1];
        Value copy;
        if(top.t == V_STR){
          copy = make_str_dup(top.s);
        } else if(top.t == V_LIST){
          copy = make_list();
          for(size_t i=0; i<top.list_len; i++){
            list_append(&copy, top.list[i]);
          }
        } else {
          copy = top;
        }
        stack_push(&st, copy);
      } break;
      case OP_POP: {
        /* Pop and discard top stack value */
        if(st.len > 0){
          value_free(&st.data[--st.len]);
        }
      } break;
      /* ======== Event-Driven Paradigm Opcodes ======== */
      case OP_EMIT: {
        /* IR_EMIT event_name - pops 1 (payload), pushes handler count
           Stack: [... payload] -> [... handler_count]
        */
        Value payload = stack_pop(&st);
        char *event_name = in.a ? in.a : "unknown";
        
        /* Create event object from payload */
        EventType *evt = event_create(event_name);
        if(evt){
          /* Store payload in event (simplified: convert to string for storage) */
          char *payload_str = value_to_new_cstr(&payload);
          /* Note: In full implementation, would store Value* in event */
          
          /* Emit and get handler count */
          int handler_count = event_emit(event_name, payload_str);
          stack_push(&st, make_num((double)handler_count));
          
          free(payload_str);
          free(evt);
        } else {
          fprintf(stderr,"[ERR] IR_EMIT failed to create event\n");
          stack_push(&st, make_num(0));
        }
        value_free(&payload);
      } break;
      
      case OP_ON: {
        /* IR_ON event_name handler_body - pops 1 (handler function), pushes handler ID
           Stack: [... handler_func] -> [... handler_id]
           Note: Simplified; full version stores callable handler
        */
        Value handler = stack_pop(&st);
        char *event_name = in.a ? in.a : "unknown";
        
        /* Register handler (simplified: just create subscription) */
        int handler_id = event_on(event_name, NULL);
        stack_push(&st, make_num((double)handler_id));
        
        value_free(&handler);
      } break;
      
      case OP_ONCE: {
        /* IR_ONCE event_name handler_body - pops 1 (handler), pushes handler ID
           Stack: [... handler] -> [... handler_id]
           Handler fires exactly once then auto-unsubscribes
        */
        Value handler = stack_pop(&st);
        char *event_name = in.a ? in.a : "unknown";
        
        /* Register one-time handler */
        int handler_id = event_once(event_name, NULL);
        stack_push(&st, make_num((double)handler_id));
        
        value_free(&handler);
      } break;
      
      case OP_OFF: {
        /* IR_OFF handler_id - pops 1 (handler ID), pushes success bool
           Stack: [... handler_id] -> [... success]
        */
        Value handler_id_val = stack_pop(&st);
        if(handler_id_val.t == V_NUM){
          int handler_id = (int)handler_id_val.num;
          int success = event_off(handler_id);
          stack_push(&st, make_num(success ? 1 : 0));
        } else {
          fprintf(stderr,"[ERR] IR_OFF invalid handler ID type\n");
          stack_push(&st, make_num(0));
        }
        value_free(&handler_id_val);
      } break;
      
      case OP_ATTACH: {
        /* IR_ATTACH target_var event_handlers - pops 2 (target, handlers), pushes success
           Stack: [... target, handlers] -> [... success]
           Attaches event handler to variable/function/object
        */
        Value handlers = stack_pop(&st);
        Value target = stack_pop(&st);
        
        if(target.t == V_STR && in.a){
          /* Simplified: track attachment in environment */
          char attach_key[512];
          snprintf(attach_key, sizeof(attach_key), "__attached_%s", target.s);
          env_set(&env, attach_key, make_num(1));
          stack_push(&st, make_num(1));
        } else {
          fprintf(stderr,"[ERR] IR_ATTACH invalid target\n");
          stack_push(&st, make_num(0));
        }
        
        value_free(&target);
        value_free(&handlers);
      } break;
      
      case OP_DETACH: {
        /* IR_DETACH target_var event_id - pops 2 (target, event_id), pushes success
           Stack: [... target, event_id] -> [... success]
           Removes event handler from target
        */
        Value event_id = stack_pop(&st);
        Value target = stack_pop(&st);
        
        if(target.t == V_STR && in.a){
          /* Simplified: remove attachment from environment */
          char attach_key[512];
          snprintf(attach_key, sizeof(attach_key), "__attached_%s", target.s);
          
          Value *slot = env_lookup(&env, attach_key);
          if(slot){
            stack_push(&st, make_num(1));
          } else {
            fprintf(stderr,"[ERR] IR_DETACH not attached\n");
            stack_push(&st, make_num(0));
          }
        } else {
          fprintf(stderr,"[ERR] IR_DETACH invalid target\n");
          stack_push(&st, make_num(0));
        }
        
        value_free(&target);
        value_free(&event_id);
      } break;
      
      case OP_TRY: {
        /* IR_TRY catch_label - sets up try/catch handler
           Pushes catch label as the active exception handler
           If throw occurs, will jump to this label
        */
        if(!in.a){
          fprintf(stderr,"[ERR] IR_TRY missing catch label\n");
          break;
        }
        ssize_t catch_label_pc = labels_find(&lt, in.a);
        if(catch_label_pc < 0){
          fprintf(stderr,"[ERR] IR_TRY unknown catch label %s\n", in.a);
          break;
        }
        exception_catch_pc = catch_label_pc;
      } break;
      
      case OP_THROW: {
        /* IR_THROW - throws exception with value on stack as error message
           Stack: [... value] -> []
           Pops value, stores as exception message, jumps to catch handler
        */
        Value error_val = stack_pop(&st);
        char *error_str = value_to_new_cstr(&error_val);
        
        /* Store error message */
        if(exception_message) free(exception_message);
        exception_message = xstrdup(error_str);
        free(error_str);
        value_free(&error_val);
        
        /* Mark exception active and jump to catch handler if available */
        exception_active = 1;
        if(exception_catch_pc >= 0){
          pc = (size_t)exception_catch_pc;
          continue;  /* Skip normal pc increment */
        } else {
          /* No catch handler - print error and stop execution */
          fprintf(stderr,"[ERR] Uncaught exception: %s\n", exception_message);
          pc = p->len;  /* Jump to end */
        }
      } break;
      
      case OP_CATCH: {
        /* IR_CATCH variable_name - assigns caught exception to variable
           Stores the exception message in the given variable and clears exception state
           Stack: [] -> []
        */
        if(!in.a){
          fprintf(stderr,"[ERR] IR_CATCH missing variable name\n");
          break;
        }
        if(exception_active && exception_message){
          /* Store exception message in variable */
          env_set(&env, in.a, make_str_dup(exception_message));
          exception_active = 0;
          if(exception_message){ 
            free(exception_message); 
            exception_message = NULL;
          }
        }
      } break;
    }
    pc++;  // Increment pc for normal instruction execution
  }
  
  /* Clean up event system */
  event_clear_all();
  
  /* Clean up exception state */
  if(exception_message) free(exception_message);
  
  labels_free(&lt); funcdef_free(&ft); env_free(&env); callstack_free(&cs); stack_free(&st); }

/* ======================= File Loading ======================= */
static char *slurp(const char *path){ FILE *f=fopen(path,"rb"); if(!f) return NULL; if(fseek(f,0,SEEK_END)!=0){ fclose(f); return NULL;} long n=ftell(f); if(n<0){ fclose(f); return NULL;} if(fseek(f,0,SEEK_SET)!=0){ fclose(f); return NULL;} char *buf=(char*)xmalloc((size_t)n+1); size_t rd=fread(buf,1,(size_t)n,f); if(rd!=(size_t)n){ free(buf); fclose(f); return NULL;} buf[n]='\0'; fclose(f); return buf; }

/* ======================= Main ======================= */
static int build_program(Node *root, Program *out);
int main(int argc,char **argv){ const char *ir_path=NULL; const char *out_path=NULL; for(int i=1;i<argc;i++){ if(strcmp(argv[i],"--o")==0){ if(i+1<argc) out_path=argv[++i]; else { fprintf(stderr,"Usage: %s <program.ir> [--o output] \n", argv[0]); return 2; } } else if(!ir_path) ir_path=argv[i]; }
  if(!ir_path){ fprintf(stderr,"Usage: %s <program.ir> [--o output]\n", argv[0]); return 1; }
  fprintf(stderr,"[INFO] Loading IR %s\n", ir_path);
  char *text=slurp(ir_path); if(!text){ fprintf(stderr,"[ERR] Cannot read %s: %s\n", ir_path, strerror(errno)); return 1; }
  Node *root=parse_ir_text(text); free(text); if(!root){ fprintf(stderr,"[ERR] Parse failed\n"); return 1; }
  Program prog; if(!build_program(root,&prog)){ fprintf(stderr,"[ERR] Build failed\n"); node_free(root); return 1; }
  node_free(root);
  FILE *out_raw=NULL; if(out_path){ out_raw=fopen(out_path,"w"); if(!out_raw){ fprintf(stderr,"[ERR] Cannot open %s: %s\n", out_path, strerror(errno)); prog_free(&prog); return 1; } }
  exec_program(&prog,out_raw); if(out_raw){ fflush(out_raw); fclose(out_raw);} prog_free(&prog); return 0; }
/* END minimal */

/* Runtime cleaned: legacy fragments removed. */
