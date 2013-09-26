###############################################################################
# File:     SciPy.pm
#
# Copyright (C) 2005-2012 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export model to a Python script for integration using SciPy.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package SciPy;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use Matlab.pm
@EXPORT = qw(
	     export_scipy_files
	    );

use Globals;
use Expression;

#######################################################################################
# INSTANCE METHODS
#######################################################################################

# Prints python script for ODE integration using SciPy
sub export_scipy_files {
    my $self = shift;

    my %args = (
	output_file_prefix => undef,
	split_flag => 0,
	extern_flag => 0,
	jacobian_flag => 0,
	factor_flag => 0,
	@_,
       );

    my $output_file_prefix = $args{output_file_prefix};
    my $split_flag = $args{split_flag};
    my $extern_flag = $args{extern_flag};
    my $jacobian_flag = $args{jacobian_flag};
    my $factor_flag = $args{factor_flag};

    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $driver_file_contents;			# ode driver (main function)
    my %ode_file_contents;			# ode definition
    my $jac_file_contents;                      # jacobian definition
    my $species_index_mapper_file_contents;     # species index mapping function
    my $rate_index_mapper_file_contents;        # rate index mapping function
    my $IC_file_contents = "";                  # species initial conditions file
    my $rates_file_contents = "";                   # rate constants file

    # get configuration vars affecting output
    my $config_ref = $self->get_config_ref();
    my $compartment_volume = $config_ref->{compartment_volume};
    my $tf = $config_ref->{tf};
    my $tv = $config_ref->{tv};
    my $tk = $config_ref->{tk};
    my $solver = $config_ref->{scipy_ode_solver};
    my $solver_options = $config_ref->{scipy_solver_options}{$solver};
    my $ode_event_times = $config_ref->{ode_event_times};
    my $SS_timescale = $config_ref->{SS_timescale};
    my $SS_RelTol = $config_ref->{SS_RelTol};
    my $SS_AbsTol = $config_ref->{SS_AbsTol};
    my $plot_flag = $config_ref->{plot_flag};

    # construct lists of nodes and variables to print out
    my @free_nodes = $node_list_ref->get_ordered_free_node_list();
    my @free_node_names = map ($_->get_name(), @free_nodes);
    my @variables = $variable_list_ref->get_list();

    my @constant_rate_params = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
				      $_->get_is_expression_flag() == 0), @variables);
    my @constant_rate_param_names = map($_->get_name(), @constant_rate_params);

    my @constant_rate_expressions = grep (($_->get_type() =~ /^(rate)|(other)$/ &&
					   $_->get_is_expression_flag() == 1 &&
					   $_->get_is_dynamic_flag() == 0), @variables);
    my @constant_rate_expression_names = map($_->get_name(), @constant_rate_expressions);

    my @dynamic_rate_expressions = grep ($_->get_type() =~ /^(rate)|(other)$/ &&
				 $_->get_is_dynamic_flag() == 1, @variables);

    my @ode_rate_constants = (@constant_rate_params,@constant_rate_expressions);
    my @ode_rate_constants_names = map($_->get_name(), @ode_rate_constants);

    my @moiety_totals = grep ($_->get_type() eq "moiety_total", @variables);
    my @constrained_node_expressions = grep ($_->get_type() eq "constrained_node_expression",
					     @variables);

    #********************************************************#
    # generate ode driver                                    #
    #********************************************************#	
    # driver setup
    $driver_file_contents .= <<HEADER;
#!/usr/bin/python
#
# File generated by Facile version $VERSION
#

import time
tic = time.time()

import numpy as np

from scipy.integrate import ode
from scipy.integrate import odeint
from matplotlib.pylab import *

import ${output_file_prefix}_odes
from ${output_file_prefix}_odes import *
HEADER

    if ($jacobian_flag) {
	$driver_file_contents .= "import ${output_file_prefix}_jac\n";
	$driver_file_contents .= "from ${output_file_prefix}_jac import *\n\n";
    }

    # print initial values
    $IC_file_contents .= "# initial values (free nodes only)\n";
    foreach my $node_ref (@free_nodes) {
	my $node_name = $node_ref->get_name();
	my $initial_value = $node_ref->get_initial_value_in_molarity($compartment_volume);
	my $extern = $extern_flag && $node_ref->get_is_extern_flag() ? "#" : ""; # comment-out IC if external
	$IC_file_contents .= "$extern$node_name = $initial_value\n";
    }

    # vectorize initial values, printing species in lines of length $linelength
    my $length = @free_node_names;
    my $linelength = 8;
    my $no_lines = int($length/$linelength);
    $IC_file_contents .= "ivalues = [";
    if ($no_lines == 0) {
	$IC_file_contents .= join(",",@free_node_names);
    } else {
	my ($start, $end);
	for (my $j = 0; $j < $no_lines; $j++) {
	    $start= $j * $linelength;
	    $end= $start + $linelength - 1;
	    $IC_file_contents .= join(",",@free_node_names[$start...$end]).",\n\t";
	}
	$start = $end + 1;
	$end = $length - 1;
	$IC_file_contents .= join(",",@free_node_names[$start...$end]);
    }
    $IC_file_contents .= "]\n\n";

    # if splitting, source the IC file, else incorporate directly in driver
    if (!$split_flag) {
	$driver_file_contents .= $IC_file_contents;
    } else {
	$driver_file_contents .= "# initial values (free nodes only)\n";
	$driver_file_contents .= "import ${output_file_prefix}_ivals\n\n";
    }

    # rate constants
    $rates_file_contents .= "# rate constants and constant expressions\n";
    foreach my $variable_ref (@constant_rate_params) {
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $extern = $extern_flag && $variable_ref->get_is_extern_flag() ? "%" : ""; # comment-out param if external
	if ($variable_value !~ /[eE]|[.]/) {
	    # integer value, need to write it out as float
	    $variable_value .= ".0";
	}
	$rates_file_contents .= sprintf("$extern%-16s = $variable_value\n","$variable_name");
    }
    foreach my $variable_ref (@constant_rate_expressions) {
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	my $extern = $extern_flag && $variable_ref->get_is_extern_flag() ? "%" : ""; # comment-out param if external
	$rates_file_contents .= sprintf("$extern%-16s = $variable_value\n","$variable_name");
    }
    $rates_file_contents .= "ode_rate_constants = [";
    $length = @ode_rate_constants;
    $linelength = 12;
    $no_lines = int($length/$linelength);
    if ($no_lines == 0) {
	$rates_file_contents .= join(",",@ode_rate_constants_names);
    } else {
	my ($start, $end);
	for (my $j = 0; $j < $no_lines; $j++) {
	    $start= $j * $linelength;
	    $end= $start + $linelength - 1;
	    $rates_file_contents .= join(",",@ode_rate_constants_names[$start...$end]).",\n\t";
	}
	$start= $end+1;
	$end= $length-1;
	$rates_file_contents .= join(",",@ode_rate_constants_names[$start...$end]);
    }
    $rates_file_contents .= "]\n\n";

    # if splitting, source the IC file, else incorporate directly in driver
    if (!$split_flag) {
	$driver_file_contents .= $rates_file_contents;
    } else {
	$driver_file_contents .= "# rate constants\n";
	$driver_file_contents .= "import ${output_file_prefix}_rates\n\n";
    }

    # setup and call ODE function
    my $linspace;
    my $num_points;
    if ($tv =~ /\[\s*(\S+)\s+(\S+)\]/) {
	# t_vector of form [t0 tf]
	$num_points = "100";
	$linspace = "linspace(t0,$2,num_points+1)"
    } elsif ($tv =~ /\[\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\]/) {
	$num_points = "($3 - $1)/$2";
	$linspace = "linspace(t0,$3,num_points+1)"
    }

    $driver_file_contents .= <<SCIPY;
# time interval
t0= 0
tf= $tf
num_points = int($num_points)
t = $linspace
#print t

# call solver routine

SCIPY

    if ($solver eq "odeint") {
	# option #1 -- odeint

	if (!defined $ode_event_times) {
	    $ode_event_times = "tcrit=None";
	} else {
	    $ode_event_times = join(",",split(/\s+/,$ode_event_times));
	    $ode_event_times = "tcrit=($ode_event_times)";
	}

	if ($jacobian_flag) {
	  $driver_file_contents .= "\ny = odeint(dydt_${output_file_prefix},ivalues,t,args=(ode_rate_constants,),Dfun=jac_${output_file_prefix},$ode_event_times)\n\n";
	} else {
	  $driver_file_contents .= "\ny = odeint(dydt_${output_file_prefix},ivalues,t,args=(ode_rate_constants,),Dfun=None,$ode_event_times)\n\n";
	}

    } elsif ($solver =~ /^ode\.(\S+)/) {
	# option #2 -- OO style w/ bdf

	my $integrator = $1;

	my @solver_options = map {"$_=$solver_options->{$_}"} (keys %$solver_options);
	if ($jacobian_flag) {
	    push @solver_options, "with_jacobian=True";
	}
	my $solver_options_string = join(",",@solver_options);

	if (!defined $ode_event_times) {
	    $ode_event_times = "-1";
	} else {
	    $ode_event_times = join(",",split(/\s+/,$ode_event_times));
	    $ode_event_times .= ",-1";
	}

	my $ode_init;
	if ($jacobian_flag) {
	    $ode_init = "ode(dydt_${output_file_prefix},jac_${output_file_prefix})";
	} else {
	    $ode_init = "ode(dydt_${output_file_prefix})";
	}

	$driver_file_contents .= <<SCIPY;
ode_event_times = [$ode_event_times]
event_index = 0
next_ode_event_time = ode_event_times[event_index]

r = $ode_init
r.set_integrator('$integrator', $solver_options_string)

r.set_initial_value(ivalues,t0)
r.set_f_params(ode_rate_constants)
r.set_jac_params(ode_rate_constants)

y=[];
y.append(ivalues)

for i in range(0,num_points):
#    print 'integrating to t=',t[i+1]
    r.integrate(t[i+1])
    y.append(r.y)        #makes a list of 1d arrays
    if (t[i+1] == next_ode_event_time):
        print 'ode event at t=',t[i+1]
        event_index = event_index + 1
        next_ode_event_time = ode_event_times[event_index]
#        r = $ode_init
#        r.set_integrator('$integrator', $solver_options_string)
#        r.set_initial_value(y[i+1],t[i+1])
#        r.set_f_params(ode_rate_constants)
#        r.set_jac_params(ode_rate_constants)


y = array(y)        #convert from list to 2d array

#print t
#print y

SCIPY

    }

    $driver_file_contents .= "# map free node state vector names\n";
    for (my $j = 0; $j < @free_node_names; $j++) {
	$driver_file_contents .= "$free_node_names[$j] = y[:,$j]; ";
	if (($j % 10) == 9) {
	    $driver_file_contents .= "\n";
	}
    }
    $driver_file_contents .= "\n\n";

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $driver_file_contents .= "# moiety totals\n" if (@moiety_totals);
    foreach my $variable_ref (@moiety_totals) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$driver_file_contents .= "$variable_name = $variable_value;\n";
    }
    $driver_file_contents .= "\n";

    # contrained node expressions, e.g. E = C - E_moiety
    $driver_file_contents .= "# compute constrained nodes\n" if (@constrained_node_expressions);
    foreach my $variable_ref (@constrained_node_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$driver_file_contents .= "$variable_name = $variable_value;\n";
    }
    $driver_file_contents .= "\n";

    # plot free nodes
    my $fig_num = 100;
    my $plot_format = "'.k-'";
    # comment out plot commands if user didn't specify -P on command line
    my $plot_prefix = ($plot_flag ? "" : "#");
    my @probed_nodes = grep ($_->get_probe_flag(), @free_nodes);
    $driver_file_contents .= "# plot free nodes\n" if (@probed_nodes);
    for (my $j = 0; $j < @probed_nodes; $j++) {
	my $node_ref = $probed_nodes[$j];
	my $node_name = $node_ref->get_name();
	my $title = length($node_name) <= 40 ? $node_name : substr($node_name, 0, 40).".....(truncated)";
	$title =~ s/_/\\_/g;  # escape underscore for Matlab (otherwise interprets as subscript)
	# plot command uses convert routine
	$driver_file_contents .= "${plot_prefix}figure(".$fig_num++.");plot(t, $node_name, $plot_format);grid(\'on\');xlabel(\'Time\');ylabel(\'Concentration\');title(\'$title\')\n";
    }

    # plot expressions
    my @probe_expressions = grep ($_->get_probe_flag(), @variables);
    $driver_file_contents .= "# plot expressions\n" if (@probe_expressions);
    for (my $j = 0; $j < @probe_expressions; $j++) {
	my $probe_ref = $probe_expressions[$j];
	my $probe_name = $probe_ref->get_name();
	my $probe_value = $probe_ref->get_value();
	# plot command uses convert routine
	my $title = length($probe_value) <= 40 ? $probe_value : substr($probe_value, 0, 40).".....(truncated)";
	$title = "$probe_name=$title";
	$title =~ s/_/\\_/g;  # escape underscore for Matlab (otherwise interprets as subscript)
	$driver_file_contents .= "$probe_name = $probe_value;\n";
	$driver_file_contents .= "${plot_prefix}figure(".$fig_num++.");plot(t, $probe_name, $plot_format);grid(\'on\');xlabel(\'Time\');ylabel(\'Concentration\');title(\'$title\')\n";
    }
    $driver_file_contents .= "\n";

    $driver_file_contents .= "ode_tot_cputime = ${output_file_prefix}_odes.ode_tot_cputime\n";
    $driver_file_contents .= "ode_num_calls = ${output_file_prefix}_odes.ode_num_calls\n";

    $driver_file_contents .= "print 'ODE STATS: num ode calls={0}, tot time={1}, avg time={2:.3f}ms'.format(ode_num_calls, ode_tot_cputime, ode_tot_cputime/ode_num_calls*1000.0)\n";
    if ($jacobian_flag) {
	$driver_file_contents .= "jac_tot_cputime = ${output_file_prefix}_jac.jac_tot_cputime\n";
	$driver_file_contents .= "jac_num_calls = ${output_file_prefix}_jac.jac_num_calls\n";
	$driver_file_contents .= "if jac_num_calls != 0:\n";
	$driver_file_contents .= "    print 'JAC STATS: num jac calls={0}, tot time={1}, avg time={2:.3f}ms'.format(jac_num_calls, jac_tot_cputime, jac_tot_cputime/jac_num_calls*1000.0)\n";
	$driver_file_contents .= "else:\n";
	$driver_file_contents .= "    print 'JAC STATS: num jac calls={0}, tot time={1}, avg time={2:.3f}ms'.format(jac_num_calls, jac_tot_cputime, 0.0)\n";
    }
    $driver_file_contents .= "\n";


    $driver_file_contents .= "show(block=False)\n\n";

    # please don't remove this 'done' message
    $driver_file_contents .= "# issue done message for calling/wrapper scripts\n";
    $driver_file_contents .= "toc = time.time()\n";
    $driver_file_contents .= "print 'Facile driver script done (elapsed time {0:.3f}s)'.format(toc-tic);\n\n";

    #********************************************************#
    # generate dydt function                                 #
    #********************************************************#
    # ODE function
    # default

    my $t_y_arg = $solver eq "odeint" ? "y, t" : "t, y";

    $ode_file_contents{header} .= <<SCIPY;
#
# File generated by Facile version $VERSION
#

import numpy as np
from scipy import pi
from scipy.signal.waveforms import square

import time
ode_tot_cputime = 0.0
ode_num_calls = 0

def dydt_${output_file_prefix}($t_y_arg, ode_rate_constants):
    
SCIPY

    $ode_file_contents{header} .= "    global ode_tot_cputime\n";
    $ode_file_contents{header} .= "    global ode_num_calls\n";
    $ode_file_contents{header} .= "    ode_start_time = time.clock()\n";
    $ode_file_contents{header} .= "    ode_num_calls = ode_num_calls + 1\n";
    $ode_file_contents{all} .= $ode_file_contents{header};

    # Clock tick
    # (incomplete implementation)
    my $tick_line = ($tk == -1) ? "" : "print 'ode: sim time is t =',t\n\n";
    $ode_file_contents{tick} .= "    $tick_line";
    $ode_file_contents{all} .= $ode_file_contents{tick};
	
    # map state vector to free nodes
    $ode_file_contents{node_map} .= "    # state vector to node mapping\n" if (@constant_rate_params);
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $node_ref = $free_nodes[$j];
	my $node_name = $node_ref->get_name();
	$ode_file_contents{node_map} .= "    $node_name = y[$j]\n";
    }	
    $ode_file_contents{node_map} .= "\n";
    $ode_file_contents{all} .= $ode_file_contents{node_map};

    # ordinary rate constants (e.g. f1=1) and constant rate expressions (e.g. f2=2*f1)
    $ode_file_contents{consts} .= "    # constants and constant expressions\n" if (@constant_rate_params);
    for (my $i = 0; $i < @ode_rate_constants; $i++) {
	my $variable_ref = $ode_rate_constants[$i];
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$ode_file_contents{consts} .= "    $variable_name = ode_rate_constants[$i]\n";
    }
    $ode_file_contents{consts} .= "\n";
    $ode_file_contents{all} .= $ode_file_contents{consts};

    # moiety totals, e.g. E_moiety = 123 (mol/L)
    $ode_file_contents{moiety} .= "    # moiety totals\n" if (@moiety_totals);
    foreach my $variable_ref (@moiety_totals) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$ode_file_contents{moiety} .= "    $variable_name = $variable_value\n";
    }
    $ode_file_contents{moiety} .= "\n";
    $ode_file_contents{all} .= $ode_file_contents{moiety};

    # contrained node expressions, e.g. E = C - E_moiety
    $ode_file_contents{cnodes} .= "    # dependent species\n" if (@constrained_node_expressions);
    foreach my $variable_ref (@constrained_node_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$ode_file_contents{cnodes} .= "$variable_name = $variable_value;\n";
    }
    $ode_file_contents{cnodes} .= "\n";
    $ode_file_contents{all} .= $ode_file_contents{cnodes};

    # rate expressions
    $ode_file_contents{dynrates} .= "    # dynamic rate expressions\n" if (@dynamic_rate_expressions);
    foreach my $variable_ref (@dynamic_rate_expressions) {
	my $variable_index = $variable_ref->get_index();
	my $variable_name = $variable_ref->get_name();
	my $variable_value = $variable_ref->get_value();
	$ode_file_contents{dynrates} .= "    $variable_name = $variable_value\n";
    }
    $ode_file_contents{dynrates} .= "\n";
    $ode_file_contents{all} .= $ode_file_contents{dynrates};

    # print out differential equations for the free nodes
    $ode_file_contents{dydt} .= "    # differential equations for independent species\n";
    $ode_file_contents{dydt} .= "    n = len(y)\n";
    $ode_file_contents{dydt} .= "    dydt = np.zeros(n)\n";

    my @ode_rhs = ();
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $node_ref = $free_nodes[$j];
	my $node_name = $node_ref->get_name();

	my $ode_rhs = "";

	my @create_reactions = $node_ref->get_create_reactions();
	my @destroy_reactions = $node_ref->get_destroy_reactions();

	# print positive terms
	foreach my $reaction_ref (@create_reactions) {
	    my $velocity = $reaction_ref->get_velocity();
	    $ode_rhs .= "+ $velocity ";
	}
	# print negative terms
	foreach my $reaction_ref (@destroy_reactions) {
	    my $velocity = $reaction_ref->get_velocity();
	    $ode_rhs .= "- $velocity ";
	}

	push @ode_rhs, $ode_rhs;

	if ($factor_flag) {
	    $ode_rhs = Expression->new({value=>$ode_rhs})->factor_expression();
 	}

	if ($ode_rhs ne "") {
	    $ode_file_contents{dydt} .= "    dydt[$j]= $ode_rhs;\n";
	} else {
	    $ode_file_contents{dydt} .= "    dydt[$j]= 0;\n";
	}
    }
    $ode_file_contents{all} .= $ode_file_contents{dydt};

    $ode_file_contents{footer} .= "    ode_end_time = time.clock()\n";
    $ode_file_contents{footer} .= "    ode_tot_cputime = ode_tot_cputime + (ode_end_time - ode_start_time);\n";
    $ode_file_contents{footer} .= "\n    return dydt\n";
    $ode_file_contents{all} .= $ode_file_contents{footer};

    #********************************************************#
    # generate jacobian function                             #
    #********************************************************#
    $jac_file_contents .= <<SCIPY;
#
# File generated by Facile version $VERSION
#

import numpy as np
from scipy import pi
from scipy.signal.waveforms import square

import time
jac_tot_cputime = 0.0
jac_num_calls = 0

def jac_${output_file_prefix}($t_y_arg, ode_rate_constants):
    
SCIPY

    $jac_file_contents .= "    global jac_tot_cputime\n";
    $jac_file_contents .= "    global jac_num_calls\n";
    $jac_file_contents .= "    jac_start_time = time.clock()\n";
    $jac_file_contents .= "    jac_num_calls = jac_num_calls + 1\n";

    # Clock tick
    if ($tk != -1) {
	my $tick_line = ($tk == -1) ? "" : "print 'jac: sim time is t =',t\n\n";
	$jac_file_contents .= "    $tick_line";
    }

    # other sections are the same as the ode file
    $jac_file_contents .= $ode_file_contents{node_map};
    $jac_file_contents .= $ode_file_contents{consts};
    $jac_file_contents .= $ode_file_contents{moiety};
    $jac_file_contents .= $ode_file_contents{cnodes};
    $jac_file_contents .= $ode_file_contents{dynrates};

    # now generate equations for jacobian
    $jac_file_contents .= "    # jacobian equations for independent species\n";
    $jac_file_contents .= "    n = len(y)\n";
    $jac_file_contents .= "    J = np.zeros([n,n]);\n";
    for (my $j = 0; $j < @free_nodes; $j++) {
	my $ode_rhs_ex_ref = Expression->new({value=>$ode_rhs[$j]});
	for (my $k = 0; $k < @free_nodes; $k++) {
	    my $dvar = $free_nodes[$k]->get_name();
	    my $jac_rhs = $ode_rhs_ex_ref->differentiate_expression($dvar);
	    if ($jac_rhs ne "0") {
		if ($factor_flag) {
		    $jac_rhs = Expression->new({value=>$jac_rhs})->factor_expression();
		}
		$jac_file_contents .= "    J[$j,$k] = $jac_rhs;\n";
	    }
	}
    }

    # timings
    $jac_file_contents .= "    jac_end_time = time.clock()\n";
    $jac_file_contents .= "    jac_tot_cputime = jac_tot_cputime + (jac_end_time - jac_start_time);\n";

    $jac_file_contents .= "\n    return J\n";

#    #********************************************************#
#    # generate species conversion function                   #
#    #********************************************************#	

    $species_index_mapper_file_contents .= "!!! NOT IMPLEMENTED\n";
#    $species_index_mapper_file_contents .= "function n= ".$output_file_prefix."_s(a)\n\n";
#    for (my $j = 0; $j < @free_node_names; $j++) {
#	$species_index_mapper_file_contents .= ($j == 0) ? "if" : "elseif";
#	$species_index_mapper_file_contents .= " strcmp(a, '".$free_node_names[$j]."')\n";
#	$species_index_mapper_file_contents .= "\tn= ".($j+1).";\n";
#    }
#    $species_index_mapper_file_contents .= "else\n\tdisp('ERROR!');\n";
#    $species_index_mapper_file_contents .= "\tn= -1;\nend;";

#    #********************************************************#
#    # generate rates conversion function                     #
#    #********************************************************#	

    $rate_index_mapper_file_contents .= "!!! NOT IMPLEMENTED\n";
#    $rate_index_mapper_file_contents .= "function n= ".$output_file_prefix."_r(a)\n\n";
#    for (my $j = 0; $j < @constant_rate_param_names; $j++) {
#	$rate_index_mapper_file_contents .= ($j == 0) ? "if" : "elseif";
#	$rate_index_mapper_file_contents .= " strcmp(a, '".$constant_rate_param_names[$j]."')\n";
#	$rate_index_mapper_file_contents .= "\tn= ".($j+1).";\n";
#    }
#    $rate_index_mapper_file_contents .= "else\n\tdisp('ERROR!');\n";
#    $rate_index_mapper_file_contents .= "\tn= -1;\nend;"; 


    # substitute exponentiation operator "^" -> "**";
    $driver_file_contents =~ s/\^/\*\*/g;
    $ode_file_contents{all} =~ s/\^/\*\*/g;
    $jac_file_contents =~ s/\^/\*\*/g;

    # substitute logical operators e.g. "&&" -> "and";
    $driver_file_contents =~ s/&&/and/g;
    $ode_file_contents{all} =~ s/&&/and/g;
    $jac_file_contents =~ s/&&/and/g;
    $driver_file_contents =~ s/\|\|/or/g;
    $ode_file_contents{all} =~ s/\|\|/or/g;
    $jac_file_contents =~ s/\|\|/or/g;

    return (
	$driver_file_contents,
	$ode_file_contents{all},
	$jac_file_contents,
	$species_index_mapper_file_contents,
	$rate_index_mapper_file_contents,
	$IC_file_contents,
	$rates_file_contents,
       );
}

1;  # don't remove -- req'd for module to return true

