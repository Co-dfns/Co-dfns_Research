#include <stdio.h>
#include <stdlib.h>
#include <time.h>
typedef int I;typedef void V;typedef size_t B;typedef char C;typedef double D;
typedef struct cn{B i;I t;B c;struct cn*k[];}*CN;typedef clock_t CT;
#define R return
#define P printf
#define EQ(s1,s2) (!strcmp((s1),(s2)))
#define DO(n,x) for(I i=0;i<(n);i++){x;}
#define TIME(x) {CT s=clock();x;CT e=clock();\
 P("Took %0.3f secs.\n",(D)(e-s)/CLOCKS_PER_SEC);}
B id=0;
V pi(I i){P("%d",i);}V nl(V){P("\n");}
V pp(B d,B w,C*s){P("Benchmarking %s algorithm (Depth: %d, Width: %d)...\n",s,d,w);}
V help(V){P("benchmark <cpu|gpu> <print|quiet> [<depth> <width>]\n");exit(1);}
V merr(V){P("Out of Memory.\n");exit(2);}

CN mcn(I i,I t,B c){CN n=malloc(sizeof(struct cn)+c*sizeof(CN));if(!n)merr();
 n->i=i;n->t=t;n->c=c;R n;}
CN mct(B d,B w){CN n;
 if(d){n=mcn(id++,0,w);DO(w,n->k[i]=mct(d-1,w));}else n=mcn(id++,1,0);R n;}
V fct(CN t){if(t->c){DO(t->c,fct(t->k[i]));free(t);}else free(t);}
V pct(CN t,I d){DO(d,P(" "));P("%d %d\n",t->t,t->i);DO(t->c,pct(t->k[i],d+1));}
B fltc1(CN t){B x=0;if(!t->t){x++;DO(t->c,x+=fltc1(t->k[i]));};R x;}
B fltc2(CN r,CN t,B c){
 if(!t->t){r->k[c++]=t;
  DO(t->c,{CN k=t->k[i];t->k[i]=k->t?k:mcn(k->i,1,0);c=fltc2(r,k,c);})}
 R c;}
CN fltc(CN t){CN r=mcn(id++,0,fltc1(t));fltc2(r,t,0);R r;}
V cpu(B d,B w,I p){pp(d,w,"CPU");CN t=mct(d,w);if(p){P("Before\n");pct(t,1);}
 TIME(t=fltc(t));if(p){P("After\n");pct(t,1);}fct(t);}

V gpu(B d,B w,I p){pp(d,w,"GPU");}

I main(I c,C*v[]){B d=3,w=2;I p=1;if(c!=3&&c!=5)help();
 if(c==5){d=atoi(v[3]);w=atoi(v[4]);}
 if(EQ(v[2],"print"))p=1;else if(EQ(v[2],"quiet"))p=0;else help();
 if(EQ(v[1],"cpu"))cpu(d,w,p);else if(EQ(v[1],"gpu"))gpu(d,w,p);else help();
 R 0;}
