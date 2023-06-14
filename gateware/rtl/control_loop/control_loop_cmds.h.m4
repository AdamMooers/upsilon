m4_changequote(`⟨', `⟩')m4_dnl
m4_changecom(⟨/*⟩, ⟨*/⟩)m4_dnl
m4_define(generate_macro, ⟨m4_dnl
#define $1 $2 m4_dnl
m4_define(M4_$1, $2)m4_dnl
⟩)m4_dnl
m4_include(control_loop_cmds.m4)
