function [R,T,Yf,Err] = rot3dfit(X,Y)
%ROT3DFIT Determine least-square rigid rotation and translation.
% [R,T,Yf] = ROT3DFIT(X,Y) permforms a least-square fit for the
% linear form
%
% Y = X*R + T
%
% where R is a 3 x 3 orthogonal rotation matrix, T is a 1 x 3
% translation vector, and X and Y are 3D points sets defined as
% N x 3 matrices. Yf is the best-fit matrix.
%
% See also SVD, NORM.
%
% rot3dfit: Frank Evans, NHLBI/NIH, 30 November 2001
%

% ROT3DFIT uses the method described by K. S. Arun, T. S. Huang, and
% S. D. Blostein, "Least-Squares Fitting of Two 3-D Point Sets",
% IEEE Transactions on Pattern Analysis and Machine Intelligence,
% PAMI-9(5): 698 - 700, 1987.
%
% A better theoretical development is found in B. K. P. Horn,
% H. M. Hilden, and S. Negahdaripour, "Closed-form solution of
% absolute orientation using orthonormal matrices", Journal of the
% Optical Society of America A, 5(7): 1127 - 1135, 1988.
%
% Special cases, e.g. colinear and coplanar points, are not implemented.

% error(nargchk(2,2,nargin));
if size(X,2) ~= 3, error('X must be N x 3'); end;
if size(Y,2) ~= 3, error('Y must be N x 3'); end;
if size(X,1) ~= size(Y,1), error('X and Y must be the samesize'); end;

% mean correct

Xm = mean(X,1); X1 = X - ones(size(X,1),1)*Xm;
Ym = mean(Y,1); Y1 = Y - ones(size(Y,1),1)*Ym;

% calculate best rotation using algorithm 12.4.1 from
% G. H. Golub and C. F. van Loan, "Matrix Computations"
% 2nd Edition, Baltimore: Johns Hopkins, 1989, p. 582.

XtY = (X1')*Y1;
[U,S,V] = svd(XtY);
R = U*(V');

% solve for the translation vector

T = Ym - Xm*R;

% calculate fit points

Yf = X*R + ones(size(X,1),1)*T;

% calculate the error

dY = Y - Yf;
Err = norm(dY,'fro'); % must use Frobenius norm 


