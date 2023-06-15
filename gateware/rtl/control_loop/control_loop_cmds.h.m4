/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
m4_changequote(`⟨', `⟩')m4_dnl
m4_changecom(⟨/*⟩, ⟨*/⟩)m4_dnl
m4_define(generate_macro, ⟨m4_dnl
#define $1 $2 m4_dnl
m4_define(M4_$1, $2)m4_dnl
⟩)m4_dnl
m4_include(control_loop_cmds.m4)
