function [err,r,b] = sphererr(z,headdata);
% SPHERERR: Find best fitting 3-D sphere to a set of data
% function [err,r,b] = sphererr(z,headdata);
% Given z = [x0,y0,z0] (row vector), 
%  headdata = [x y z] (matrix of such rows)
% Calculate 
%  b = sqrt((x-x0)^2 + (y-y0)^2 + (z-z0)^2).
% Return err proportional to std dev of b, which effectively
%  calculates r as the mean of the b.
% Execute this routine in a minimization algorithm, such as:
%   X = fmins('sphererr',X0,[],[],headdata);
%   [err,r] = sphererr(X,headdata);  % returns average error and radius
 
% Copyright(c) 1994 John C. Mosher
% Los Alamos National Laboratory
% Group ESA-6, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov

 
[m,n] = size(headdata);
b = headdata - ones(m,1)*z';  % data - estimates
% form square of distance to center estimate
b = b.^2;  
b = sqrt(sum(b'))';
r = mean(b);
err = (b-r).^2; % square error
%err = sqrt(sum(err)/m); % biased std deviation
err = sum(err);  % equivalent for minimization
return
 
