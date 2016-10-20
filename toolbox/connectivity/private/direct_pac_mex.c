/* --------------------------------------------------------------
 * file: direct_pac_mex.c - calculates directPAC metric
 *     
 * DPAC = direct_pac_mex(PHASE,AMPLITUDE)
 * INPUTS:
 * PHASE - TxMxS complex matrix (T=number of timepoints, 
 * 		M=number of low frequencies, S=number of signals)
 * AMPLITUDE - TxNxS real matrix (T=number of timepoints, 
 *              N=number of high frequencies, S=number of signals)
 * OUTPUTS:             
 * DPAC - MxNxS complex matrix (unscaled directPAC metric)
 * --------------------------------------------------------------*/

#include "mex.h"
#include "math.h"

void computeDirectPAC(double *phase_r, double *phase_i, int *dimPhase,
                        double *amp, const int *dimAmp,
                        double *out_r, double *out_i);

/* --------------------------------------------------------------
 * function: mexFunction - Entry point from Matlab environment
 * INPUTS: 
 * nlhs - number of left hand side arguments (outputs)
 * plhs[] - pointer to table where created matrix pointers are
 * to be placed
 * nrhs - number of right hand side arguments (inputs)
 * prhs[] - pointer to table of input matrices
 * --------------------------------------------------------------*/

void mexFunction(int nlhs, mxArray *plhs[], /* Output variables */
		int nrhs, const mxArray *prhs[]) /* Input variables */
{
	/* assign variables */
	/* input & output matrices, real & imaginary part */
	double *pA_r, *pA_i, *pB, *pOut_r, *pOut_i;
	/* matrix dimensions */
	int nDimA, nDimB;
	int *dimsA, *dimsB;
    int dimsOut[3];

	if (nrhs!=2){ mexErrMsgTxt("Expecting two inputs."); }
	
	/* get input dimensions */
	nDimA = mxGetNumberOfDimensions(prhs[0]);
	nDimB = mxGetNumberOfDimensions(prhs[1]);
	dimsA = (int *) mxGetDimensions(prhs[0]);
	dimsB = (int *) mxGetDimensions(prhs[1]);
	/* add 3rd dimension if only one input signal */
	if (nDimA==2){ *(dimsA+2)=1; *(dimsB+2)=1; }
	/* check if dimensions fit */
    if ((*dimsA!=*dimsB) | (nDimA!=nDimB) | (*(dimsA+2)!=*(dimsB+2))){
            mexErrMsgTxt("Input dimensions mismatch.");
    }
    
	/* calculate output dimensions, allocate output, get pointer */
    dimsOut[0] = *(dimsA+1);
    dimsOut[1] = *(dimsB+1);
    dimsOut[2] = *(dimsA+2); 
	plhs[0] = mxCreateNumericArray(nDimA, dimsOut, mxDOUBLE_CLASS, 1);	
	pOut_r = mxGetPr(plhs[0]);
	pOut_i = mxGetPi(plhs[0]);
	
	/* get pointers to input matrices */	
	if (mxIsComplex(prhs[0])){
        	pA_r = mxGetPr(prhs[0]);
        	pA_i = mxGetPi(prhs[0]);
	} else mexErrMsgTxt("Input 1 has to be complex array.");
	if (mxIsDouble(prhs[1])){
		pB = mxGetPr(prhs[1]);
	} else mexErrMsgTxt("Input 2 has to be double array.");		
	
	/* compute */
	computeDirectPAC(pA_r, pA_i, dimsA, pB, dimsB, pOut_r, pOut_i);		

	return;
}

void computeDirectPAC(double *phase_r, double *phase_i, int *dimPhase,
			double *amp, const int *dimAmp,
			double *out_r, double *out_i){

	int iS, iA, offA, iP, offP, iT, c; /* loop variables */
	double tmp_r, tmp_i; /* temporary real & imaginary variables */	
	
	c=0; /* counter for indexing output matrix */
	
	/* loop over signals */
	for (iS=0; iS<*(dimAmp+2); iS++){
		/* high frequencies loop */
		for (iA=0; iA<*(dimAmp+1); iA++){
			/* offset for indexing amplitude array */
			offA = 0 + iA * *(dimAmp) + iS * *(dimAmp) * *(dimAmp+1);
			/* low frequencies loop */
			for (iP=0; iP<*(dimPhase+1); iP++){
				/* offset for indexing phase array */
				offP = 0 + iP * *(dimPhase) + iS * *(dimPhase) * *(dimPhase+1);
				/* time loop */
				tmp_r = phase_r[offP] * amp[offA];
				tmp_i = phase_i[offP] * amp[offA];
				for (iT=1; iT<*(dimAmp); iT++){
					tmp_r = tmp_r + phase_r[iT+offP] * amp[iT+offA];
					tmp_i = tmp_i + phase_i[iT+offP] * amp[iT+offA];
				}
				out_r[c] = tmp_r;
				out_i[c] = tmp_i;
				c++;
			}
		}
	}

	return;	
}


