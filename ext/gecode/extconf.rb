#
# GECODE needs to be built with 
# ./configure --with-architectures=i386,x86_64
# to work properly here.
require 'mkmf'

$LIBS << " -lstdc++"

have_library('gecodesearch')
have_library('gecodeint')
have_library('gecodekernel')
have_library('gecodesupport')

create_makefile('dep_selector_to_gecode_interface')