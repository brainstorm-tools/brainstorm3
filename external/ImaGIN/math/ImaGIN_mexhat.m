function M = ImaGIN_mexhat(fs, f)
% Generate Mexican hat wavelets
% FORMAT M = spm_eeg_morlet(Rtf, ST, f, ff)
% 
% fs  - sample frequency [ms]
% f   - vector of frequencies [Hz]
%
% M   - cell vector, where each element contains the filter for each
%       frequency in f
%__________________________________________________________________________
% 
% spm_eeg_morlet generates morlet wavelets for specified frequencies f with
% a specified ratio Rtf, see [1], for sample time ST (ms). One obtains the
% wavelet coefficients by convolution of a data vector with the kernels in
% M. See spm_eeg_tf how one obtains instantaneous power and phase estimates
% from the wavelet coefficients.
%
% [1] C. Tallon-Baudry, O. Bertrand, F. Peronnet and J. Pernier, 1998.
% Induced \gamma-Band Activity during the Delay of a Visual Short-term
% memory Task in Humans. The Journal of Neuroscience (18): 4244-4254.
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Stefan Kiebel
% $Id: spm_eeg_morlet.m 5900 2014-02-27 21:54:51Z karl $


M      = {};
for f0 = f
    
    nu=f0/fs;
    M{end+1} = mexhat(nu);

end


function  h = mexhat(nu) ;
%MEXHAT	Mexican hat wavelet in time domain.
%	H=MEXHAT(NU) returns the mexican hat wavelet with central 
%	frequency NU (NU is a normalized frequency in Hz). 
%
%	NU : any real between 0 and 0.5		(default : 0.05).
%	H  : time vector containing the mexhat samples. 
%		length(H)=2*ceil(1.5/NU)+1.
%
%	Example : 
%	 plot(mexhat);
%
%	See also KLAUDER.

%	P. Goncalves, October 95
%	Copyright (c) 1995 Rice University
%
%  This program is free software; you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation; either version 2 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program; if not, write to the Free Software
%  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

if nargin==0,
 nu=0.05;
elseif nargin>1,
 error('Too many input parameters');
end

if nu>0.5 | nu<0,
 disp('Warning : NU should be between 0 and 0.5');
end

N = 1.5 ;
alpha = pi^2*nu^2 ;
n = ceil(N/nu) ; 
t = -n:n ;
h = nu*sqrt(pi)/2*exp(-alpha*t.^2).*(1-2*alpha*t.^2) ; 

