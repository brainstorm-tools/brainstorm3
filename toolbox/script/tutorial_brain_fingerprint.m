function tutorial_brain_fingerprint(ProtocolNameOmega, reports_dir)
% TUTORIAL_BRAIN_FINGERPRINT: Script that reproduces the results of the online tutorial "Brain-fingerprint".
%
% CORRESPONDING ONLINE TUTORIAL:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/BrainFingerprint
%
% INPUTS:
%    - ProtocolNameOmega : Name of the protocol created with all the data imported (TutorialOmega)
%    - reports_dir       : Directory where to save the execution report (instead of displaying it)
%
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
% Author: Jason da Silva Castanheira, Raymundo Cassani, 2024


%% ===== CHECK PROTOCOL =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin < 1) || isempty(ProtocolNameOmega)
    ProtocolNameOmega = 'TutorialOmega';
end

% Check Protocol that it exists
iProtocolOmega = bst_get('Protocol', ProtocolNameOmega);
if isempty(iProtocolOmega)
    error(['Unknown protocol: ' ProtocolNameOmega]);
end
% Select input protocol
gui_brainstorm('SetCurrentProtocol', iProtocolOmega);


%% ===== BRAIN-FINGERPRINT PARAMETERS =====
SubjectNames = {'sub-0002', 'sub-0003', 'sub-0004', 'sub-0006', 'sub-0007'};
nSubjects = length(SubjectNames);
LowerFreq =   4; % Hz, inclusive
UpperFreq = 150; % Hz, exclusive

% Verify the Subjects
ProtocolSubjects = bst_get('ProtocolSubjects');
ProtocolSubjectNames = {ProtocolSubjects.Subject.Name};
if ~all(ismember(SubjectNames, ProtocolSubjectNames))
    error(['All requested subjects must be present in the ' ProtocolNameOmega ' protocol.']);
end


%% ===== FIND FILES =====
bst_report('Start');

% Get raw and source files for each Subject
sRawDataFiles = [];
sSourcesFiles = [];

for iSubject = 1 : nSubjects
    % Process: Select data files in: sub-000*/*
    sFiles = bst_process('CallProcess', 'process_select_files_data', [], [], ...
        'subjectname',   SubjectNames{iSubject}, ...
        'condition',     '', ...
        'tag',           '', ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);
    sRawDataFiles = [sRawDataFiles, sFiles];

    % Process: Select results files in: sub-000*/*
    sFiles = bst_process('CallProcess', 'process_select_files_results', [], [], ...
        'subjectname',   SubjectNames{iSubject}, ...
        'condition',     '', ...
        'tag',           '', ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);
    sSourcesFiles = [sSourcesFiles, sFiles];
end


%% Compute PSD for all ROIs of an atlas (example below Destrieux)
% For each subject, their recordings are split in two parts
% these two recordings segments will be used to create PSDs that are the
% features which will define the brain-fingerprint

nSegments = 2; % Training and Validation
timeIni   = zeros(nSubjects, nSegments);
timeFin   = zeros(nSubjects, nSegments);
sPsdFiles = repmat(db_template('processfile'), nSubjects, nSegments);
for iSubject = 1 : nSubjects
    sData = load(file_fullpath(sRawDataFiles(iSubject).FileName), 'Time');
    halfTime = diff(sData.Time) / 2;
    % First segment
    timeIni(iSubject, 1) = sData.Time(1) + 30;
    timeFin(iSubject, 1) = halfTime      - 30;
    % Second segment
    timeIni(iSubject, 2) = halfTime      + 30;
    timeFin(iSubject, 2) = sData.Time(2) - 30;
    % Compute PSD
    for iSegment = 1 : size(timeIni, 2)
        % Process: Power spectrum density (Welch)
        sPsdFiles(iSubject, iSegment) = bst_process('CallProcess', 'process_psd', sSourcesFiles(iSubject).FileName, [], ...
            'timewindow',  [timeIni(iSubject, iSegment), timeFin(iSubject, iSegment)], ...
            'win_length',  2, ...
            'win_overlap', 50, ...
            'units',       'physical', ...  % Physical: U2/Hz
            'clusters',    {'Destrieux', {'G_Ins_lg_and_S_cent_ins L', 'G_Ins_lg_and_S_cent_ins R', 'G_and_S_cingul-Ant L', 'G_and_S_cingul-Ant R', 'G_and_S_cingul-Mid-Ant L', 'G_and_S_cingul-Mid-Ant R', 'G_and_S_cingul-Mid-Post L', 'G_and_S_cingul-Mid-Post R', 'G_and_S_frontomargin L', 'G_and_S_frontomargin R', 'G_and_S_occipital_inf L', 'G_and_S_occipital_inf R', 'G_and_S_paracentral L', 'G_and_S_paracentral R', 'G_and_S_subcentral L', 'G_and_S_subcentral R', 'G_and_S_transv_frontopol L', 'G_and_S_transv_frontopol R', 'G_cingul-Post-dorsal L', 'G_cingul-Post-dorsal R', 'G_cingul-Post-ventral L', 'G_cingul-Post-ventral R', 'G_cuneus L', 'G_cuneus R', 'G_front_inf-Opercular L', 'G_front_inf-Opercular R', 'G_front_inf-Orbital L', 'G_front_inf-Orbital R', 'G_front_inf-Triangul L', 'G_front_inf-Triangul R', 'G_front_middle L', 'G_front_middle R', 'G_front_sup L', 'G_front_sup R', 'G_insular_short L', 'G_insular_short R', 'G_oc-temp_lat-fusifor L', 'G_oc-temp_lat-fusifor R', 'G_oc-temp_med-Lingual L', 'G_oc-temp_med-Lingual R', 'G_oc-temp_med-Parahip L', 'G_oc-temp_med-Parahip R', 'G_occipital_middle L', 'G_occipital_middle R', 'G_occipital_sup L', 'G_occipital_sup R', 'G_orbital L', 'G_orbital R', 'G_pariet_inf-Angular L', 'G_pariet_inf-Angular R', 'G_pariet_inf-Supramar L', 'G_pariet_inf-Supramar R', 'G_parietal_sup L', 'G_parietal_sup R', 'G_postcentral L', 'G_postcentral R', 'G_precentral L', 'G_precentral R', 'G_precuneus L', 'G_precuneus R', 'G_rectus L', 'G_rectus R', 'G_subcallosal L', 'G_subcallosal R', 'G_temp_sup-G_T_transv L', 'G_temp_sup-G_T_transv R', 'G_temp_sup-Lateral L', 'G_temp_sup-Lateral R', 'G_temp_sup-Plan_polar L', 'G_temp_sup-Plan_polar R', 'G_temp_sup-Plan_tempo L', 'G_temp_sup-Plan_tempo R', 'G_temporal_inf L', 'G_temporal_inf R', 'G_temporal_middle L', 'G_temporal_middle R', 'Lat_Fis-ant-Horizont L', 'Lat_Fis-ant-Horizont R', 'Lat_Fis-ant-Vertical L', 'Lat_Fis-ant-Vertical R', 'Lat_Fis-post L', 'Lat_Fis-post R', 'Pole_occipital L', 'Pole_occipital R', 'Pole_temporal L', 'Pole_temporal R', 'S_calcarine L', 'S_calcarine R', 'S_central L', 'S_central R', 'S_cingul-Marginalis L', 'S_cingul-Marginalis R', 'S_circular_insula_ant L', 'S_circular_insula_ant R', 'S_circular_insula_inf L', 'S_circular_insula_inf R', 'S_circular_insula_sup L', 'S_circular_insula_sup R', 'S_collat_transv_ant L', 'S_collat_transv_ant R', 'S_collat_transv_post L', 'S_collat_transv_post R', 'S_front_inf L', 'S_front_inf R', 'S_front_middle L', 'S_front_middle R', 'S_front_sup L', 'S_front_sup R', 'S_interm_prim-Jensen L', 'S_interm_prim-Jensen R', 'S_intrapariet_and_P_trans L', 'S_intrapariet_and_P_trans R', 'S_oc-temp_lat L', 'S_oc-temp_lat R', 'S_oc-temp_med_and_Lingual L', 'S_oc-temp_med_and_Lingual R', 'S_oc_middle_and_Lunatus L', 'S_oc_middle_and_Lunatus R', 'S_oc_sup_and_transversal L', 'S_oc_sup_and_transversal R', 'S_occipital_ant L', 'S_occipital_ant R', 'S_orbital-H_Shaped L', 'S_orbital-H_Shaped R', 'S_orbital_lateral L', 'S_orbital_lateral R', 'S_orbital_med-olfact L', 'S_orbital_med-olfact R', 'S_parieto_occipital L', 'S_parieto_occipital R', 'S_pericallosal L', 'S_pericallosal R', 'S_postcentral L', 'S_postcentral R', 'S_precentral-inf-part L', 'S_precentral-inf-part R', 'S_precentral-sup-part L', 'S_precentral-sup-part R', 'S_suborbital L', 'S_suborbital R', 'S_subparietal L', 'S_subparietal R', 'S_temporal_inf L', 'S_temporal_inf R', 'S_temporal_sup L', 'S_temporal_sup R', 'S_temporal_transverse L', 'S_temporal_transverse R'}}, ...
            'scoutfunc',   1, ...  % Mean
            'win_std',     0, ...
            'edit',        struct(...
                 'Comment',         'Scouts,Power', ...
                 'TimeBands',       [], ...
                 'Freqs',           [], ...
                 'ClusterFuncTime', 'before', ...
                 'Measure',         'power', ...
                 'Output',          'all', ...
                 'SaveKernel',      0));
    end
end


%% ===== VECTORIZE PSD DATA FOR FINGERPRINTING =====
% Find size of requested PSD data
sPsdMat = in_bst_timefreq(sPsdFiles(1,1).FileName, 0, 'RowNames', 'Freqs');
ixLowerFreq = find(sPsdMat.Freqs >= LowerFreq, 1, 'first');
ixUpperFreq = find(sPsdMat.Freqs <  UpperFreq, 1, 'last');
nFreqs = (ixUpperFreq - ixLowerFreq + 1);

% Subject vectors
trainingVectors   = zeros(iSubject, length(sPsdMat.RowNames) * nFreqs);
validationVectors = zeros(iSubject, length(sPsdMat.RowNames) * nFreqs);

% Vectorize Scout PSDs
for iSubject = 1 : nSubjects
    for iSegment = 1 : nSegments
        sPsdMat = in_bst_timefreq(sPsdFiles(iSubject, iSegment).FileName, 0, 'TF');
        if iSegment == 1
            trainingVectors(iSubject,:) = reshape(squeeze(sPsdMat.TF(:, :, ixLowerFreq:ixUpperFreq)), 1, []);
        elseif iSegment == 2
            validationVectors(iSubject,:) = reshape(squeeze(sPsdMat.TF(:, :, ixLowerFreq:ixUpperFreq)), 1, []);
        end
    end
end


%% ==== SIMILARITY AND DIFFERENCTIABILITY =====
% Subject similarity matrix
% It is generally symetric although it does not necessairly have to be!
SubjectCorrMatrix= corr(trainingVectors', validationVectors');
% Differentiability
diff_1= (diag(SubjectCorrMatrix)-mean(SubjectCorrMatrix,1) )/ std(SubjectCorrMatrix,0,1);  % along columns
diff_2= (diag(SubjectCorrMatrix)-mean(SubjectCorrMatrix,2)')/ std(SubjectCorrMatrix,0,2)'; % along rows
% Differentiability across rows and columns are generally strongly correlated
Differentiability = (diff_1 + diff_2)/2; % Mean differentiability derrived from rows and columns

%% ===== SAVE OUTCOME IN BRAINSTORM DATABASE =====
% Study to save files
[sOutputStudy, iOutputStudy] = bst_get('StudyWithCondition', bst_fullfile(bst_get('NormalizedSubjectName'), bst_get('DirAnalysisIntra')));

% Similarity matrix
sSimilarityMat = db_template('timefreqmat');
% Reshape: [nA x nB x nTime x nFreq] => [nA*nB x nTime x nFreq]
sSimilarityMat.TF = reshape(SubjectCorrMatrix, [], 1, 1);
sSimilarityMat.Comment      = 'Similarity matrix';
sSimilarityMat.DataType     = 'matrix';
sSimilarityMat.Time     = [0, 1];
sSimilarityMat.RefRowNames = cellfun(@(x) ['Train ', x], SubjectNames, 'UniformOutput', false);
sSimilarityMat.RowNames    = cellfun(@(x) ['Validation ', x], SubjectNames, 'UniformOutput', false);
% Output filename
SimilarityFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'timefreq_connectn_corr');
% Save file
bst_save(SimilarityFile, sSimilarityMat, 'v6');
% Add file to database structure
db_add_data(iOutputStudy, SimilarityFile, sSimilarityMat);

% Differentiability matrix
sDiffMat = db_template('matrixmat');
sDiffMat.Value   = Differentiability;
sDiffMat.Comment = 'Differentiability';
sDiffMat.Time     = [0, 1];
sDiffMat.Description = SubjectNames;
% Output filename
DiffFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'matrix');
% Save file
bst_save(DiffFile, sDiffMat, 'v6');
% Add file to database structure
db_add_data(iOutputStudy, DiffFile, sDiffMat);

% Reload database
db_reload_studies(iOutputStudy)


%% ===== SNAPSHOTS =====
% Process: Snapshot: Similarity matrix
bst_process('CallProcess', 'process_snapshot', SimilarityFile, [], ...
    'type',    'connectimage', ...  % Connectivity matrix
    'Comment', 'Similarity matrix');

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', DiffFile, [], ...
    'type',           'data', ...  % Recordings time series
    'time',           0, ...
    'Comment',        'Differentiability');

% Save report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end