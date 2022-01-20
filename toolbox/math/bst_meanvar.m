function varargout = bst_meanvar(varargin)
%BST_MEANVAR: Mex-file to compute mean and variance along first dimension (with imprecise algorithm)
%
% USAGE: [mean,var,nAvg] = bst_meanvar(x, isZeroBad)
% 
% INPUTS: 
%    - x         : [NxM] double matrix with values to process
%    - isZeroBad : If 1, excludes all the zero values from the computation
%
% OUTPUTS:
%    - mean : [1xM] averages values 
%    - var  : [1xM] unbiased estimator of the variance (computed with an algorithm prone to rounding errors)
%    - nAvg : [1xM] number of non-zero values that were averaged
% 
% COMPILE:
%    mex -v bst_meanvar.c

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2016

error('Mex-function bst_meanvar.c not compiled.');

