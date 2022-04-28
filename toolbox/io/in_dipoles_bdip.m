function DipolesMat = in_dipoles_bdip(fname)
% IN_DIPOLES_BDIP: Read a binary dipole file
%
% USAGE:  DipolesMat = in_dipoles_bdip(fname)
%
% DESCRIPTION: From page 115 of the source modeling chapter of the Neuromag manual

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
% Authors: John Mosher, Elizabeth Bock, 2008-2012

%% ===== READ BDIP FILE =====
% Open file
fid = fopen(fname,'rb','ieee-be');

% Get number of dipoles
fseek(fid,0,1);            % jump to the end
FileSize = ftell(fid);     % how many bytes
NumDipoles = FileSize/196; % size of the structure per dipole
% rewind file
fseek(fid,0,-1); 


% Build dipoles structure
[bdip(1:NumDipoles)] = deal(struct('dipole',[],'begin',[],'end',[],...
   'r0',zeros(3,1),'rd',zeros(3,1),'Q',zeros(3,1),'goodness',[],'errors_computed',[],...
   'noise_level',[],'single_errors',zeros(5,1),'error_matrix',zeros(5,5),...
   'conf_vol',[],'khi2',[],'prob',[],'noise_est',[]));

% Read each dipole
for i = 1:NumDipoles,
   bdip(i).dipole = fread(fid,1,'int32');    % Which dipole in a multi-dipole set
   bdip(i).begin  = fread(fid,1,'float32');  % Fitting time range (start)
   bdip(i).end    = fread(fid,1,'float32');  % Fitting time range (stop)
   bdip(i).r0     = fread(fid,3,'float32');  % Sphere model origin
   bdip(i).rd     = fread(fid,3,'float32');  % Dipole location
   bdip(i).Q      = fread(fid,3,'float32');  % Dipole amplitude
   bdip(i).goodness        = fread(fid,1,'float32');  % Goodness-of-fit
   bdip(i).errors_computed = fread(fid,1,'int32');    % Have we computed the errors
   bdip(i).noise_level     = fread(fid,1,'float32');  % Noise level used for error computations
   bdip(i).single_errors   = fread(fid,5,'float32');  % Single parameter error limits
   bdip(i).error_matrix    = fread(fid,25,'float32'); % This fully describes the conf. ellipsoid
   bdip(i).conf_vol  = fread(fid,1,'float32');  % The xyz confidence volume
   bdip(i).khi2      = fread(fid,1,'float32');  % The khi^2 value
   bdip(i).prob      = fread(fid,1,'float32');  % Probability to exceed khi^2 by chance
   bdip(i).noise_est = fread(fid,1,'float32');  % Total noise estimate
end 
% Close file
fclose(fid);


%% ===== REBUILD DIPOLES BLOCKS =====
% If several dipoles concatenated but not marked as different
nChanSet = 1;
if (NumDipoles > 1)
    timeSamp = round((bdip(2).begin - bdip(1).begin)*1000)*3;
    % Ask user for number of channel subsets
    nChanSet = java_dialog('input','Enter number of channel subsets used: ','Number of Channel Subsets',[], '1');
    if isempty(nChanSet)
        return
    end
    
    %  Get the number
    nChanSet = str2double(nChanSet);
    if nChanSet<1
        nChanSet = 1;
    end

    % Is only one dipole index
    isOneGroup = all([bdip.dipole] == bdip(1).dipole);
    % Is time linear
    timeDiff = round(diff([bdip.begin])*1000);
	
    % If need to change dipoles index
    if isOneGroup && any(abs(timeDiff) > timeSamp)
        % Get indices of new dipoles blocks
        iStartNew = find(abs(timeDiff) > timeSamp) + 1;
        iStartFit = [1 iStartNew length([bdip.dipole])+1];
        if length(unique(diff(iStartFit))) > 1
            bst_error('All groups must have equal number of time points','Import bdip dipoles');
        end
        % Loop on all the new blocks and assign an index
        for i = 1:length(iStartFit)-1
            indx = iStartFit(i) : iStartFit(i+1)-1;
            [bdip(indx).dipole] = deal(i);
        end 
    end    
end
% If only one group of dipole fits is represented here, or only one dipole exists,
% adjust the index to be one instead of zero
isIndexZero = all([bdip.dipole] == 0);
if isIndexZero
    for n=1:length([bdip.dipole])
        bdip(n).dipole = 1;
    end
end
    

%% ===== CONVERT TO BRAINSTORM FORMAT =====
% Get base filename
[fPath, fBase, fExt] = bst_fileparts(fname);
% Create base structure
DipolesMat = struct('Comment',     fBase, ...
                    'Time',        unique([bdip.begin]), ...
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
    DipolesMat.Dipole(i).Index          = double(bdip(i).dipole);
    DipolesMat.Dipole(i).Time           = bdip(i).begin;
    DipolesMat.Dipole(i).Origin         = bdip(i).r0;
    DipolesMat.Dipole(i).Loc            = bdip(i).rd;
    DipolesMat.Dipole(i).Amplitude      = bdip(i).Q;
    DipolesMat.Dipole(i).Goodness       = bdip(i).goodness;
    DipolesMat.Dipole(i).Errors         = bdip(i).errors_computed;
    DipolesMat.Dipole(i).Noise          = bdip(i).noise_level;
    DipolesMat.Dipole(i).SingleError    = bdip(i).single_errors;
    DipolesMat.Dipole(i).ErrorMatrix    = bdip(i).error_matrix;
    DipolesMat.Dipole(i).ConfVol        = bdip(i).conf_vol;
    DipolesMat.Dipole(i).Khi2           = bdip(i).khi2;
    DipolesMat.Dipole(i).Probability    = bdip(i).prob;
    DipolesMat.Dipole(i).NoiseEstimate  = bdip(i).noise_est;
end

% Create the dipoles names list
dipolesList = unique([DipolesMat.Dipole.Index]); %unique group names
DipolesMat.DipoleNames = cell(1,length(dipolesList));
k = 1; %index of names for groups with subsets
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
