//
// File generated by Facile version 0.53
//

#include <cvode/cvode.h>             // prototypes for CVODE fcts., consts.
#include <nvector/nvector_serial.h>  // serial N_Vector types, fcts., macros
#include <cvode/cvode_dense.h>       // prototype for CVDense
#include <sundials/sundials_dense.h> // definitions DlsMat DENSE_ELEM
#include <sundials/sundials_types.h> // definition of type realtype

#include <vector>

#define ODE_OPTION_RELTOL        0
#define ODE_OPTION_ABSTOL        1
#define ODE_OPTION_INITSTEP      2
#define ODE_OPTION_MINSTEP       3
#define ODE_OPTION_MAXSTEP       4
#define ODE_OPTION_SS_TIMESCALE  5
#define ODE_OPTION_SS_RELTOL     6
#define ODE_OPTION_SS_ABSTOL     7
#define NUM_ODE_OPTIONS          8

static const unsigned int NEQ = 3;

int cvode_sim_steady_state(double *ivalues, double *ode_rate_constants,
                                  std::vector<realtype> &tv,
                                  std::vector<realtype> &aT,
                                  std::vector<realtype> &aY,
                                  std::vector<realtype> &ode_options,
                                  std::vector<realtype> &ode_events,
                                  std::vector<int>      &event_flags,
                                  std::vector<realtype> &event_times
                                  );

int cvode_sim_print_output(std::vector<realtype> &aT,
                           std::vector<realtype> &aY);

