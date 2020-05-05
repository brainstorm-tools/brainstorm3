function [sFile, ChannelMat, DataMat] = in_fopen_bstmat(DataFile)
% IN_FOPEN_BSTMAT: Open a Brainstorm imported structure/file
%
% USAGE:  [sFile, ChannelMat, DataMat] = in_fopen_bstmat(DataFile)

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
% Authors: Francois Tadel, 2015


% Data file
if ischar(DataFile)
    % Load file
    DataMat = in_bst_data(DataFile);
    if isempty(DataMat)
        sFile = [];
        ChannelMat = [];
        return;
    end
    % Load channel file
    ChannelFile = bst_get('ChannelFileForStudy', DataFile);
    if ~isempty(ChannelFile)
        ChannelMat = in_bst_channel(ChannelFile);
    end
    FullPath = file_fullpath(DataFile);
% Data structure
else
    DataMat = DataFile;
    ChannelMat = [];
    FullPath = '';
end
% Generate a sFile structure that describes this database file
sFile = db_template('sfile');
sFile.filename = FullPath;
sFile.format   = 'BST-DATA';
sFile.device   = 'Brainstorm';
sFile.comment  = DataMat(1).Comment;
sFile.prop.times   = [DataMat(1).Time(1), DataMat(1).Time(end)];
sFile.prop.sfreq   = 1 ./ (DataMat(1).Time(2) - DataMat(1).Time(1));
sFile.prop.currCtfComp = 3;
sFile.prop.destCtfComp = 3;
if isfield(DataMat(1), 'Events') && ~isempty(DataMat(1).Events)
    sFile.events = DataMat(1).Events;
end
sFile.header.F    = DataMat(1).F;
sFile.channelflag = DataMat(1).ChannelFlag;




