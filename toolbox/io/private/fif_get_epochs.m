function [epochs] = fif_get_epochs( sFile, fid )
% FIF_GET_EPOCHS: Get the descriptions of all the epochs in an evoked .FIF file.
%
% USAGE:  epochs = fif_get_epochs( sFile, fid )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2011
%          Based on scripts from M.Hamalainen

% FIFF Constants
global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end
% Inialize returned variable
epochs = [];

% Get epochs list
sets = fiff_dir_tree_find(sFile.header.tree, FIFF.FIFFB_EVOKED);
nbSets = length(sets);
% If at least one set avaialable => evoked FIF file
if (nbSets > 0)
    % Initialize structure
    epochs = struct('label',   '', ...
                    'times',   [], ...
                    'nAvg',    1);
    iTotal = 1;
    % Get comments for each epoch
    for iSet = 1:nbSets
        % === GET EPOCH INFO ===
        % COMMENT
        iDir = find([sets(iSet).dir.kind] == FIFF.FIFF_COMMENT);
        if ~isempty(iDir)
            % Read comment tag
            tag = fiff_read_tag(fid, sets(iSet).dir(iDir).pos);
            epochComment = tag.data;
        end
        % SAMPLES INDICES
        iDirStart = find([sets(iSet).dir.kind] == FIFF.FIFF_FIRST_SAMPLE);
        iDirStop  = find([sets(iSet).dir.kind] == FIFF.FIFF_LAST_SAMPLE);
        if ~isempty(iDirStart) && ~isempty(iDirStop)
            % Read samples indices tag
            tagStart = fiff_read_tag(fid, sets(iSet).dir(iDirStart).pos);
            tagStop  = fiff_read_tag(fid, sets(iSet).dir(iDirStop).pos);
            epochSamples = [tagStart.data, tagStop.data];
            epochTimes   = double(epochSamples) ./ sFile.prop.sfreq;
        end
            
        % === GET ASPECTS INFO ===
        % Get the aspects (data, error, etc...)
        aspects  = fiff_dir_tree_find(sets(iSet),FIFF.FIFFB_ASPECT);
        nbAspects = length(aspects);
        % If some aspects defined
        if (nbAspects > 0)
            % Loop on all the aspects
            for iAspect = 1:nbAspects
                % Find Aspect type
                iAspectKind = find([aspects(iAspect).dir.kind] == FIFF.FIFF_ASPECT_KIND);
                if ~isempty(iAspectKind)
                    tag = fiff_read_tag(fid, aspects(iAspect).dir(iAspectKind).pos);
                    % Switch between different aspect types
                    switch(tag.data)
                        case FIFF.FIFFV_ASPECT_AVERAGE
                            aspectComment = [];
                        case FIFF.FIFFV_ASPECT_STD_ERR
                            aspectComment = 'std err';
                        case FIFF.FIFFV_ASPECT_SINGLE
                            aspectComment = 'single';
                        case FIFF.FIFFV_ASPECT_SUBAVERAGE
                            aspectComment = 'subavg';
                        case FIFF.FIFFV_ASPECT_ALTAVERAGE
                            aspectComment = 'altavg';
                        case FIFF.FIFFV_ASPECT_SAMPLE
                            aspectComment = 'sample';
                        case FIFF.FIFFV_ASPECT_POWER_DENSITY
                            aspectComment = 'pow dens';
                        case FIFF.FIFFV_ASPECT_DIPOLE_WAVE
                            aspectComment = 'wav';
                    end
                end
                % Get number of average
                iNave = find([aspects(iAspect).dir.kind] == FIFF.FIFF_NAVE);
                if ~isempty(iNave)
                    tag = fiff_read_tag(fid, aspects(iAspect).dir(iNave).pos);
                    epochs(iTotal).nAvg = tag.data;
                end
                % Final comment
                if ~isempty(aspectComment)
                    epochs(iTotal).label = [epochComment ' (' aspectComment ')'];
                else
                    epochs(iTotal).label = epochComment;
                end
                % Samples (start, stop)
                epochs(iTotal).times   = epochTimes;
                % Total indice of epoch/aspect
                iTotal = iTotal + 1;
            end
        % No aspects defined
        else
            epochs(iTotal).times = epochTimes;
            epochs(iTotal).label = epochComment;
            iTotal = iTotal + 1;
        end
    end
end



