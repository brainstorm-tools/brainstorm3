function varargout = process_extract_pthresh2( varargin )
% PROCESS_EXTRACT_PTHRESH2 Apply a statistical threshold from FilesA(stat) to a FilesB(regular file).
%
% USAGE:  OutputFiles = process_extract_pthresh2('Run', sProcess, sInput, sInput2)

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
% Authors: Francois Tadel, 2013-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Apply statistic threshold';
    sProcess.Category    = 'File2';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 140;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics#Directionality:_Difference_of_absolute_values';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    % Define options
    sProcess = process_extract_pthresh('DefineOptions', sProcess);
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_extract_pthresh('FormatComment', sProcess);
end



%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput, sInput2) %#ok<DEFNU>
    % Get options
    [StatThreshOptions, strCorrect] = process_extract_pthresh('GetOptions', sProcess);
    % Load stat result (FileA)
    [sFileA, matNameA] = in_bst(sInput.FileName);
    % Load file to threshold (FileB)
    [sFileB, matNameB] = in_bst(sInput2.FileName);
    % Check that the two files have the same type and dimensions
    sizeMat = size(sFileA.(matNameA));
    if ~isequal(sizeMat, size(sFileB.(matNameB)))
        bst_report('Error', sProcess, [sInput, sInput2], 'File sizes do not match.');
        return;
    end
    
    % Process separately the types of files
    switch (sInput.FileType)
        case 'pdata'
            % Load channel file
            ChannelMat = in_bst_channel(sInput.ChannelFile);
            % Get only relevant sensors as multiple tests
            iChannels = good_channel(ChannelMat.Channel, sFileA.ChannelFlag, {'MEG', 'EEG', 'SEEG', 'ECOG', 'NIRS'});
            if isfield(sFileA, 'pmap') && ~isempty(sFileA.pmap)
                sFileA.pmap = sFileA.pmap(iChannels,:,:);
            end
            if isfield(sFileA, 'tmap') && ~isempty(sFileA.tmap)
                sFileA.tmap = sFileA.tmap(iChannels,:,:);
            end
            % Create a new data file structure
            pmask = zeros(sizeMat);
            pmask(iChannels,:) = (process_extract_pthresh('Compute', sFileA, StatThreshOptions) ~= 0);
            
        case {'presults', 'ptimefreq', 'pmatrix'}
            pmask = (process_extract_pthresh('Compute', sFileA, StatThreshOptions) ~= 0);
    end
    
    % Apply threshold mask to the data file
    sFileB.(matNameB) = sFileB.(matNameB) .* pmask;
    % Update file comment
    sFileB.Comment = [sFileB.Comment ' | ' strCorrect];
    % Add history entry
    sFileB = bst_history('add', sFileB, 'pthresh', ['Setting the stat threshold: ' strCorrect]);
    sFileB = bst_history('add', sFileB, 'pthresh', ['Stat file: ' sInput.FileName]);
    sFileB = bst_history('add', sFileB, 'pthresh', ['Data file: ' sInput2.FileName]);
    % Output filename
    [fPath, fBase, fExt] = bst_fileparts(file_fullpath(sInput2.FileName));
    DataFile = file_unique(fullfile(fPath, [fBase, '_pthresh', fExt]));
    % Save on disk
    bst_save(DataFile, sFileB, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, DataFile, sFileB);
    % Return data file
    OutputFiles{1} = DataFile;
end




