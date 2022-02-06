function [Projector, errMsg] = import_ssp(ChannelFile, SspFiles, ApplyToData, SaveChannelFile, strComment)
% IMPORT_SSP: Reads SSP projectors from a list of FIF files, add it to the channel file and to all the dependant data.
%
% USAGE:  [Projector, errMsg] = import_ssp(ChannelFile, SspFiles, ApplyToData, SaveChannelFile, strComment)
%         [Projector, errMsg] = import_ssp(ChannelFile, Projector, ApplyToData, SaveChannelFile, strComment)
%         [Projector, errMsg] = import_ssp(ChannelFile)

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
% Authors: Lucie Charles, Francois Tadel, 2010-2015

%% ===== PARSE INPUTS =====
Projector = [];
errMsg = [];
if (nargin < 5)
    strComment = [];
end
if (nargin < 4)
    SaveChannelFile = 1;
end
if (nargin < 3)
    ApplyToData = [];
end
if (nargin < 2)
    SspFiles = {};
elseif ~ischar(SspFiles)
    Projector = SspFiles;
    SspFiles = [];
end
% Detect file format
if ~isempty(SspFiles)
    % Get the file extenstion
    [fPath, fBase, fExt] = bst_fileparts(SspFiles{1});
    if ~isempty(fExt)
        % Detect file format by extension
        switch lower(fExt)
            case 'fif', FileFormat = 'FIF';
            case 'mat', FileFormat = 'BST';
            otherwise,  FileFormat = 'ASCII';
        end
    end
end
% Load existing channel file
if (nargin >= 1) && ~isempty(ChannelFile)
    ChannelMat = in_bst_channel(ChannelFile);
else
    ChannelFile = [];
    ChannelMat = [];
    ApplyToData = 0;
end


%% ===== SELECT SSP FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(SspFiles) && isempty(Projector)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get default format
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.SspIn)
        DefaultFormats.SspIn = 'BST';
    end
    % Get MRI file
    [SspFiles, FileFormat] = java_getfile('open', ...
            'Import SSP files...', ...         % Window title
            LastUsedDirs.ImportChannel, ...   % Last used directory
            'multiple',    'files', ...       % Selection mode
            {{'.fif'},     'Elekta-Neuromag/MNE (*.fif)',       'FIF'; ...
             {'_channel','_proj'}, 'Brainstorm (channel_*.mat; proj_*.mat)',  'BST'; ...
             {'*'},        'ASCII (*.*)',                'ASCII' ...
            }, DefaultFormats.SspIn);
    % If no file was selected: exit
    if isempty(SspFiles)
        return;
    end
    % Save default import directory
    LastUsedDirs.ImportChannel = bst_fileparts(SspFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.SspIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


%% ===== LOAD PROJECTORS =====
isProgress = bst_progress('isVisible');
% Read from file
if isempty(Projector)
    if ~isProgress
        bst_progress('start', 'Import SSP projectors', 'Load SSP files...');
    else
        bst_progress('text', 'Load SSP files...');
    end
    % FIF format: multiple files handled in in_projector_fif
    if strcmpi(FileFormat, 'FIF')
        % Read projectors from FIF file
        Projector = in_projector_fif(SspFiles, {ChannelMat.Channel.Name});
    % Other formats: multiply all the projectors
    else
        newProj = [];
        Projector = [];
        % Load all the SSP projections
        for iFile = 1:length(SspFiles)
            % Load SSP from the file #iFile
            switch (FileFormat)
                case 'BST'
                    % Load file
                    ProjMat = in_bst_channel(SspFiles{iFile}, 'Projector', 'RowNames');
                    if ~isempty(ChannelMat) && ~isempty(ProjMat.Projector) && ~isempty(ProjMat.RowNames) % && isfield(ProjMat, 'RowNames'), always because we ask for it explicitly
                        [ProjMat, errMsg] = VerifyProjectorChannels(ChannelMat, ProjMat);
                        if ~isempty(errMsg)
                            return;
                        end
                    end
                    % Get projectors
                    newProj = ProjMat.Projector;
                case 'ASCII'
                    % Load file as ASCII
                    newProj = load(SspFiles{iFile}, '-ascii');
            end
            if isempty(newProj)
                disp(['SSP> Warning: No projections in the file "' SspFiles{iFile} '"']);
                continue;
            end
            % Combine new projector with the previous ones
            if isempty(Projector)
                Projector = newProj;
            else
                Projector = [Projector, newProj];
            end
        end
    end
end
% Force new Projector matrix to be in the new projector format
if ~isempty(Projector) && ~isstruct(Projector)
    Projector = process_ssp2('ConvertOldFormat', Projector);
end
% Check if there is actually something to apply
if isempty(Projector)
    errMsg = 'No new projectors to apply.';
    bst_progress('stop');
    return;
end
% Check the number of channels
if ~isempty(ChannelFile) && ~isempty(ChannelMat)
    nChanProj = size(Projector(1).Components, 1);
    nChanFile = length(ChannelMat.Channel);
    if (nChanProj ~= nChanFile)
        errMsg = sprintf('There are %d channels, but %d rows in the projector.', nChanFile, nChanProj);
        Projector = [];
        return;
    end
end
% If there is no channel file defined: stop here, after reading the file
if isempty(ChannelFile) || ~SaveChannelFile
    bst_progress('stop');
    return
end


%% ===== GET DATA FILES =====
if ~isProgress
    bst_progress('start', 'Import SSP projectors', 'Apply new projectors...');
end
% Get all the data file concerned by this channel file
DataFiles = bst_get('DataForChannelFile', ChannelFile);
% No data: nothing to apply
if isempty(DataFiles)
    ApplyToData = 0;
% If all of the data files are raw files, nothing to apply
else
    isRaw = ~cellfun(@(c)isempty(strfind(c, '_0raw')), DataFiles);
    if all(isRaw)
        ApplyToData = 0;
    end
end
% Ask before if user want to apply it to the data
if isempty(ApplyToData) % || (any(isRaw) && ~all(isRaw))
    res = java_dialog('question', ['Would you like to apply all these projections ' 10 ...
                                   'to the recordings already imported in the database?'], ...
                      'Import SSP projectors', [], {'Yes', 'No', 'Cancel'}, 'Yes');
    if isempty(res) || strcmpi(res, 'Cancel')
        bst_progress('stop');
        return
    end
    ApplyToData = strcmpi(res, 'Yes');
end


%% ===== APPLY TO CHANNEL FILE =====
% Add projector to the channel file
if ~isfield(ChannelMat, 'Projector') || isempty(ChannelMat.Projector)
    ChannelMat.Projector = Projector;
else
    ChannelMat.Projector = [ChannelMat.Projector, Projector];
end
% History: Added SSP
for iProj = 1:length(Projector)
    ChannelMat = bst_history('add', ChannelMat, 'ssp', ['Added SSP: ' Projector(iProj).Comment]);
    if ~isempty(strComment)
        ChannelMat = bst_history('add', ChannelMat, 'ssp', strComment);
    end
end
% Save modified channel file
bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');


%% ===== APPLY TO DATA =====
if ApplyToData
    % Build final form of the projectors
    P = process_ssp2('BuildProjector', Projector, [0 1 2]);
    if ~isempty(P)
        iNonRaw = find(~isRaw);
%         % Process all the data files
%         for i = 1:length(iNonRaw)
%             iFile = iNonRaw(i);
%             % Load file
%             DataFile = file_fullpath(DataFiles{iFile});
%             DataMat = in_bst_data(DataFile);
%             % Imported data files: Multiply the F matrix by the projector
%             DataMat.F = P * DataMat.F;
%             % History: Added SSP
%             for iProj = 1:length(Projector)
%                 DataMat = bst_history('add', DataMat, 'ssp', ['Added SSP: ' Projector(iProj).Comment]);
%             end
%             % Save modified file
%             bst_save(DataFile, DataMat, 'v6');
%         end
        % Display warning
        if ~isempty(iNonRaw)
            disp(['BST> Warning: The channel file in which the new SSP were saved is shared by ' num2str(length(iNonRaw)) ' imported files.']);
            disp('BST>          The SSP are not applied to these files, you may have to re-import your data.');
        end
    end
end
if ~isProgress
    bst_progress('stop');
end

end

function [ProjMat, errMsg] = VerifyProjectorChannels(ChannelMat, ProjMat)
    errMsg = [];
    % Check consistency
    if numel(ProjMat.RowNames) ~= size(ProjMat.Projector(1).Components, 1)
        errMsg = 'Inconsistent number of projector channel names.';
        ProjMat = [];
        return;
    end
    % Find channels involved. If any are missing in ChannelMat, the
    % projector is not valid.
    iProjNeeded = find(any(ProjMat.Projector(1).Components ~= 0, 2));
    [isChanInProj, iProjPresent] = ismember({ChannelMat.Channel.Name}, ProjMat.RowNames);
    % Remove zeros for those not found.
    iProjPresent(iProjPresent == 0) = [];
    Missing = ~ismember(iProjNeeded, iProjPresent);
    if any(Missing)
        Example = ProjMat.RowNames{iProjNeeded(find(Missing, 1))};
        errMsg = sprintf('Projector contains channels not present in channel file (e.g. %s).', Example);
        ProjMat = [];
        return;
    end
    if numel(ChannelMat.Channel) > size(ProjMat.Projector(1).Components, 1)
        for p = 1:numel(ProjMat.Projector)
            % Add rows or zeros for additional channels.
            tempProj = zeros(numel(ChannelMat.Channel), size(ProjMat.Projector(p).Components, 2));
            tempProj(isChanInProj, :) = ProjMat.Projector(p).Components(iProjPresent, :);
            ProjMat.Projector(p).Components = tempProj;
        end
    end
end


