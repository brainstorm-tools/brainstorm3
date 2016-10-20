/*--------------------------------------------------------------
 * file: bst_meanvar.c - Mean and variance estimation along first dimension with imprecise algorithm
 *                       Excludes the zero values from the computation
 *                   
 * [mean,var,nAvg] = bst_meanvar(x, isZeroBad)
 *-------------------------------------------------------------- */
#include <math.h>
#include "mex.h"

/*--------------------------------------------------------------
 * function: mexFunction - Entry point from Matlab environment
 * INPUTS:
 * nlhs - number of left hand side arguments (outputs)
 * plhs[] - pointer to table where created matrix pointers are
 * to be placed
 * nrhs - number of right hand side arguments (inputs)
 * prhs[] - pointer to table of input matrices
 *-------------------------------------------------------------- */

/* Compile with: 
 * mex -v bst_meanvar.c */

void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] ){
    double *x, *mean, *var, *param, *nAvg;
    int j, N, M, isZeroBad;
    
	/* Input checks */
    if (nrhs < 1)
        mexErrMsgTxt("Not enough input arguments.");
    if (nrhs > 2)
        mexErrMsgTxt("Too many input arguments.");
    if ((!mxIsDouble(prhs[0])) || (!mxIsDouble(prhs[1])))
        mexErrMsgTxt("Arguments must be type double.");
    if (mxIsComplex(prhs[0]) || ((nrhs > 1) && (mxIsComplex(prhs[1]))))
        mexWarnMsgTxt("Complex parts ignored.");
		
    /* Get input data */
    x = mxGetPr(prhs[0]);
    M = mxGetM(prhs[0]);   /* Signals to average */
    N = mxGetN(prhs[0]);   /* Independent measurements */
	/* Additional parameters */
    param = mxGetPr(prhs[1]);
	if (param[0] == 0){
		isZeroBad = 0;
	} else {
		isZeroBad = 1;
	}
	
	
    /* Initialize outputs */
    plhs[0] = mxCreateDoubleMatrix(1,N,mxREAL);
	plhs[1] = mxCreateDoubleMatrix(1,N,mxREAL);
	plhs[2] = mxCreateDoubleMatrix(1,N,mxREAL);
    mean = mxGetPr(plhs[0]);
	var  = mxGetPr(plhs[1]);
	nAvg = mxGetPr(plhs[2]);
    
    /* Mean/Variance computation */
	/* Loop on indendent measurements */
    for (j=0; j<N; j++){
        double vA = 0.0;    
        int i;
		
        /* Mean:  Loop on signals to average */
        for (i=0; i<M; i++) {
		    if ((isZeroBad == 0) || (x[i + j*M] != 0)){
				mean[j] += x[i + j*M];
				nAvg[j] += 1;
			}
		}
		/* Averaging at least two values */
		if (nAvg[j] > 1){
		    /* Finish the computation of the average */
		    mean[j] = mean[j] / nAvg[j];
			/* Variance:  Loop on signals to average */
			for (i=0; i<M; i++) {
				if (x[i + j*M] != 0){
					vA = (x[i + j*M] - mean[j]);
					var[j] += vA * vA;
				}
			}
			/* Unbiased estimator */
			var[j] = var[j] / (nAvg[j]-1);
		} else {
			var[j] = 0;
		}
    }

} /* end mexFunction() */
