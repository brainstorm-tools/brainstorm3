function Projector = in_projector_fif( SspFiles, ChannelNames )
% IN_PROJECTOR_FIF: Read a FIF file, and return a brainstorm Channel structure.
%
% USAGE:  Projector = in_projector_fif( SspFile, ChannelNames );
%         Projector = in_projector_fif( projs, ChannelNames );

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
% Authors: Francois Tadel, 2010-2012

global FIFF;

%% ===== PARSE INPUTS =====
if ischar(SspFiles)
    SspFiles = {SspFiles};
end
% Remove spaces in all the channel names
tmp = ChannelNames;
ChannelNames = cellfun(@(c)upper(c(c~=' ')), ChannelNames, 'UniformOutput', 0);


%% ===== READ PROJECTORS =====
projs = [];
% Read files
if iscell(SspFiles)
    % Loop on all files
    for i = 1:length(SspFiles)
        % Open SSP file
        [ fid, tree ]  = fiff_open(SspFiles{i});
        if (fid < 0)
            error(['Cannot open FIFF file : "' SspFiles{i} '"']);
        end
        % Read projectors
        node = fiff_dir_tree_find(tree, FIFF.FIFFB_PROJ);
        newProjs = fiff_read_proj(fid, node);
        % Add projectors to list of all projectors to combine
        if isempty(projs)
            projs = newProjs;
        else
            projs = [projs, newProjs];
        end
        % Close SSP file
        fclose(fid);
    end
% Projectors already loaded
elseif isstruct(SspFiles)
    projs = SspFiles;
else
    error('Invalid input.');
end


%% ====== BUILD PROJECTION MATRIX =====
Projector = repmat(db_template('projector'), 0);
nChannels = length(ChannelNames);
% Collect all the projections from the FIF file
for i = 1:length(projs)
    % Check type of the projector
    if (projs(i).kind ~= FIFF.FIFFV_PROJ_ITEM_FIELD)
        fprintf(1, 'SSP> Unsupported type of projector #%d: "%s". Skipping...\n', projs(i).kind, projs(i).desc);
        continue;
    end
    % Copy basic information
    iNew = length(Projector) + 1;
    Projector(iNew).Comment = projs(i).desc;
    if projs(i).active
        Projector(iNew).Status = 2;  % Recordings in the file saved this way
    else
        Projector(iNew).Status = 1;  % Projector is selected and applied dynamically to the recordings
    end
    % Get the projectors values
    data = projs(i).data;
    % Remove the spaces in the channel names
    data.col_names = cellfun(@(c)upper(c(c~=' ')), data.col_names, 'UniformOutput', 0);
    % Copy the information of each channel
    U = zeros(nChannels, data.nrow);
    for iCol = 1:data.ncol
        iChan = find(strcmpi(data.col_names{iCol}, ChannelNames));
        if isempty(iChan)
            % Channel not found
            continue;
        elseif (length(iChan) > 1)
            disp('IN> Warning: Several channels have the same name, the result might be random...');
            iChan = iChan(1);
        end
        U(iChan,:) = data.data(:,iCol)';
    end
    % Finish filling the entry
    Projector(iNew).Components = U;
    Projector(iNew).CompMask   = ones(1,data.nrow);
end




