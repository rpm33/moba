use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

system("cd libkcode; chmod 0755 make.sh; ./make.sh");

WriteMakefile(
    'NAME'		=> 'Kcode',
    'VERSION_FROM'	=> 'Kcode.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Kcode.pm', # retrieve abstract from module
       AUTHOR     => 'A. U. Thor <shuhei@localdomain>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'MYEXTLIB' => 'libkcode/libkcode.a',
    'clean' => {
        FILES  => 'libkcode/libkcode.a'
    },
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
