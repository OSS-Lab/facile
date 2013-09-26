#!/usr/bin/perl -w
############################################################################
## File:     facile.pl
## Synopsys: Convert chemical kinetic equations into simulatable objects.
##           Simulation targets are Matlab and XPP for numerical simulation,
##           Mathematica and Maple for symbolic analysis, and EasyStoch for
##           stochastic simulations.  Other tools are supported via
##           SBML output.
## Authors:  J. Ollivier, F. Siso, P. Swain, U. Skalska
## Reference:
##   Siso-Nadal F., Ollivier JF, Swain PS, Facile: a command-line network
##   compiler for systems biology, BMC Systems Biology 2007, 1:36.
#############################################################################
## Detailed Description:
## ---------------------
##
###############################################################################
## QUICK HELP
###############################################################################
#-
#- NAME:      facile - network compiler for systems biology.
#- SYNOPSIS:  facile.pl [options] input_file
#- ARGUMENTS: input_file or '-' for STDIN
#- OPTIONS:   (short form and long form)
#-
#- General options
#-
#- (-H) --extended_help     Extended help screen
#- (-h) --help              Quick help screen
#-
#- (-V) --verbose           More verbose output
#- (-q) --quiet             Quiet mode, suppresses some warnings and messages
#- (-E) --echo              Echo output to STDOUT
#- (-o) --prefix (prefix)   Specifies prefix for output files
#-
#- Output type
#-
#- (-M) --mathematica       Mathematica input file (default)
#- (-L) --maple             Maple input file
#- (-m) --matlab            Matlab driver script and functions (optionally with -r)
#- (-O) --octave            Octave driver script and functions (optionally with -r)
#- (-y) --python            Python/SciPy driver script and functions (optionally with -r)
#-      --cpp               C++ driver script and functions (optionally with -r)
#- (-x) --xpp               XPP input file (optionally with -r)
#- (-s) --easystoch         EasyStoch simulation input file and Matlab conversion
#-                          script for EasyStoch output.
#- (-a) --auto              AUTO output, implies (-r) (optionally with -A)
#- (-S) --sbml              Export to SBML file.
#-
#- Output modifiers
#-
#- (-p) --split             Split output into top-lvl script and sub-scripts with
#-                          containing rates and ICs (Matlab, Octave, SciPy only).
#-      --extern            In driver script, don't set external parameters and/or ICs
#-                          to a value in equation file (Matlab/Octave only). This allows
#-                          those parameters and species designated in the CONFIG section
#-                          to be set outside the driver.
#-      --jacobian          Generate a jacobian function.
#-      --factor            Factor out common variables from terms in dydt and jacobian function
#-                          to make them more efficient.
#-                          CAUTION: compare results w/ and w/o to ensure correctness of
#-                          refactoring result.
#- (-r) --reduce            Reduce equations using moiety and constraint identification algorithm
#- (-R) --matrix            Same as -r except that stoichiometry matrix is output to a file.
#-
#- AUTO related
#-
#- (-A) --ss_file (file)    Reads initial solution from file
#-
#- Simulation parameters
#-
#- (-t) --t_final    (time)      Final integration time 'tf' (Matlab; default NO_TIME_SPECIFIED)
#- (-v) --t_sampling (vector)    Sampling time list for state vector (Matlab; defaults '[t0 tf]')
#- (-k) --t_tick     (tick)      Progress messages tick interval (Matlab/SciPy)
#- (-l) --solver     (solver)    ODE solver
#-                               For Matlab, overrides matlab_ode_solver configuration variable,
#-                               which defaults to "ode23s".
#-                               For Octave, overrides octave_ode_solver configuration variable,
#-                               which defaults to "lsode".
#- (-n) --solver_options option,value,...
#-                               ODE solver options provided as comma-separated option-value pairs.
#-                               For Matlab, overrides matlab_ode_options configuration variable.
#-                               For Octave, overrides octave_ode_options configuration variable.
#-                               For SciPy, overrides scipy_ode_options configuration variable.
#-                               For C++, overrides cpp_ode_options configuration variable.
#- (-e) --ode_event_times (event_list) Comma-separated list of times where system parameters
#-                               change discontinuously (Matlab)
#- (-C) --volume (volume)        Specify compartment volume (in L)
#- (-P) --plot                   Plot probes (matlab only).
#-
#- Miscellaneous
#-
#-      -- run                   Run the selected target simulator.
#-
#- If the --prefix option is not used, facile uses the name of input file, with the
#- extension (e.g. .txt or .eqn) removed, as the output file prefix.
#-
#- EXAMPLES:
#-
#- facile.pl --run -P -m <input file>   # generates Matlab scripts with commented-in plot commands, runs Matlab
#- facile.pl -s <input file>            # generates input file for EasyStoch stochastic simulator
#- facile.pl <input file>               # defaults to Mathematica output
#- facile.pl -E <input file>            # echo Mathematica eqns to screen
#- echo 'A+B->C; f=1' | facile.pl -E -  # grab equation from stdin and display
#-
##############################################################################
## EXTENDED HELP
##############################################################################
#+ INPUT FILE
#+
#+    The input file is divided into sections and is assumed to begin with
#+    an EQN section.  The other sections include the INIT section where
#+    initial values are specified.  Sections are delimited with the new
#+    section name on its own line (see examples below).
#+
#+    The EQN section contains reaction equations which are written with associated
#+    rate constants or velocities. Duplicate reactions are accepted and
#+    cause extra terms in the rate equations.  Use 'null' for a
#+    source or a sink.  The reaction kinetics follow the mass-action law
#+    if written with '<->', '->', or '<-' (in which case you supply a rate
#+    constant), or they interpreted as rate equations if written with
#+    '<=>', '=>', or '<=' (in which case one supplies the reaction velocity).
#+
#+    The EQN section may also contain stand-alone node and variable definitions.
#+    Variables may be constants or quoted expressions.
#+
#+    When an expression is given for the rate constant of a reaction in mass-action
#+    law form, the treatment is different depending on the simulation
#+    target.  If Matlab output is required, the rate expression is included verbatim
#+    in the appropriate differential equation.  Hence any valid Matlab expression
#+    can be supplied, including functions of time and/or of concentrations.
#+
#+    For EasyStoch output, the rate expression in quotes is evaluated at t=0
#+    and at each time supplied through the easystoch_sample_times configuration
#+    variable.  EasyStoch uses the evaluated values to build a piecewise-constant
#+    or piecewise-linear approximation for the expression. Currently,
#+    the function square() can be included in the expression, and also the
#+    value 'pi'.
#+
#+    Comments must start with '//' or '#'.
#+    The reactions can also be written without the +'s.  
#+
#+    Here is an example EQN section:
#+
#+ EQN:    # not needed if first section
#+ A + B <-> C;   f1=0.7; b1=0.2         # binary reversible reaction
#+ C   C -> D;    f2=2                   # the '+' is optional
#+ null  -> X;    f3=1.5                 # creation (source)
#+ null <-> C;    f4=f3; b2=0.3          # creation and destruction 
#+ C     -> null; d1= 0.2                # destruction (sink) 
#+ null  -> X;    f3                     # duplicate reaction; X created at rate of 2*f3=3.0M/s
#+ X     -> null; f6="square(2*pi*t)+1"  # time-varying sink, T=1 s, A=2Hz
#+ mRNA => mRNA + P;   ftr="mRNA/(1+mRNA)" # Example of simple rate-law to model transcription
#+
#+    The INIT section specifies the end of reaction equations and
#+    the start of initial values.  Example:
#+
#+ INIT
#+ A=4;
#+ B=2;
#+ C=1;
#+ Y=5;
#+ Z=5;
#+
##############################################################################

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use 5.008_000;            # require perl version 5.8.0 or higher
use Class::Std 0.0.8;     # require Class::Std version 0.0.8 or higher

use File::Copy;

#######################################################################################
# Modules used
#######################################################################################
use English;

# J.Ollivier: assume package is present in same directory as script;
use FindBin qw($Bin);
use lib "$Bin/modules";

use Globals;

# Report version
$VERSION = "0.53a";
print <<HEADER;
Facile version $VERSION
Copyright (c) 2003-2013, Ollivier, Siso, Swain et al.
HEADER

exit if (grep(/--version/, @ARGV) == 1);

use Model;  # main class for reading, processing and exporting model

#######################################################################################
# Facile variables
#######################################################################################
my $input_file_name;
my $output_file_directory;
my $output_file_prefix;
my $mathematica_output;         # flag; default is Mathematica output
my $maple_output;
my $matlab_output;		# flag
my $octave_output;		# flag
my $scipy_output;               # flag
my $cpp_output;
my $xpp_output;                 # flag
my $easystoch_output;		# flag
my $auto_output;                # flag
my $sbml_output;                # flag
my $steady_state_file;
my $reduce_flag;
my $reduce_and_output_flag;

my $split_flag;
my $extern_flag;
my $factor_flag;
my $jacobian_flag;

my $echo_stdout = 0;            # if set, will echo main output file to STDOUT

my ($extended_help, $help);

#######################################################################################
# Command line and switch processing
#######################################################################################

use Getopt::Long;    # Standard package for options processing
Getopt::Long::Configure("bundling");

my $opt_ref = {};

my $get_opt_result = GetOptions (
    "extended_help|H" => \$extended_help,
    "help|h" => \$help,
    "quick_help" => \$help,
    "verbose|V" => \$verbose,
    "quiet|q" => \$quiet,
    "echo|E" => \$echo_stdout,
    "prefix|o=s" => \$output_file_prefix,

    "mathematica|M" => \$mathematica_output,
    "maple|L" => \$maple_output,
    "matlab|m" => \$matlab_output,
    "octave|O" => \$octave_output,
    "scipy|y" => \$scipy_output,
    "cpp" => \$cpp_output,
    "xpp|x" => \$xpp_output,
    "easystoch|s" => \$easystoch_output,
    "auto|a" => \$auto_output,
    "sbml|S" => \$sbml_output,

    "split|p" => \$split_flag,
    "extern" => \$extern_flag,
    "factor" => \$factor_flag,
    "jacobian" => \$jacobian_flag,

    "reduce|r" => \$reduce_flag,
    "matrix|R" => \$reduce_and_output_flag,
    "ss_file|A" => \$steady_state_file,

    "t_final|t=f" => \$opt_ref->{tf},
    "t_sampling|v=s" => \$opt_ref->{tv},
    "t_tick|k=f" => \$opt_ref->{tk},
    "solver|l=s" => \$opt_ref->{solver},
    "solver_options|n=s" => \$opt_ref->{solver_options},
    "ode_event_times|e=s" => \$opt_ref->{ode_event_times},
    "volume|C=f" => \$opt_ref->{compartment_volume},

    "plot|P" => \$opt_ref->{plot_flag},

    "run" => \$opt_ref->{run_flag},
);

# option --auto implies option --reduce
if ($auto_output) {
    $reduce_flag = 1;
}

$matlab_output = $matlab_output ? 1 : 0;
$octave_output = $octave_output ? 1 : 0;
$scipy_output = $scipy_output ? 1 : 0;
$cpp_output = $cpp_output ? 1 : 0;
$easystoch_output = $easystoch_output ? 1 : 0;
$xpp_output = $xpp_output ? 1 : 0;
$mathematica_output = $mathematica_output ? 1 : 0;
$maple_output = $maple_output ? 1 : 0;
$sbml_output = $sbml_output ? 1 : 0;
$auto_output = $auto_output ? 1 : 0;
$reduce_flag = $reduce_flag ? 1 : 0;
$reduce_and_output_flag = $reduce_and_output_flag ? 1 : 0;

my $num_output_flags = ($matlab_output + $octave_output + $scipy_output + $cpp_output +
			$easystoch_output + $xpp_output +
			$mathematica_output + $maple_output +
			$sbml_output + $auto_output);

if ($num_output_flags > 1) {
  print "ERROR: you can't specify more than one output type\n";
  exit(1);
}

# If user has not specified anything to do, default is to generate Mathematica file
# and output its contents to STDOUT.
if (($num_output_flags + $reduce_and_output_flag) == 0) {
    $mathematica_output = 1;
    $echo_stdout = 1;
}

#######################################################################################
# Model instantiation
#######################################################################################
my $model_ref = Model->new();
my $config_ref = $model_ref->get_config_ref();
$config_ref->{opt_ref} = $opt_ref;

$config_ref->{output_type} = "matlab" if ($matlab_output);
$config_ref->{output_type} = "octave" if ($octave_output);
$config_ref->{output_type} = "scipy" if ($scipy_output);
$config_ref->{output_type} = "cpp" if ($cpp_output);
$config_ref->{output_type} = "easystoch" if ($easystoch_output);
$config_ref->{output_type} = "xpp" if ($xpp_output);
$config_ref->{output_type} = "mathematica" if ($mathematica_output);
$config_ref->{output_type} = "maple" if ($maple_output);
$config_ref->{output_type} = "sbml" if ($sbml_output);
$config_ref->{output_type} = "auto" if ($auto_output);

# copy args into model config
if (defined $opt_ref->{solver}) {
  $config_ref->{matlab_ode_solver} = $opt_ref->{solver} if ($matlab_output);
  $config_ref->{octave_ode_solver} = $opt_ref->{solver} if ($octave_output);
  $config_ref->{scipy_ode_solver} = $opt_ref->{solver} if ($scipy_output);
  $config_ref->{cpp_ode_solver} = $opt_ref->{solver} if ($cpp_output);
}
if (defined $opt_ref->{solver} && defined $opt_ref->{solver_options}) {
  # solver options given as comma-separated pair list
  my @solver_options = split(",",$opt_ref->{solver_options});
  if (@solver_options % 2 != 0) {
    print "ERROR: solver options must be given as option,value pairs on command line\n";
    exit(1);
  }
  $opt_ref->{solver_options} = {@solver_options};
  $config_ref->{matlab_solver_options} = {@solver_options} if ($matlab_output);
  $config_ref->{octave_solver_options}{$opt_ref->{solver}} = {@solver_options} if ($octave_output);
  $config_ref->{scipy_solver_options}{$opt_ref->{solver}} = {@solver_options} if ($scipy_output);
  $config_ref->{cpp_solver_options}{$opt_ref->{solver}} = {@solver_options} if ($cpp_output);
}

foreach my $key (keys %$opt_ref) {
  next if ($key eq "solver");
  next if ($key eq "solver_options");
  $config_ref->{$key} = $opt_ref->{$key} if defined $opt_ref->{$key};
}

if ($octave_output && $matlab_output) {
    print "ERROR: can't output both Octave and Matlab scripts\n";
    exit(1);
}

if ($extended_help || $help) {
  open (SLURP, "< $PROGRAM_NAME") || return undef;
  my @help = <SLURP>;
  close SLURP;

  # print the quick help screen
  #    my  $help_tag = "^#" . "-";
  foreach (@help) {
    my $line = $_;
    if ($line =~ /^#-(.*)/) {
      print "$1\n";
    }
  }

  if ($extended_help) {
    # print the extended help screen
    #    $help_tag = "^#" . "+";
    foreach (@help) {
      my $line = $_;
      if ($line =~ /^#\+(.*)/) {
	print "$1\n";
      }
    }
    exit(0);
  }
}

# get input file argument
if (@ARGV) {
    $input_file_name = pop(@ARGV);	# input file is first (and only) argument
} else {
    print " No input file specified; exiting...\n";
    exit(1);
}

if ($input_file_name ne "-" && ! -e $input_file_name) {
    die " File \"$input_file_name\" does not exist, exiting...\n";
}

if (!defined $output_file_prefix) {
    if ($input_file_name ne "-") {
	# strip off extension from input file name if exists,
	# to use that as prefix for output files
	if ($input_file_name =~ /(.*)(\.\S+)$/) {
	    $output_file_prefix = $1;
	} else {
	    $output_file_prefix = $input_file_name;
	}
    } else {
	# input file is STDIN
	$output_file_prefix = "stdin";
    }
}

# check if output file is in another directory
if ($output_file_prefix =~ /(.*)\/(.*)/) {
    $output_file_directory = $1;
    $output_file_prefix = $2;
} else {
    $output_file_directory = ".";
}

#######################################################################################
# Preprocess input file
#######################################################################################
$model_ref->read_and_preprocess_input_file($input_file_name);

#######################################################################################
# Parse the line buffer
#######################################################################################
$model_ref->parse_eqn_section();
$model_ref->parse_init_section();
$model_ref->parse_moiety_section() if ($reduce_flag || $reduce_and_output_flag);
# the following needs to happen after MOIETY parsing
# in case moiety total designated as bifurc param
$model_ref->parse_bifurc_param_section() if ($auto_output);
$model_ref->parse_promoter_section();

$model_ref->parse_config_section($opt_ref);

$model_ref->parse_probe_section();

#######################################################################################
# Compute moieties if required
#######################################################################################
if ($reduce_and_output_flag) {
  my $stoi_file=$output_file_prefix."_stoi.txt";
  $model_ref->stoichMatrix($stoi_file);
} elsif ($reduce_flag) {   # n.b. option -a implies -r (see above)
  $model_ref->stoichMatrix(undef);
}

#######################################################################################
# Generate output files as required.
#######################################################################################
# write out Mathematica format equations
if ($mathematica_output) {
    my $mathematica_file_name = "$output_file_directory/$output_file_prefix.ma";
    my $mathematica_file_contents = $model_ref->export_mathematica_file();
    print "Note: input file for Mathematica is $mathematica_file_name\n" if (!$quiet);

    if ($echo_stdout) {
	print "$mathematica_file_contents";
    }

    open(FILE, "> $mathematica_file_name") or die "Can't open $mathematica_file_name"; # print to file
    print FILE "$mathematica_file_contents";
    close FILE;
}

# write out Maple format equations
if ($maple_output) {
    my $maple_file_name = "$output_file_directory/$output_file_prefix.maple";
    my $maple_file_contents = $model_ref->export_maple_file(
	$config_ref->{compartment_volume}
       );
    print "Note: input file for Maple is $maple_file_name\n" if (!$quiet);

    if ($echo_stdout) {
	print "$maple_file_contents";
    }

    open(FILE, "> $maple_file_name") or die "Can't open $maple_file_name"; # print to file
    print FILE "$maple_file_contents";
    close FILE;
}

# write out EasyStoch input file
if ($easystoch_output) {
    my $stochastic_equation_file_name = "$output_file_directory/${output_file_prefix}.seqn";
    my $stochastic_equation_file_contents = $model_ref->export_easystoch_input_file();

    my $convert_script_file_name = "$output_file_directory/${output_file_prefix}_convert.m";
    my $convert_script_file_contents = $model_ref->export_easystoch_converter_file();
    print "Note: input file for stochastic sims is $stochastic_equation_file_name\n" if (!$quiet);
    print "Note: Matlab conversion script for stochastic sims is $convert_script_file_name\n" if (!$quiet);

    if ($echo_stdout) {
	print "$stochastic_equation_file_contents";
    }

    open(FILE, "> $stochastic_equation_file_name") or die "Can't open $stochastic_equation_file_name"; # print to file
    print FILE "$stochastic_equation_file_contents";
    close FILE;

    open(FILE, "> $convert_script_file_name") or die "Can't open $convert_script_file_name"; # print to file
    print FILE "$convert_script_file_contents";
    close FILE;
}

# write out Matlab or Octave scripts
if ($matlab_output || $octave_output) {
    my $driver_file_name = "$output_file_directory/${output_file_prefix}Driver.m";
    my $ode_file_name = "$output_file_directory/${output_file_prefix}_odes.m";
    my $jac_file_name = "$output_file_directory/${output_file_prefix}_jac.m";
    my $node_index_mapper_file_name = "$output_file_directory/${output_file_prefix}_s.m";
    my $rate_index_mapper_file_name = "$output_file_directory/${output_file_prefix}_r.m";
    my $ode_event_file_name = "$output_file_directory/${output_file_prefix}_ode_event.m";
    my $IC_file_name = "$output_file_directory/${output_file_prefix}_ivals.m";
    my $rates_file_name = "$output_file_directory/${output_file_prefix}_rates.m";

    my ($driver_file_contents,
	$ode_file_contents,
	$jac_file_contents,
	$node_index_mapper_file_contents,
	$rate_index_mapper_file_contents,
	$IC_file_contents,
	$rates_file_contents) =
       $model_ref->export_matlab_files(
	   output_file_prefix => $output_file_prefix,
	   split_flag => $split_flag,
	   extern_flag => $extern_flag,
	   jacobian_flag => $jacobian_flag,
	   factor_flag => $factor_flag,
	   octave_output => $octave_output,
	  );

    my $input_file_list = "$driver_file_name, $ode_file_name";
    $input_file_list .= ", $jac_file_name" if $jacobian_flag;
    $input_file_list .= ", $IC_file_name, $rates_file_name" if $split_flag;
    $input_file_list .= ", $node_index_mapper_file_name, $rate_index_mapper_file_name";
    if ($matlab_output && defined $config_ref->{ode_event_times}) {
      copy("$FindBin::Bin/ode_event.m", "$ode_event_file_name");
      $input_file_list .= ", $ode_event_file_name";
    }
    print "Note: input files for ".($octave_output ? "Octave" : "Matlab")." sims are $input_file_list\n" if (!$quiet);

    if ($echo_stdout) {
	print "$driver_file_contents$ode_file_contents$jac_file_contents";
    }

    open(FILE, ">$driver_file_name") or die "Can't open $driver_file_name";
    print FILE "$driver_file_contents";
    close FILE;	

    open(FILE, ">$ode_file_name") or die "Can't open $ode_file_name"; 
    print FILE "$ode_file_contents";
    close FILE;

    if ($jacobian_flag) {
	open(FILE, ">$jac_file_name") or die "Can't open $jac_file_name"; 
	print FILE "$jac_file_contents";
	close FILE;
    }

    if ($split_flag) {
	open(FILE, ">$IC_file_name") or die "Can't open $IC_file_name"; 
	print FILE "$IC_file_contents";
	close FILE;
	open(FILE, ">$rates_file_name") or die "Can't open $rates_file_name"; 
	print FILE "$rates_file_contents";
	close FILE;
    }

    open(FILE, ">$node_index_mapper_file_name") or die "Can't open $node_index_mapper_file_name";
    print FILE "$node_index_mapper_file_contents";
    close FILE;

    open(FILE, ">$rate_index_mapper_file_name") or die "Can't open $rate_index_mapper_file_name";
    print FILE "$rate_index_mapper_file_contents";
    close FILE;
}

# write out SciPy scripts
if ($scipy_output && $config_ref->{scipy_ode_solver} ne "cvode") {
    my $driver_file_name = "$output_file_directory/${output_file_prefix}Driver.py";
    my $ode_file_name = "$output_file_directory/${output_file_prefix}_odes.py";
    my $jac_file_name = "$output_file_directory/${output_file_prefix}_jac.py";
    my $node_index_mapper_file_name = "$output_file_directory/${output_file_prefix}_s.py";
    my $rate_index_mapper_file_name = "$output_file_directory/${output_file_prefix}_r.py";
    my $ode_event_file_name = "$output_file_directory/${output_file_prefix}_ode_event.py";
    my $IC_file_name = "$output_file_directory/${output_file_prefix}_ivals.py";
    my $rates_file_name = "$output_file_directory/${output_file_prefix}_rates.py";

    my ($driver_file_contents,
	$ode_file_contents,
	$jac_file_contents,
	$node_index_mapper_file_contents,
	$rate_index_mapper_file_contents,
	$IC_file_contents,
	$rates_file_contents) =
       $model_ref->export_scipy_files(
	   output_file_prefix => $output_file_prefix,
	   split_flag => $split_flag,
	   extern_flag => $extern_flag,
	   jacobian_flag => $jacobian_flag,
	   factor_flag => $factor_flag,
	  );
    my $input_file_list = "$driver_file_name, $ode_file_name";
    $input_file_list .= ", $jac_file_name" if $jacobian_flag;
    $input_file_list .= ", $IC_file_name, $rates_file_name" if $split_flag;
    $input_file_list .= ", $node_index_mapper_file_name, $rate_index_mapper_file_name";
#    if (defined $config_ref->{ode_event_times}) {
#      copy("$FindBin::Bin/ode_event.m", "$ode_event_file_name");
#      $input_file_list .= ", $ode_event_file_name";
#    } else {
    print "Note: input files for SciPy sims are $input_file_list\n" if (!$quiet);
#    }

    if ($echo_stdout) {
	print "$driver_file_contents$ode_file_contents";
    }

    open(FILE, ">$driver_file_name") or die "Can't open $driver_file_name";
    print FILE "$driver_file_contents";
    close FILE;	

    open(FILE, ">$ode_file_name") or die "Can't open $ode_file_name"; 
    print FILE "$ode_file_contents";
    close FILE;

    if ($jacobian_flag) {
	open(FILE, ">$jac_file_name") or die "Can't open $jac_file_name"; 
	print FILE "$jac_file_contents";
	close FILE;
    }

    if ($split_flag) {
	open(FILE, ">$IC_file_name") or die "Can't open $IC_file_name"; 
	print FILE "$IC_file_contents";
	close FILE;
	open(FILE, ">$rates_file_name") or die "Can't open $rates_file_name"; 
	print FILE "$rates_file_contents";
	close FILE;
    }

    open(FILE, ">$node_index_mapper_file_name") or die "Can't open $node_index_mapper_file_name";
    print FILE "$node_index_mapper_file_contents";
    close FILE;

    open(FILE, ">$rate_index_mapper_file_name") or die "Can't open $rate_index_mapper_file_name";
    print FILE "$rate_index_mapper_file_contents";
    close FILE;

}

# write out and compile Sundials/CVODE C++ code, wrappers
if (($cpp_output && $config_ref->{cpp_ode_solver} eq "cvode") ||
    ($octave_output && $config_ref->{octave_ode_solver} eq "cvode")){
    my $driver_file_name = "$output_file_directory/${output_file_prefix}Driver.cpp";
    my $cvode_header_file_name = "$output_file_directory/${output_file_prefix}CVODE.h";
    my $cvode_file_name = "$output_file_directory/${output_file_prefix}CVODE.cpp";
    my $octwrap_file_name = "$output_file_directory/${output_file_prefix}CVODEOctWrapper.cpp";
    my ($driver_file_contents, $cvode_header_file_contents, $cvode_file_contents, $octwrap_file_contents) =
       $model_ref->export_cvode_files(
	   output_file_prefix => $output_file_prefix,
	   split_flag => $split_flag,
	   extern_flag => $extern_flag,
	   jacobian_flag => $jacobian_flag,
	   factor_flag => $factor_flag,
	  );

    open(FILE, ">$driver_file_name") or die "Can't open $driver_file_name";
    print FILE "$driver_file_contents";
    close FILE;	

    open(FILE, ">$cvode_header_file_name") or die "Can't open $cvode_header_file_name";
    print FILE "$cvode_header_file_contents";
    close FILE;	

    open(FILE, ">$cvode_file_name") or die "Can't open $cvode_file_name";
    print FILE "$cvode_file_contents";
    close FILE;	

    print "Note: C++ files for CVODE sims are $driver_file_name, $cvode_header_file_name, $cvode_file_name\n" if (!$quiet);
    print "Compiling shared lib and C++ driver using the commands:\n";
    $config_ref->{cvode_executable_file} = "$output_file_directory/${output_file_prefix}CVODE";

#g++ -shared -o libpoissonCVODE.so ./poissonCVODE.cpp
#g++ -L/usr/lib -L. -Wl,-rpath=. -o poissonCVODE poissonDriver.cpp -lpoissonCVODE -lsundials_cvode -lsundials_nvecserial -lm -llapack -lblas
#mkoctfile -L. -lpoissonCVODE '-Wl,-rpath=.' -lsundials_cvode -lsundials_nvecserial -lm -llapack -lblas poissonCVODEOctWrapper.cpp

    $config_ref->{cvode_compile_command} = <<CMD;
g++ -O3 -shared -o lib${output_file_prefix}CVODE.so ./${output_file_prefix}CVODE.cpp
g++ -O3 -L/usr/lib -L. -Wl,-rpath=. -o $config_ref->{cvode_executable_file} $driver_file_name \\
    -l${output_file_prefix}CVODE -lsundials_cvode -lsundials_nvecserial -lm -llapack -lblas
CMD
    print $config_ref->{cvode_compile_command}."\n";
    system("rm -f lib${output_file_prefix}CVODE.so $config_ref->{cvode_executable_file} ");
    system($config_ref->{cvode_compile_command});

    if ($octave_output) {
      print "Note: Octave wrapper file for CVODE C++ code is $octwrap_file_name\n" if (!$quiet);
      open(FILE, ">$octwrap_file_name") or die "Can't open $octwrap_file_name";
      print FILE "$octwrap_file_contents";
      close FILE;	

      print "Compiling Octave oct-file wrapper using command:\n";
      $config_ref->{mkoctfile_command} = "mkoctfile -L. -l${output_file_prefix}CVODE '-Wl,-rpath=.' -lsundials_cvode -lsundials_nvecserial -lm -llapack -lblas ${output_file_prefix}CVODEOctWrapper.cpp";
      print $config_ref->{mkoctfile_command}."\n";
      system("rm -f ${output_file_prefix}CVODEOctWrapper.oct");
      system($config_ref->{mkoctfile_command});
    }

    if ($echo_stdout) {
	print "$cvode_file_contents";
    }
}

###write out XPP input file
if ($xpp_output) {
    my $xpp_file_name = "$output_file_directory/${output_file_prefix}.ode";
    my $xpp_file_contents;
    $xpp_file_contents = $model_ref->export_XPP_file();

    print "Note: input file for XPP sims is $xpp_file_name\n" if (!$quiet);

    if ($echo_stdout) {
	print "$xpp_file_contents";
    }

    open(FILE, "> $xpp_file_name") or die "Can't open $xpp_file_name";
    print FILE "$xpp_file_contents";
    close FILE;
  }

### write out AUTO format stuff
if ($auto_output) {
    my $AUTO_C_file_name = "$output_file_directory/${output_file_prefix}.c"; # .c file
    my $AUTO_C_file_contents = $model_ref->export_AUTO_file(
	$steady_state_file,
       );

    print "Note: input file for AUTO is $AUTO_C_file_name\n";

    if ($echo_stdout) {
	print "$AUTO_C_file_contents";
    }

    open(FILE, "> $AUTO_C_file_name") or die "Can't open $AUTO_C_file_name";
    print FILE "$AUTO_C_file_contents";
    close FILE;
}

###write out SBML
if ($sbml_output) {
    my $sbml_file_name = "$output_file_directory/${output_file_prefix}.sbml";
    my $sbml_file_contents = $model_ref->export_sbml($output_file_prefix);

    print "Note: SBML file is $sbml_file_name\n" if (!$quiet);

    if ($echo_stdout) {
	print "$sbml_file_contents";
    }

    open(FILE, "> $sbml_file_name") or die "Can't open $sbml_file_name";
    print FILE "$sbml_file_contents";
    close FILE;
}

if ($opt_ref->{run_flag}) {
    if ($cpp_output && $config_ref->{cpp_ode_solver} eq "cvode") {
      system($config_ref->{cvode_executable_file});
    }
    if ($scipy_output && $config_ref->{scipy_ode_solver} ne "cvode") {
	my $FACILE_PYTHON_EXE = defined $ENV{FACILE_PYTHON_PATH} ? "$ENV{FACILE_PYTHON_PATH}/python" : "python";
	print "Running Python/SciPy...\n";
	system("cd $output_file_directory; $FACILE_PYTHON_EXE -i ${output_file_prefix}Driver.py");
    }
    if ($octave_output && $config_ref->{octave_ode_solver}) {
	print "Running Octave...\n";
	system("cd $output_file_directory; octave --persist ${output_file_prefix}Driver.m");
    }
    if ($matlab_output) {
	print "Running Matlab...\n";
	system("cd $output_file_directory; matlab -nodesktop -nosplash -r ${output_file_prefix}Driver");
    }
}

print "Facile done.\n\n"

