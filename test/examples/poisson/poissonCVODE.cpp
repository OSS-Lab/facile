//
// File generated by Facile version 0.53
//
// This code is adapted from the file "cvRoberts_dns.c", a usage example
// that is part of the the of the Sundials suite:
// * -----------------------------------------------------------------
// * Programmer(s): Scott D. Cohen, Alan C. Hindmarsh and
// *                Radu Serban @ LLNL
// * -----------------------------------------------------------------
//

#include <stdio.h>
#include <math.h>

// Custom header file
#include "poissonCVODE.h"

#define Ith(v,i)    NV_Ith_S(v,i)
#define IJth(A,i,j) DENSE_ELEM(A,i,j)

// These macros needed to properly handle discontinuities
#if defined(SUNDIALS_SINGLE_PRECISION)
#define DT_BEFORE(x) nextafterf((float)x,x/2.0)
#define DT_AFTER(x) nextafterf((float)x,x*2.0)
#elif defined(SUNDIALS_DOUBLE_PRECISION)
#define DT_BEFORE(x) nextafter((double)x,x/2.0)
#define DT_AFTER(x) nextafter((float)x,x*2.0)
#elif defined(SUNDIALS_EXTENDED_PRECISION)
#define DT_BEFORE(x) nextafterl((long double)x,x/2.0)
#define DT_AFTER(x) nextafterl((float)x,x*2.0)
#endif

// Private function to check function return values

static int check_flag(void *flagvalue, char *funcname, int opt);

// Private functions to output results

static void StoreOutput(std::vector<realtype> *T,
                        std::vector<realtype> *Y,
                        realtype t, N_Vector y);

static void PrintOutput(realtype t, N_Vector y);

// Private function to print final statistics

static void PrintFinalStats(void *cvode_mem);

// User-defined model functions by the Solver

static int f_dydt(realtype t, N_Vector y, N_Vector ydot, void *user_data);

static int f_jac(int N, realtype t,
                 N_Vector y, N_Vector fy, DlsMat J, void *user_data,
                 N_Vector tmp1, N_Vector tmp2, N_Vector tmp3);

// Constants and functions that may appear in user-defined model functions
static const realtype pi = atan(1.0)*4.0;

// Octave-style square() function -- (duty cycle between 0 and 1)
static realtype square(realtype t, realtype duty) {
  realtype r;

  if (fmod(t, 2*pi) < 2*pi * duty) {
    r = +1;
  } else {
    r = -1;
  }
  return r;
}

static realtype square(realtype t) {
  realtype r;
  realtype duty = 0.5;

  if (fmod(t, 2*pi) < 2*pi * duty) {
    r = +1;
  } else {
    r = -1;
  }
  return r;
}


// Main Program

int cvode_sim_poisson(double *ivalues, double *rates,
                                  std::vector<realtype> *aT,
                                  std::vector<realtype> *aY) {

  realtype t0 = 0.0;
  N_Vector y = NULL;

  void *cvode_mem = NULL;

  int flag;

  // Create serial vector of length NEQ for I.C.
  y = N_VNew_Serial(NEQ);
  if (check_flag((void *)y, (char*)"N_VNew_Serial", 0)) return(1);

  // initial values (free nodes only)
  Ith(y,0) = ivalues[0]; // D
  Ith(y,1) = ivalues[1]; // A

  // set absolute and relative integration tolerances
  realtype reltol = RCONST(0.001);
  N_Vector abstol = N_VNew_Serial(NEQ);
  if (check_flag((void *)abstol, (char*)"N_VNew_Serial", 0)) return(1);
  for (int i=0; i<NEQ; i++) {
    Ith(abstol,i) = RCONST(1e-06);
  }

  // rate constants and constant expressions
  realtype ode_rate_constants[1];
  realtype d                = ode_rate_constants[0] = rates[0];

  // Call CVodeCreate to create the solver memory and specify the
  // Backward Differentiation Formula and the use of a Newton iteration
  cvode_mem = CVodeCreate(CV_BDF, CV_NEWTON);
  if (check_flag((void *)cvode_mem, (char*)"CVodeCreate", 0)) return(1);
  
  // Call CVodeInit to initialize the integrator memory and specify the
  // user's right hand side function in y'=f(t,y), the inital time t0, and
  // the initial dependent variable vector y.
  flag = CVodeInit(cvode_mem, f_dydt, t0, y);
  if (check_flag(&flag, (char*)"CVodeInit", 1)) return(1);

  // Call CVodeSVtolerances to specify the scalar relative tolerance
  // and vector absolute tolerances
  flag = CVodeSVtolerances(cvode_mem, reltol, abstol);
  if (check_flag(&flag, (char*)"CVodeSVtolerances", 1)) return(1);

  // Call CVodeSetUserData to specify rate constants
  flag = CVodeSetUserData(cvode_mem, ode_rate_constants);
  if (check_flag(&flag, (char*)"CVodeSetUserData", 1)) return(1);

  // Call CVDense to specify the CVDENSE dense linear solver
  flag = CVDense(cvode_mem, NEQ);
  if (check_flag(&flag, (char*)"CVDense", 1)) return(1);

  // Set the Jacobian routine to Jac (user-supplied)
  flag = CVDlsSetDenseJacFn(cvode_mem, f_jac);
  if (check_flag(&flag, (char*)"CVDlsSetDenseJacFn", 1)) return(1);

  // Set misc. options
  flag = CVodeSetInitStep(cvode_mem, 0.0);
  if (check_flag(&flag, (char*)"CVodeSetInitStep", 1)) return(1);

  flag = CVodeSetMinStep(cvode_mem, 0.0);
  if (check_flag(&flag, (char*)"CVodeSetMinStep", 1)) return(1);

  // ODE discontinuities
  unsigned int num_ode_events = 2;
  realtype ode_events[2] = {4,8};
  realtype ode_events_minus_dt[2] = {DT_BEFORE(4),DT_BEFORE(8)};
  unsigned int ode_event_index = 0;
  flag = CVodeSetStopTime(cvode_mem, ode_events_minus_dt[ode_event_index]);
  if (check_flag(&flag, (char*)"CVodeSetStopTime", 1)) return(1);

  // Setup for main loop
  int cvode_mode = CV_ONE_STEP;

  realtype t = 0;
  realtype tf = 10;
  realtype tout = realtype(tf / 100.0);

  unsigned int i_sample = 1;
  unsigned int num_samples = floor(tf / realtype(tf / 100.0) + realtype(0.5)); // use floor() to round;

  aT->resize(0); aT->reserve(num_samples+1);
  aY->resize(0); aY->reserve((num_samples+1)*NEQ);

  // Print output at initial time
  PrintOutput(t, y);
  StoreOutput(aT, aY, t, y);

  // Main loop: call CVode, output results, manage events and test for errors.
  while(1) {
    flag = CVode(cvode_mem, tout, y, &t, cvode_mode);
    if (check_flag(&flag, (char*)"CVode", 1)) break;
    if (flag == CV_SUCCESS) {
      PrintOutput(t, y);
      StoreOutput(aT, aY, t, y);
      if (cvode_mode == CV_NORMAL) {
        i_sample++;
        tout = realtype(i_sample) / realtype(num_samples) * tf;
      } else {
        tout = 0.0;
      }
    } else if (flag == CV_TSTOP_RETURN) {
      // Check that we stopped at expected time
      if (t != ode_events_minus_dt[ode_event_index]) { // should always be true
        printf("ERROR: unexpected condition\n");
      }
      // Output value at (event-dt) only if solver-defined steps
      if (cvode_mode == CV_ONE_STEP) {
        PrintOutput(t, y);
        StoreOutput(aT, aY, t, y);
      }

      // Advance time to the discontinuity, extend and output y
      t = ode_events[ode_event_index];
      printf("ode_event at t=%.40f\n",t);

      // Ouput if solver-defined steps or if on user-defined sample point
      if (cvode_mode == CV_ONE_STEP || (cvode_mode == CV_NORMAL && t == tout)) {
        PrintOutput(t, y);
        StoreOutput(aT, aY, t, y);
        if (cvode_mode == CV_NORMAL) {
          i_sample++;
          tout = realtype(i_sample) / realtype(num_samples) * tf;
        } else {
          tout = t + realtype(tf / 100.0);
        }
      }

      // Call CVodeReInit to re-initialize the integrator at the discontinuity
      flag = CVodeReInit(cvode_mem, t, y);
      if (check_flag(&flag, (char*)"CVodeReInit", 1)) return(1);
      if (cvode_mode == CV_ONE_STEP) tout = t + realtype(tf / 100.0); // first time to output

      // Next event and set a new stop time if necessary
      ode_event_index++;
      if (ode_event_index < num_ode_events) {
        flag = CVodeSetStopTime(cvode_mem, ode_events_minus_dt[ode_event_index]);
        if (check_flag(&flag, (char*)"CVodeSetStopTime", 1)) return(1);
      } else {
        flag = CVodeSetStopTime(cvode_mem, 2.0*tf);
        if (check_flag(&flag, (char*)"CVodeSetStopTime", 1)) return(1);
      }
    } else {
      break;
    }

    // Stopping condition
    if (t >= tf) break;
  }

  // Print some final statistics
  PrintFinalStats(cvode_mem);

  // Free y and abstol vectors
  N_VDestroy_Serial(y);
  N_VDestroy_Serial(abstol);

  // Free integrator memory
  CVodeFree(&cvode_mem);

  return(0);
}

 // Private helper functions
static void StoreOutput(std::vector<realtype> *aT,
                        std::vector<realtype> *aY,
                        realtype t, N_Vector y) {
  aT->push_back(t);

  realtype *y_ptr = &(Ith(y,0));
  for(int i=0; i < NEQ; i++) {
    aY->push_back(y_ptr[i]);
  }
}

static void PrintOutput(realtype t, N_Vector y) {
  printf("At t = %0.20e      y[] = ",t);
  int i;

  for (i=0; i < NEQ; i++) {
//    printf("%.20e  ", Ith(y,i));
  }
  printf("\n");
  return;
}

// Get and print some final statistics

static void PrintFinalStats(void *cvode_mem) {
  long int nst, nfe, nsetups, nje, nfeLS, nni, ncfn, netf, nge;
  int flag;

  flag = CVodeGetNumSteps(cvode_mem, &nst);
  check_flag(&flag, (char*)"CVodeGetNumSteps", 1);
  flag = CVodeGetNumRhsEvals(cvode_mem, &nfe);
  check_flag(&flag, (char*)"CVodeGetNumRhsEvals", 1);
  flag = CVodeGetNumLinSolvSetups(cvode_mem, &nsetups);
  check_flag(&flag, (char*)"CVodeGetNumLinSolvSetups", 1);
  flag = CVodeGetNumErrTestFails(cvode_mem, &netf);
  check_flag(&flag, (char*)"CVodeGetNumErrTestFails", 1);
  flag = CVodeGetNumNonlinSolvIters(cvode_mem, &nni);
  check_flag(&flag, (char*)"CVodeGetNumNonlinSolvIters", 1);
  flag = CVodeGetNumNonlinSolvConvFails(cvode_mem, &ncfn);
  check_flag(&flag, (char*)"CVodeGetNumNonlinSolvConvFails", 1);

  flag = CVDlsGetNumJacEvals(cvode_mem, &nje);
  check_flag(&flag, (char*)"CVDlsGetNumJacEvals", 1);
  flag = CVDlsGetNumRhsEvals(cvode_mem, &nfeLS);
  check_flag(&flag, (char*)"CVDlsGetNumRhsEvals", 1);

  flag = CVodeGetNumGEvals(cvode_mem, &nge);
  check_flag(&flag, (char*)"CVodeGetNumGEvals", 1);

  printf("\nFinal Statistics:\n");
  printf("nst = %-6ld nfe  = %-6ld nsetups = %-6ld nfeLS = %-6ld nje = %ld\n",
	 nst, nfe, nsetups, nfeLS, nje);
  printf("nni = %-6ld ncfn = %-6ld netf = %-6ld nge = %ld\n \n",
	 nni, ncfn, netf, nge);
}

//
// Check function return value...
//   opt == 0 means SUNDIALS function allocates memory so check if
//            returned NULL pointer
//   opt == 1 means SUNDIALS function returns a flag so check if
//            flag >= 0
//   opt == 2 means function allocates memory so check if returned
//            NULL pointer 
//

static int check_flag(void *flagvalue, char *funcname, int opt) {
  int *errflag;

  /* Check if SUNDIALS function returned NULL pointer - no memory allocated */
  if (opt == 0 && flagvalue == NULL) {
    fprintf(stderr, "\nSUNDIALS_ERROR: %s() failed - returned NULL pointer\n\n",
	    funcname);
    return(1); }

  /* Check if flag < 0 */
  else if (opt == 1) {
    errflag = (int *) flagvalue;
    if (*errflag < 0) {
      fprintf(stderr, "\nSUNDIALS_ERROR: %s() failed with flag = %d\n\n",
	      funcname, *errflag);
      return(1); }}

  /* Check if function returned NULL pointer - no memory allocated */
  else if (opt == 2 && flagvalue == NULL) {
    fprintf(stderr, "\nMEMORY_ERROR: %s() failed - returned NULL pointer\n\n",
	    funcname);
    return(1); }

  return(0);
}

static int f_dydt(realtype t, N_Vector y, N_Vector ydot, void *user_data) {
//    printf("f_dydt call at t=%.20f\n",t);

    realtype *ode_rate_constants = (realtype *)user_data;

    // state vector to node mapping
    realtype D = Ith(y,0);
    realtype A = Ith(y,1);

    // rate constants and constant expressions
    realtype d = ode_rate_constants[0];



    // expressions
    realtype k = t/4*10*(t>4 && t<8);

    // differential equations for independent species
    Ith(ydot,0) = 0;
    Ith(ydot,1) =  + k*D - d*A;

    return (0);
}

static int f_jac(int N, realtype t,
                 N_Vector y, N_Vector fy, DlsMat J, void *user_data,
                 N_Vector tmp1, N_Vector tmp2, N_Vector tmp3) {

    realtype *ode_rate_constants = (realtype *)user_data;

    // state vector to node mapping
    realtype D = Ith(y,0);
    realtype A = Ith(y,1);

    // rate constants and constant expressions
    realtype d = ode_rate_constants[0];



    // expressions
    realtype k = t/4*10*(t>4 && t<8);

    // jacobian equations for independent species
    unsigned int i,j;
    for (i=0; i < 2; i++) {
        for (j=0; j < 2; j++) {
            IJth(J,i,j) = 0.0;
        }
    }
    IJth(J,0,0) = 0;
    IJth(J,1,0) =  + k;
    IJth(J,1,1) =  - d;

    return (0);
}
