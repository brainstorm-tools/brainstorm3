function [Cel, Cind, x, y, z, Ic] = ImaGIN_spm_eeg_locate_channels(D, n, interpolate_bad,dmax,Ctf,Atlas)
% function [Cel, Cind, x, y, z] = ImaGIN_spm_eeg_locate_channels(D, n, interpolate_bad)
%
% Locates channels and generates mask for converting EEG data to analyze format on the scalp

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Olivier David

switch Atlas
    case{'Human'}
        tmp = spm('Defaults','EEG');
        bb = tmp.normalise.write.bb;
    case{'Rat'}
        bb = [[-80 -156 -120];[80 60 10]];
    case{'Mouse'}
        bb = [[-48 -94 -70];[48 72 0]];
    case{'PPN'}
        bb = [[-8 -5 -20];[8 6 2]];     % Brainstem full
end

Nchannels = length(Ctf.label);

try
    if ~isfield(Ctf,'pnt')
        Ctf.pnt = Ctf.elecpos;
    end
    Cel = Ctf.pnt';    
catch
    D.channels.order = 1:Nchannels;
    D.channels.eeg = 1:Nchannels;
    Cel = Ctf.pnt';    
end

Bad = badchannels(D);

% For mapping indices
Itmp = zeros(1,Nchannels);
Itmp(1:Nchannels) = 1:Nchannels;        %to be optimised ?

Cind = setdiff(1:Nchannels, Bad);

[x,y,z] = meshgrid(bb(1,1):n:bb(2,1),...
    bb(1,2):n:bb(2,2),...
    bb(1,3):n:bb(2,3));

dmax = dmax^2;  %5mm

Ic = [];
if interpolate_bad
    % keep bad electrode positions in
    for i1 = 1:size(Cel,2)
        d = (x(:)-Cel(1,i1)).^2+(y(:)-Cel(2,i1)).^2+(z(:)-Cel(3,i1)).^2;
        Ic = [Ic; find(d <= dmax)];
    end
else
    % or don't
    tmp = Itmp(Cind);
    for i1 = 1:length(Cind)
        d = (x(:)-Cel(1,tmp(i1))).^2+(y(:)-Cel(2,tmp(i1))).^2+(z(:)-Cel(3,tmp(i1))).^2;
        Ic = [Ic;find(d<=dmax)];
    end
end
Ic = unique(Ic);

x = x(Ic); 
y = y(Ic); 
z = z(Ic);

Cel = Cel';
Cel = Cel(Itmp(Cind), :);
if (length(Cind) == D.nchannels)
    Cind = 1:D.nchannels;
end



