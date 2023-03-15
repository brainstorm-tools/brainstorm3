function [sFile, ChannelMat, DataMat] = in_fopen_bstmatrix(MatFile)
% IN_FOPEN_BSTMATTRIX: Open a Brainstorm matrix file as DataFile
%
% USAGE:  [sFile, ChannelMat, DataMat] = in_fopen_bstmatrix(MatFile)

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
% Authors: Raymundo Cassani, 2023

sFile      = [];
ChannelMat = [];
DataMat    = [];
% Data file
if ischar(MatFile)
    % Load matrix file
    MatrixMat = in_bst_matrix(MatFile);
    if isempty(MatrixMat)
        return;
    end
    FullPath = file_fullpath(MatFile);
else
    MatrixMat = MatFile;
    FullPath = '';
end
% Generate DataMat structure
DataMat = db_template('datamat');
nSignals = size(MatrixMat.Value, 1);
DataMat.F = MatrixMat.Value;
DataMat.Comment = MatrixMat.Comment;
DataMat.Time = MatrixMat.Time;
DataMat.Events = MatrixMat.Events;
DataMat.ChannelFlag = ones(1, nSignals);
% Generate ChannelMat structure
ChannelMat = db_template('channelmat');
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, nSignals);
for iSignal = 1 : nSignals
    ChannelMat.Channel(iSignal).Type = 'EEG';
    ChannelMat.Channel(iSignal).Name = MatrixMat.Description{iSignal};
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


