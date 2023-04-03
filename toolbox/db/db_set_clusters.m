function OutputFiles = db_set_clusters(ChannelFile, Target, Clusters)
% DB_SET_CLUSTERS: Set the list of clusters saved in the channel files of target folders
%
% USAGE:  OutputFiles = db_set_clusters(ChannelFile, iDestStudies)   : Copy clusters from a channel file to the target folders
%         OutputFiles = db_set_clusters(ChannelFile, 'AllConditions'): Copy clusters from a channel file to all the folders in the same subject
%         OutputFiles = db_set_clusters(ChannelFile, 'AllSubjects')  : Copy clusters from a channel file to all the folders in all the subjects
%         OutputFiles = db_set_clusters(..., Clusters)               : Copy input clusters to the target studies (instead of reading then from input channel file)
%         OutputFiles = db_set_clusters(..., [])                     : Empty the list of clusters in the target studies

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
% Authors: Francois Tadel, 2023

OutputFiles = {};
% Parse inputs
if (nargin < 3)
    Clusters = [];
    isInputCluster = 0;
else
    isInputCluster = 1;
end

% ===== GET SOURCE STUDY =====
if ~isempty(ChannelFile)
    % Get study index
    [sSrcStudy, iSrcStudy] = bst_get('AnyFile', ChannelFile);
    if isempty(iSrcStudy)
        error(['Invalid channel file: ' ChannelFile]);
    end
    % Load channel file
    if ~isInputCluster
        ChannelMat = in_bst_channel(ChannelFile, 'Clusters');
        Clusters = ChannelMat.Clusters;
    end
else
    iSrcStudy = [];
end

% ===== GET TARGET STUDIES =====
if isnumeric(Target)
    % Destination studies are passed in argument
    iDestStudies = Target;
elseif strcmpi(Target, 'AllConditions')
    % Invalid combination of inputs
    if isempty(iSrcStudy)
        error('When using option ''AllConditions'', the first argument must be the path to a channel file.');
    end
    % Get all the studies for this subject
    [sDestStudies, iDestStudies] = bst_get('StudyWithSubject', sSrcStudy.BrainStormSubject);
elseif strcmpi(Target, 'AllSubjects')
    % Get the whole database
    ProtocolSubjects = bst_get('ProtocolSubjects');
    % Get list of subjects (sorted alphabetically => same order as in the tree)
    [uniqueSubjects, iUniqueSubjects] = sort({ProtocolSubjects.Subject.Name});
    % Process each subject
    iDestStudies = [];
    for iSubj = 1:length(uniqueSubjects)
        % Get subject filename
        iSubject = iUniqueSubjects(iSubj);
        SubjectFile = ProtocolSubjects.Subject(iSubject).FileName;
        % Get all the studies for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', SubjectFile, 'intra_subject', 'default_study');
        iDestStudies = [iDestStudies, iStudies];
    end
else 
    return;
end
% Remove the source study
if ~isempty(iSrcStudy)
    iDestStudies = setdiff(iDestStudies, iSrcStudy);
end
% If nothing to process: exit
if isempty(iDestStudies)
    disp('BST> Warning: db_set_cluster: No channel file to update.');
    return;
end
% Get channel files for target studies
DestChannelFiles = cell(1, length(iDestStudies));
for i = 1:length(iDestStudies)
    % Get channel file for study
    sChannel = bst_get('ChannelForStudy', iDestStudies(i));
    if ~isempty(sChannel)
        DestChannelFiles{i} = sChannel.FileName;
    end
end
% Remove empty items
iEmpty = find(cellfun(@isempty, DestChannelFiles));
if ~isempty(iEmpty)
    DestChannelFiles(iEmpty) = [];
end
% Keep only one each channel file name
DestChannelFiles = unique(DestChannelFiles);


% ===== SET CLUSTERS =====
% Process each target channel file
for iFile = 1:length(DestChannelFiles)
    % Get absolute file path
    ChannelFileFull = file_fullpath(DestChannelFiles{iFile});
    % Load file
    ChannelMat = load(ChannelFileFull);
    % If Clusters field is not defined yet, or if explicitly resetting the existing clusters
    if ~isfield(ChannelMat, 'Clusters') || isempty(ChannelMat.Clusters) || isempty(Clusters)
        ChannelMat.Clusters = repmat(db_template('cluster'), 1, 0);
    end
    % Add clusters
    for iClustSrc = 1:length(Clusters)
        % Replace existing cluster or creating a new one
        iClustDest = find(strcmpi({ChannelMat.Clusters.Label}, Clusters(iClustSrc).Label));
        if isempty(iClustDest)
            iClustDest = length(ChannelMat.Clusters) + 1;
        end
        % Copy cluster properties
        for f = fieldnames(Clusters)'
            ChannelMat.Clusters(iClustDest).(f{1}) = Clusters(iClustSrc).(f{1});
        end
    end
    % Save modifications
    bst_save(ChannelFileFull, ChannelMat, 'v7');
end
% Return modified channel files
OutputFiles = DestChannelFiles;
