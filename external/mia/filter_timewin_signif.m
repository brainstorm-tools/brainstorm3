function [h] = filter_timewin_signif(h, thresh) 
% ***********************************************************************
% Filters significative timestamps : removes from mask (h) the consecutive 
% significant points that exceed a certain duration (thresh)
% 
% Inputs :
% h : nsens x nsamples 
% thres : consecutive significative points threshold (in samples)
%
% ***********************************************************************% 
% This file is part of MIA.
% 
% MIA is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% MIA is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%  
% Copyright (C) 2016-2018 CNRS - Universite Aix-Marseille
%
% ***********************************************************************
% This software was developed by
%       Anne-Sophie Dubarry (CNRS Universite Aix-Marseille)
%
% ***********************************************************************
% Ex : fh = filter_timewin_signif(h(:,:),fix(0.01*Fs)) ;

% Get electrodes that show any significant point
elec_sig = find(max(h')==1) ; 

% For each electrode
for jj=1:length(elec_sig) 
    
    c=h(elec_sig(jj),:);
    % Set first and last sample to zero (in order to detect the same number
    % of rising edge than falling edge
    c(1)=0; c(end) = 0 ;
    
    % Detect rising and falling edge 
    r_edge = find(diff(c)>0);
    f_edge = find(diff(c)<0);
    
    % Get segments that have a number of consecutive ones > threshold
    idx = abs(r_edge-f_edge)<=thresh ;
    
    % Get the indices of period of time to remove (by rising and falling
    % edges) 
    r_edget=r_edge(idx);
    f_edget=f_edge(idx);
    
    % Remove segment that are not long enough
    for ii=1:length(r_edget)
        c(r_edget(ii):f_edget(ii) )= 0 ; 
    end
    
    h(elec_sig(jj),:) = c;

end
