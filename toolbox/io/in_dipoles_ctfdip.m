function DipolesMat = in_dipoles_ctfdip(fname)
% IN_DIPOLES_CTFDIP: Read a CTF fit.dip dipole file
%
% USAGE:  DipolesMat = in_dipoles_ctfdip(fname)
%
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
% Authors: Elizabeth Bock, 2013
%          Francois Tadel, 2013 

%% ===== READ DIP FILE =====
% Open file
fid = fopen(fname);
% find location of fit results in dip file
while 1
    tline = fgets(fid);
    if ~ischar(tline)
        break;
    end
    if strfind(tline,'// 	Trial  Sample  Latency')
       break;
    end
end

% find fit results
iDipoles = 1;
while 1
    tline = fgets(fid);
    if ~ischar(tline)
        break;
    end
    if strfind(tline, '1:')
        spl = str2double(regexp(tline, '\s++', 'split'));
        dip(iDipoles).trial = spl(3);
        dip(iDipoles).sample = spl(4);
        dip(iDipoles).Latency = spl(5);
        dip(iDipoles).position = [spl(6), spl(7), spl(8)] ./ 100; % cm->meters
        dip(iDipoles).orient = [spl(9), spl(10), spl(11)] ./ 100; % cm->meters
        dip(iDipoles).Mom = spl(12);
        dip(iDipoles).ellipsmajor = [spl(13), spl(14), spl(15)];
        dip(iDipoles).ellipsminor = [spl(16), spl(17), spl(18)];
        dip(iDipoles).ellipsinter = [spl(19), spl(20), spl(21)];
        dip(iDipoles).ellipsorigin = [spl(22), spl(23), spl(24)];
        dip(iDipoles).conf = spl(25);
        dip(iDipoles).Err = spl(26);
        dip(iDipoles).MEGerr = spl(27);
        dip(iDipoles).EEGerr = spl(28);
        dip(iDipoles).Label = spl(29);
        iDipoles = iDipoles+1;
    end
end
fclose(fid);
NumDipoles = length(dip);
%% ===== CONVERT TO BRAINSTORM FORMAT =====
% Get base filename
[fPath, fBase, fExt] = bst_fileparts(fname);
% Create base structure
DipolesMat = struct('Comment',     fBase, ...
                    'Time',        unique([dip.Latency]), ...
                    'DipoleNames', [], ...
                    'Subset', [], ...
                    'Dipole',      repmat(struct(...
                         'Index',           0, ...
                         'Time',            0, ...
                         'Origin',          [0 0 0], ...
                         'Loc',             [0 0 0], ...
                         'Amplitude',       [0 0 0], ...
                         'Goodness',        0, ...
                         'Errors',          0, ...
                         'Noise',           0, ...
                         'SingleError',     [0 0 0 0 0], ...
                         'ErrorMatrix',     zeros(1,25), ...
                         'ConfVol',         [], ...
                         'Khi2',            [], ...
                         'DOF',            [], ...
                         'Probability',     0, ...
                         'NoiseEstimate',   0, ...
                         'Perform',         0), 1, NumDipoles));

% Fill structure
for i = 1:NumDipoles
    DipolesMat.Dipole(i).Index          = dip(i).trial;
    DipolesMat.Dipole(i).Time           = dip(i).Latency;
    DipolesMat.Dipole(i).Origin         = dip(i).ellipsorigin;
    DipolesMat.Dipole(i).Loc            = dip(i).position';
    DipolesMat.Dipole(i).Amplitude      = dip(i).orient';
    DipolesMat.Dipole(i).Goodness       = 1-(dip(i).MEGerr/100);
    DipolesMat.Dipole(i).Errors         = dip(i).MEGerr;
    DipolesMat.Dipole(i).Noise          = [];
    DipolesMat.Dipole(i).SingleError    = [];
    DipolesMat.Dipole(i).ErrorMatrix    = [];
    DipolesMat.Dipole(i).ConfVol        = [];
    DipolesMat.Dipole(i).Khi2           = [];
    DipolesMat.Dipole(i).Probability    = [];
    DipolesMat.Dipole(i).NoiseEstimate  = [];
end

% Create the dipoles names list
dipolesList = unique([DipolesMat.Dipole.Index]); %unique group names
DipolesMat.DipoleNames = cell(1,length(dipolesList));
k = 1; %index of names for groups with subsets
nChanSet = 1;
for i = 1:(length(dipolesList)/nChanSet)
    % If more than one channel subset, name the groups according to index
    % and subset number
    if nChanSet > 1
        for j = 1:nChanSet
            DipolesMat.DipoleNames{k} = sprintf('Group #%d (%d)', dipolesList(i), j);
            DipolesMat.Subset(k) = j;
            k=k+1;
        end
    % if only one subsets, name the groups according to index
    else
        DipolesMat.DipoleNames{i} = sprintf('Group #%d', dipolesList(i));
        DipolesMat.Subset(i) = 1;
    end
   
end
DipolesMat.Subset = unique(DipolesMat.Subset);


