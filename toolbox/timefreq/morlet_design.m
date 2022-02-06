function [f, FWHM_t, FWHM_f, t, W] = morlet_design(fc,FWHM_tc)
% MORLET_DESIGN: Plots the complex Morlet wavelet and its temporal and frequency resolution for a set of frequencies.
%
% USAGE:  [f, FWHM_t, FWHM_f, t, W] = morlet_design(fc,FWHM_tc)
%
% INPUTS:
%     - fc      : Central frequency
%     - FWHM_tc : Full width half maximum of Gaussian kernel (in time) at the central
%                 frequency decreasing FWHM_tc improves temporal resolution (because
%                 the wavelet has smaller temporal extent) at the expense of frequency resolution
%
% DESCRIPTION: 
%     The complex Morlet wavelet is a Gaussian weighted sinusoid, blue for real values,
%     red for imaginary values. The wavelet has temporal and frequency resolution
%     weighted by Gaussian kernels. Two standard deviations are defined to be the resolution in
%     either dimension. 
%
% EXAMPLES: 
%     fc = 1;
%     FWHM_tc = 3;
%     morlet_design(fc,FWHM_tc);

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
% Authors: Dimitrios Pantazis, 2010

if nargin == 0 %if no input
    help morlet_design %display help
    return
end
sigma_tc = FWHM_tc / sqrt(8*log(2));
t = linspace(-4*sigma_tc,4*sigma_tc,1000);
W = morlet_wavelet(t,fc,sigma_tc);

%plot complex Morlet wavelet
if (nargout == 0)
    h = figure;
    plot(t,real(W),'linewidth',2)
    hold on
    plot(t,imag(W),'r','linewidth',2)
    set(gcf,'color','white')
    set(gca,'fontsize',14,'fontweight','bold')
end

%display example resolutions
f = 1:2:60; %Hz
sigma_t = sigma_tc*fc ./f; %standard deviation in time
sigma_f = 1./(2*pi*sigma_t); %standard deviation in time
% Convert to FWHM
FWHM_t = sqrt(8*log(2))*sigma_t; %FWHM resolution in time
FWHM_f = sqrt(8*log(2))*sigma_f; %FWHM resolution in frequency
    
if (nargout == 0)
    disp(' ')
    disp('The complex Morlet wavelet has point spread function with Gaussian shape both in'); 
    disp('time (temporal resolution) and in frequency (spectral resolution).');
    disp('It is designed by assigning the desired temporal resolution (variable FWHM_tc) at a specific frequency');
    disp('(central frequency). Then, its temporal and spectral resolution is automatically defined for all other');
    disp('frequencies. Resolution is given in units of FWHM for several frequencies:')
    disp('of the Gaussian kernel for several frequencies:')
    disp(' ')
    disp('Specified Parameters')
    disp(['Central frequency: fc = ' num2str(fc)]);
    disp(['FWHM at fc: FWHM_tc = ' num2str(FWHM_tc)]);
    disp(' ')
    disp('Resolution Properties')
    disp('frequency  FWHM_t(sec)  FWHM_f(Hz)');
    disp([f'  FWHM_t'  FWHM_f'])
end