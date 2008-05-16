use 5.008;
use ExtUtils::MakeMaker;

system("cd libmcode; chmod 0755 make.sh; ./make.sh");

WriteMakefile(
    'NAME'		=> 'Mcode',
    'VERSION_FROM'	=> 'Mcode.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Mcode.pm', # retrieve abstract from module
       AUTHOR     => 'A. U. Thor <shuhei@localdomain>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'MYEXTLIB' => 'libmcode/libmcode.a',
    'clean' => {
        FILES  => 'libmcode/libmcode.a'
    },
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '-I. -Ilibmcode', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
