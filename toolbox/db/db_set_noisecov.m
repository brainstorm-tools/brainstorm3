function OutputFiles = db_set_noisecov(iSrcStudy, Target, isDataCov, ReplaceFile)
% DB_SET_NOISECOV: Apply a noise covariance node to other studies
%
% USAGE:  OutputFiles = db_set_noisecov(iSrcStudy, iDestStudies, isDataCov=0, ReplaceFile=[ask])  : Apply to the target studies
%         OutputFiles = db_set_noisecov(iSrcStudy, 'AllConditions')                               : Apply to all the conditons in the same subject
%         OutputFiles = db_set_noisecov(iSrcStudy, 'AllSubjects')                                 : Apply to all the conditons in all the subjects

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
% Authors: Francois Tadel, 2009-2016

% Parse inputs
if (nargin < 4) || isempty(ReplaceFile)
    ReplaceFile = [];
end
if (nargin < 3) || isempty(isDataCov)
    isDataCov = 0;
end
OutputFiles = {};

% ===== GET SOURCE STUDY =====
% Get source study
sSrcStudy = bst_get('Study', iSrcStudy);
% Check for noise covariance matrix
if isempty(sSrcStudy.Channel)
    error('This operation requires that you have a channel file defined in the source and destination studies.');
end
if isempty(sSrcStudy.NoiseCov) || (~isDataCov && isempty(sSrcStudy.NoiseCov(1).FileName)) || (isDataCov && ((length(sSrcStudy.NoiseCov) < 2) || isempty(sSrcStudy.NoiseCov(2).FileName)))
    error('No noise covariance available in the source study.');
end
    
% ===== GET TARGET STUDIES =====
if isnumeric(Target)
    % Destination studies are passed in argument
    iDestStudies = Target;
elseif strcmpi(Target, 'AllConditions')
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
% Get the channels studies for those studies
[sDestChannels, iDestChanStudies] = bst_get('ChannelForStudy', iDestStudies);
% Unique list
iDestChanStudies = unique(iDestChanStudies);
% Remove the one the NoiseCov file comes from
iDestChanStudies = setdiff(iDestChanStudies, iSrcStudy);
% If there are no targets
if isempty(iDestChanStudies)
    error('No destination studies.');
end

% ===== READ SOURCE DATA =====
% Load noisecov file
if isDataCov
    SrcNoiseCovMat = load(file_fullpath(sSrcStudy.NoiseCov(2).FileName));
else
    SrcNoiseCovMat = load(file_fullpath(sSrcStudy.NoiseCov(1).FileName));
end
% Load channel file
SrcChannelMat = in_bst_channel(sSrcStudy.Channel.FileName);

% ===== APPLY NOISECOV =====
% Process each target study
for i = 1:length(iDestChanStudies)
    % Get destination study
    iDestStudy = iDestChanStudies(i);
    sDestStudy = bst_get('Study', iDestStudy);
    % If no channel defined: ignore destination channel
    if isempty(sDestStudy.Channel) || isempty(sDestStudy.Channel.FileName)
        disp(['BST> Warning: No channel file in ' bst_fileparts(sDestStudy.FileName) ': Ignoring condition...']);
        continue;
    end
    % Load destination channel file
    DestChannelMat = in_bst_channel(sDestStudy.Channel.FileName);
    % Intialize destination noise covariance matrix
    nbDestChan = length(DestChannelMat.Channel);
    DestNoiseCovMat = SrcNoiseCovMat;
    DestNoiseCovMat.NoiseCov = zeros(nbDestChan);
    
    % Find the indices of src channels in dest channels
    iSrcChan = [];
    iDestChan = [];
    for iChan = 1:nbDestChan
        iTmp = find(strcmpi({SrcChannelMat.Channel.Name}, DestChannelMat.Channel(iChan).Name));
        if ~isempty(iTmp) && ~isempty(DestChannelMat.Channel(iChan).Name)
            iDestChan(end+1) = iChan;
            iSrcChan(end+1) = iTmp(1);
        end
    end
    
    % If some channels were the same in both files
    if ~isempty(iDestChan)
        DestNoiseCovMat.NoiseCov(iDestChan,iDestChan) = SrcNoiseCovMat.NoiseCov(iSrcChan,iSrcChan);
        % Other fields
        if isfield(SrcNoiseCovMat, 'FourthMoment') && ~isempty(SrcNoiseCovMat.FourthMoment)
            DestNoiseCovMat.FourthMoment = zeros(nbDestChan);
            DestNoiseCovMat.FourthMoment(iDestChan,iDestChan) = SrcNoiseCovMat.FourthMoment(iSrcChan,iSrcChan);
        end
        if isfield(SrcNoiseCovMat, 'nSamples') && ~isempty(SrcNoiseCovMat.nSamples)
            DestNoiseCovMat.nSamples = zeros(nbDestChan);
            DestNoiseCovMat.nSamples(iDestChan,iDestChan) = SrcNoiseCovMat.nSamples(iSrcChan,iSrcChan);
        end
        % Copy this structure in all the target studies
        NewFile = import_noisecov(iDestStudy, DestNoiseCovMat, ReplaceFile, isDataCov);
        if ~isempty(NewFile) && ischar(NewFile)
            OutputFiles{end+1} = NewFile;
        end
    end
end

    



