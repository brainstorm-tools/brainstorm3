function ChannelMat = in_channel_besa_eps(ChannelFile)
% IN_CHANNEL_BESA_EPS:  Read 3D cartesian positions for a set of electrodes from an couple .eps/ela BESA file.
%
% USAGE:  ChannelMat = in_channel_besa_eps(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the file (either .ela or .eps file)
%
% FORMAT:
%     - .ELA file: contains the labels
%     - .EPS file: contains the positions of the electrodes
            
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2012

% Check file extension
[fPath, fBase, fExt] = bst_fileparts(ChannelFile);
switch lower(fExt)
    case '.eps'
        epsFile = ChannelFile;
        elaFile = bst_fullfile(fPath, [fBase, '.ela']);
    case '.ela'
        elaFile = ChannelFile;
        epsFile = bst_fullfile(fPath, [fBase, '.eps']);
end
        
% ELP: Get the positions
if ~isempty(epsFile) && file_exist(epsFile)
    ChannelMat = in_channel_ascii(epsFile, {'-Y','X','Z'}, 0, .01);
    ChannelMat.Comment = 'BESA channels';
else
    disp('BESA> Error: EPS file is missing');
    ChannelMat = [];
end

% ELA: Get the labels/types
if ~isempty(elaFile) && file_exist(elaFile)
    % === READ FILE ===
    % Open file
    fid = fopen(elaFile, 'r');
    if (fid == -1)
        error('Cannot open .ela file.');
    end
    % Read file
    ela = textscan(fid, '%s %s');
    % Close file
    fclose(fid);
    
    % === FILE TYPE ===
    nChan = length(ela{1});
    % ONE column (channel names)
    if all(cellfun(@isempty, ela{2}))
        chLabels = ela{1};
        % By default, all channels are considered as EEG
        chTypes  = repmat({'EEG'}, [nChan, 1]);
    % TWO columns (channel types+names)
    else
        chTypes  = ela{1};
        chLabels = ela{2};
    end
        
    % === SET THE LABELS ===
    % Create an empty Channel structure if EPS file is missing
    if isempty(ChannelMat)
        ChannelMat = db_template('channelmat');
        ChannelMat.Comment = 'BESA channels';
        ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChan]);
        [ChannelMat.Channel.Loc] = deal([0;0;0]);
    end
    % Set the labels
    for i = 1:length(chLabels)
        ChannelMat.Channel(i).Name = chLabels{i};
    end
    % Set the types
    for i = 1:length(chLabels)
        ChannelMat.Channel(i).Type = chTypes{i};
    end
else
    disp('BESA> Error: ELA file is missing');
end






