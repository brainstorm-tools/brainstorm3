function OutputLinks = db_links(varargin)
% DB_LINKS: Update all the links to shared results files.
%
% USAGE:  OutputLinks = db_links('Subject', iSubject)
%         OutputLinks = db_links('Subject', SubjectFile)
%         OutputLinks = db_links('Study',   iStudiesList) : Process only the target studies (they must belong to the same subject)
%         OutputLinks = db_links()                        : Process all the subjects of the current protocol
%
% OUTPUT: List of links created

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
% Authors: Francois Tadel, 2008-2013

%% ===== PARSE INPUTS =====
OutputLinks = {};
% CALL: db_links()
if (nargin == 0)
    % Get subjects list
    sSubjectsList = bst_get('ProtocolSubjects');
    % Update results links for global default study
    db_links('Subject', 0);
    % For all other subjects
    for iSubject = 1:length(sSubjectsList.Subject)
        % If subject do not share channel file (already processed)
        %if (sSubjectsList.Subject(iSubject).UseDefaultChannel ~= 0)
            % Update results links for subject
            db_links('Subject', iSubject);
        %end
    end
    % Hide progress bar
    %bst_progress('stop');
    return
% CALL: db_links('Subject', ...)
elseif (nargin == 2) && ischar(varargin{1}) && strcmpi(varargin{1}, 'Subject')
    % CALL: db_links('Subject', SubjectFile)
    if ischar(varargin{2})
        SubjectFile = varargin{2};
        [sSubject, iSubject] = bst_get('Subject', SubjectFile, 1);
    % CALL: db_links('Subject', iSubject)
    else
        iSubject = varargin{2};
        if (length(iSubject) > 1)
            error('Cannot process more than one subject.');
        end
        sSubject = bst_get('Subject', iSubject, 1);
    end
    % Check for weird bugs
    if isempty(sSubject)
        warning('Default subject cannot be reached for this protocol.');
        return
    end
    % Get all the studies related for this subject
    [sStudiesList, iStudiesList] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject', 'inter_subject');
% CALL: db_links('Studies', iStudiesList)
elseif (nargin == 2) && ischar(varargin{1}) && strcmpi(varargin{1}, 'Study')
    % Get studies list
    iStudiesList = varargin{2};
    sStudiesList = bst_get('Study', iStudiesList);
    % Check that they all have the same subject
    subjectsDirs = cellfun(@(c)bst_fileparts(c), {sStudiesList.BrainStormSubject}, 'UniformOutput', 0);
    [uniqueSubjects, I, J] = unique(subjectsDirs);
    if (length(uniqueSubjects) ~= 1)
        % If it is not the case: call again the function as many times as needed
        for i = 1:length(uniqueSubjects)
            % Get all the studies for subject #i
            iStudiesSubj = find(J == i);
            % Call this function only with the studies for the subject #i
            OutputLinks = cat(2, OutputLinks, db_links('Study', iStudiesList(iStudiesSubj)));
        end
        return;
    else
        SubjectFile = uniqueSubjects{1};
    end
    % Get subject
    [sSubject, iSubject] = bst_get('Subject', SubjectFile);
else
    error('Invalid call');
end
% Invalid subject: return
if isempty(sSubject)
    return
end


%% ===== INITIALIZATION =====
% Progress bar
isNewProgressBar = ~bst_progress('isvisible');
if isNewProgressBar
    bst_progress('start', 'Update results links', 'Updating results links...', 1, length(iStudiesList));
else
    %bst_progress('text', 'Updating results links...');
end
% Get the default study for this subject
sDefaultStudy = bst_get('DefaultStudy', iSubject);

% === CREATE NEW LINKS TEMPLATES ===
% Link to default study
if ((iSubject == 0) || (sSubject.UseDefaultChannel ~= 0)) && ~isempty(sDefaultStudy) && ~isempty(sDefaultStudy.Result)
    [sLinksList, linkResultFiles] = createLinksMat(sDefaultStudy.Result);    
else
    sLinksList = [];
    linkResultFiles = [];
end

%% ===== PROCESS EACH STUDY =====
% For each study
for iStudy = 1:length(iStudiesList)
    % === GET LOCAL SHARED RESULTS ===
    sStudySubject = bst_get('Subject', sStudiesList(iStudy).BrainStormSubject);
    if (sStudySubject.UseDefaultChannel == 0)
        % Get the results that do not have any DataFile attached => shared imaging kernels
        iSharedRes = find(cellfun(@isempty, {sStudiesList(iStudy).Result.DataFile}) ...
                          & ~[sStudiesList(iStudy).Result.isLink] ...
                          & ~cellfun(@isempty, strfind({sStudiesList(iStudy).Result.FileName}, '_KERNEL_')));
        % Create links to local shared kernels
        if ~isempty(iSharedRes)
            [sLinksList, linkResultFiles] = createLinksMat(sStudiesList(iStudy).Result(iSharedRes));  
        else
            sLinksList = [];
            linkResultFiles = [];
        end
    end

    % === REMOVE OLD LINKS ===
    % Get the a list of the previous results-links
    iOldLinkRes = find([sStudiesList(iStudy).Result.isLink]);
    if ~isempty(iOldLinkRes)
        % Remove them from database
        sStudiesList(iStudy).Result(iOldLinkRes) = [];
    end
    
    % === CREATE NEW LINKS ===
    nData = length(sStudiesList(iStudy).Data);
    for iData = 1:nData
        % Data structure
        sData = sStudiesList(iStudy).Data(iData);
        % Check that the file is a real recordings file
        if ~strcmpi(sData.DataType, 'recordings') && ~strcmpi(sData.DataType, 'raw')
            continue;
        end
        % Build one link for each common results file and for each data file
        for iLink = 1:length(sLinksList)
            % Build new link entry
            sLinksList(iLink).DataFile = file_win2unix(sData.FileName);
            sLinksList(iLink).FileName = ['link|', linkResultFiles{iLink}, '|', sLinksList(iLink).DataFile];
            % Add link to study
            sStudiesList(iStudy).Result(end+1) = sLinksList(iLink);
            OutputLinks{end+1} = sLinksList(iLink).FileName;
        end
    end
    % Increment progress bar
    if isNewProgressBar
        bst_progress('inc', 1);
    end
    % Update study in database
    bst_set('Study', iStudiesList(iStudy), sStudiesList(iStudy));
end

% Close progress bar
if isNewProgressBar
    bst_progress('stop');
end


end


%% ================================================================================================
%  ====== HELPERS =================================================================================
%  ================================================================================================
function [sLinksList, linkResultFiles] = createLinksMat(Results)
    sLinksList = repmat(db_template('results'), 1, length(Results));
    linkResultFiles = cell(1,length(Results));
    for iRes = 1:length(Results)
        % Create 'results' structure to be stored in database
        sLinksList(iRes).Comment  = Results(iRes).Comment;
        sLinksList(iRes).FileName = '';
        sLinksList(iRes).isLink   = 1;
        sLinksList(iRes).HeadModelType = Results(iRes).HeadModelType;
        linkResultFiles{iRes} = file_win2unix(Results(iRes).FileName);
    end
end



